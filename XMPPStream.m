#import "XMPPStream.h"
#import "AsyncSocket.h"
#import "NSXMLElementAdditions.h"
#import "NSDataAdditions.h"
#import "XMPPIQ.h"
#import "XMPPMessage.h"
#import "XMPPPresence.h"

#if TARGET_OS_IPHONE
// Note: You may need to add the CFNetwork Framework to your project
#import <CFNetwork/CFNetwork.h>
#endif


// Define the debugging state
#define DEBUG_SEND      YES
#define DEBUG_RECV      YES
#define DEBUG_DELEGATE  YES

#define DDLogSend(format, ...)    if(DEBUG_SEND)  NSLog((format), ##__VA_ARGS__)
#define DDLogRecv(format, ...)    if(DEBUG_RECV)  NSLog((format), ##__VA_ARGS__)

// Define the various timeouts (in seconds) for retreiving various parts of the XML stream
#define TIMEOUT_WRITE         10
#define TIMEOUT_READ_START    10
#define TIMEOUT_READ_STREAM   -1

// Define the various tags we'll use to differentiate what it is we're currently reading or writing
#define TAG_WRITE_START      100
#define TAG_WRITE_STREAM     101

#define TAG_READ_START       200
#define TAG_READ_STREAM      201

// Define the various states we'll use to track our progress
#define STATE_DISCONNECTED     0
#define STATE_CONNECTING       1
#define STATE_OPENING          2
#define STATE_NEGOTIATING      3
#define STATE_STARTTLS         4
#define STATE_REGISTERING      5
#define STATE_AUTH_1           6
#define STATE_AUTH_2           7
#define STATE_BINDING          8
#define STATE_START_SESSION    9
#define STATE_CONNECTED       10

enum XMPPStreamFlags
{
	kAllowsSelfSignedCertificates = 1 << 0,  // If set, self-signed certificates are allowed during TLS negotiation
	kAllowsSSLHostNameMismatch    = 1 << 1,  // If set, the certificate name will not be checked during TLS negotiation
	kIsSecure                     = 1 << 2,  // If set, connection has been secured via SSL/TLS
	kIsAuthenticated              = 1 << 3,  // If set, authentication has succeeded
};

@implementation XMPPStream

/**
 * Initializes an XMPPStream with no delegate.
 * Note that this class will most likely require a delegate to be useful at all.
**/
- (id)init
{
	return [self initWithDelegate:nil];
}

/**
 * Initializes an XMPPStream with the given delegate.
 * After creating an object, you'll need to connect to a host using one of the connect...::: methods.
**/
- (id)initWithDelegate:(id)aDelegate
{
	if((self = [super init]))
	{
		// Store reference to delegate
		delegate = aDelegate;
		
		// Initialize state and socket
		state = STATE_DISCONNECTED;
		asyncSocket = [[AsyncSocket alloc] initWithDelegate:self];
		
		// Enable pre-buffering on the socket to improve readDataToData performance
		[asyncSocket enablePreBuffering];
		
		// Initialize configuration
		flags = 0;
		
		// We initialize an empty buffer of data to store data as it arrives
		buffer = [[NSMutableData alloc] initWithCapacity:100];
		
		// Initialize the standard terminator to listen for
		// We try to parse the data everytime we encouter an XML ending tag character
		terminator = [[@">" dataUsingEncoding:NSUTF8StringEncoding] retain];
	}
	return self;
}

/**
 * The standard deallocation method.
 * Every object variable declared in the header file should be released here.
**/
- (void)dealloc
{
	[asyncSocket setDelegate:nil];
	[asyncSocket disconnect];
	[asyncSocket release];
	[xmppHostName release];
	[buffer release];
	[rootElement release];
	[terminator release];
	[authUsername release];
	[authResource release];
	[tempPassword release];
	[keepAliveTimer invalidate];
	[keepAliveTimer release];
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Configuration:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * The standard delegate methods.
**/
- (id)delegate {
	return delegate;
}
- (void)setDelegate:(id)newDelegate {
	delegate = newDelegate;
}

/**
 * If connecting to a secure server, Mac OS X will automatically verify the authenticity of the TLS certificate.
 * If the certificate is self-signed, a dialog box will automatically pop up,
 * warning the user that the authenticity could not be verified, and prompting them to see if it should continue.
 * If you are connecting to a server with a self-signed certificate, and you would like to automatically accept it,
 * then call set this value to YES method prior to connecting.  The default value is NO.
**/
- (BOOL)allowsSelfSignedCertificates
{
	return (flags & kAllowsSelfSignedCertificates);
}
- (void)setAllowsSelfSignedCertificates:(BOOL)flag
{
	if(flag)
		flags |= kAllowsSelfSignedCertificates;
	else
		flags &= ~kAllowsSelfSignedCertificates;
}

/**
 * For some servers the name on the SSL certificate does not match the domain name.
 * An good example is google talk servers that use a gmail certificate, but host many different virtual servers,
 * such as google.com, or any business account that uses google apps.
**/
- (BOOL)allowsSSLHostNameMismatch
{
	return (flags & kAllowsSSLHostNameMismatch);
}
- (void)setAllowsSSLHostNameMismatch:(BOOL)flag
{
	if(flag)
		flags |= kAllowsSSLHostNameMismatch;
	else
		flags &= ~kAllowsSSLHostNameMismatch;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Connection Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns YES if the connection is closed, and thus no stream is open.
 * If the stream is neither disconnected, nor connected, then a connection is currently being established.
**/
- (BOOL)isDisconnected
{
	return (state == STATE_DISCONNECTED);
}

/**
 * Returns YES if the connection is open, and the stream has been properly established.
 * If the stream is neither disconnected, nor connected, then a connection is currently being established.
**/
- (BOOL)isConnected
{
	return (state == STATE_CONNECTED);
}

/**
 * Returns YES if SSL/TLS was used to establish a connection to the server.
 * Some servers may require an "upgrade to TLS" in order to start communication,
 * so even if the connectToHost:onPort:withVirtualHost: method was used, an ugrade to TLS may have occured.
**/
- (BOOL)isSecure
{
	return (flags & kIsSecure);
}
- (void)setIsSecure:(BOOL)flag
{
	if(flag)
		flags |= kIsSecure;
	else
		flags &= ~kIsSecure;
}

- (void)connectToHost:(NSString *)hostName
               onPort:(UInt16)portNumber
      withVirtualHost:(NSString *)vHostName
               secure:(BOOL)secure
{    
	if(state == STATE_DISCONNECTED)
	{
		// Store configuration information
		[self setIsSecure:secure];
		
		[serverHostName autorelease];
		serverHostName = [hostName copy];
		[xmppHostName autorelease];
		xmppHostName = [vHostName copy];
		
		// Update state
		// Note that we do this before connecting to the host,
		// because the delegate methods will be called before the method returns
		state = STATE_CONNECTING;
		
		// If the given port number is zero, use the default port number for XMPP communication
		UInt16 myPortNumber = (portNumber > 0) ? portNumber : (secure ? 5223 : 5222);
		
		// Connect to the host
		[asyncSocket connectToHost:hostName onPort:myPortNumber error:nil];
	}
}

/**
 * Connects to the given host on the given port number.
 * If you pass a port number of 0, the default port number for XMPP traffic (5222) is used.
 * The virtual host name is the name of the XMPP host at the given address that we should communicate with.
 * This is generally the domain identifier of the JID. IE: "gmail.com"
 * 
 * If the virtual host name is nil, or an empty string, a virtual host will not be specified in the XML stream
 * connection. This may be OK in some cases, but some servers require it to start a connection.
 **/
- (void)connectToHost:(NSString *)hostName
			   onPort:(UInt16)portNumber
	  withVirtualHost:(NSString *)vHostName
{
	[self connectToHost:hostName onPort:portNumber withVirtualHost:vHostName secure:NO];
}

/**
 * Connects to the given host on the given port number, using a secure SSL/TLS connection.
 * If you pass a port number of 0, the default port number for secure XMPP traffic (5223) is used.
 * The virtual host name is the name of the XMPP host at the given address that we should communicate with.
 * This is generally the domain identifier of the JID. IE: "gmail.com"
 * 
 * If the virtual host name is nil, or an empty string, a virtual host will not be specified in the XML stream
 * connection. This may be OK in some cases, but some servers require it to start a connection.
**/
- (void)connectToSecureHost:(NSString *)hostName
					 onPort:(UInt16)portNumber
			withVirtualHost:(NSString *)vHostName
{
	[self connectToHost:hostName onPort:portNumber withVirtualHost:vHostName secure:YES];
}

/**
 * Closes the connection to the remote host.
**/
- (void)disconnect
{
	[asyncSocket disconnect];
	
	// Note: The state is updated automatically in the onSocketDidDisconnect: method.
}

- (void)disconnectAfterSending
{
	[asyncSocket disconnectAfterWriting];
	
	// Note: The state is updated automatically in the onSocketDidDisconnect: method.
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark User Registration:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method checks the stream features of the connected server to determine if in-band registartion is supported.
 * If we are not connected to a server, this method simply returns NO.
**/
- (BOOL)supportsInBandRegistration
{
	if(state == STATE_CONNECTED)
	{
		NSXMLElement *features = [rootElement elementForName:@"stream:features"];
		NSXMLElement *reg = [features elementForName:@"register" xmlns:@"http://jabber.org/features/iq-register"];
		
		return (reg != nil);
	}
	return NO;
}

/**
 * This method attempts to register a new user on the server using the given username and password.
 * The result of this action will be returned via the delegate method xmppStream:didReceiveIQ:
 * 
 * If the XMPPStream is not connected, or the server doesn't support in-band registration, this method does nothing.
**/
- (void)registerUser:(NSString *)username withPassword:(NSString *)password
{
	// The only proper time to call this method is after we've connected to the server,
	// and exchanged the opening XML stream headers
	if(state == STATE_CONNECTED)
	{
		if([self supportsInBandRegistration])
		{
			NSXMLElement *queryElement = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:register"];
			[queryElement addChild:[NSXMLElement elementWithName:@"username" stringValue:username]];
			[queryElement addChild:[NSXMLElement elementWithName:@"password" stringValue:password]];
			
			NSXMLElement *iqElement = [NSXMLElement elementWithName:@"iq"];
			[iqElement addAttributeWithName:@"type" stringValue:@"set"];
			[iqElement addChild:queryElement];
			
			DDLogSend(@"SEND: %@", [iqElement XMLString]);
			
			[asyncSocket writeData:[[iqElement XMLString] dataUsingEncoding:NSUTF8StringEncoding]
					   withTimeout:TIMEOUT_WRITE
							   tag:TAG_WRITE_STREAM];
			
			// Update state
			state = STATE_REGISTERING;
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark User Authentication:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method checks the stream features of the connected server to determine if plain authentication is supported.
 * If we are not connected to a server, this method simply returns NO.
**/
- (BOOL)supportsPlainAuthentication
{
	// The root element can be properly queried for authentication mechanisms anytime after the stream:features
	// are received, and TLS has been setup (if needed/required)
	if(state > STATE_STARTTLS)
	{
		NSXMLElement *features = [rootElement elementForName:@"stream:features"];
		NSXMLElement *mech = [features elementForName:@"mechanisms" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
		
		NSArray *mechanisms = [mech elementsForName:@"mechanism"];
		
		int i;
		for(i = 0; i < [mechanisms count]; i++)
		{
			if([[[mechanisms objectAtIndex:i] stringValue] isEqualToString:@"PLAIN"])
			{
				return YES;
			}
		}
	}
	return NO;
}

/**
 * This method checks the stream features of the connected server to determine if digest authentication is supported.
 * If we are not connected to a server, this method simply returns NO.
 * 
 * This is the preferred authentication technique, and will be used if the server supports it.
**/
- (BOOL)supportsDigestMD5Authentication
{
	// The root element can be properly queried for authentication mechanisms anytime after the stream:features
	// are received, and TLS has been setup (if needed/required)
	if(state > STATE_STARTTLS)
	{
		NSXMLElement *features = [rootElement elementForName:@"stream:features"];
		NSXMLElement *mech = [features elementForName:@"mechanisms" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
		
		NSArray *mechanisms = [mech elementsForName:@"mechanism"];
		
		int i;
		for(i = 0; i < [mechanisms count]; i++)
		{
			if([[[mechanisms objectAtIndex:i] stringValue] isEqualToString:@"DIGEST-MD5"])
			{
				return YES;
			}
		}
	}
	return NO;
}

/**
 * This method only applies to servers that don't support XMPP version 1.0, as defined in RFC 3920.
 * With these servers, we attempt to discover supported authentication modes jia the jabber:iq:auth namespace.
**/
- (BOOL)supportsDeprecatedPlainAuthentication
{
	if(state > STATE_STARTTLS)
	{
		// Search for an iq element within the rootElement.
		// Recall that some servers might stupidly add a "jabber:client" namespace which might cause problems
		// if we simply used the elementForName method.
		
		NSXMLElement *iq = nil;
		
		NSUInteger i, count = [rootElement childCount];
		for(i = 0; i < count; i++)
		{
			NSXMLNode *childNode = [rootElement childAtIndex:i];
			
			if([childNode kind] == NSXMLElementKind)
			{
				if([[childNode name] isEqualToString:@"iq"])
				{
					iq = (NSXMLElement *)childNode;
				}
			}
		}
		
		NSXMLElement *query = [iq elementForName:@"query" xmlns:@"jabber:iq:auth"];
		NSXMLElement *plain = [query elementForName:@"password"];
		
		return (plain != nil);
	}
	return NO;
}

/**
 * This method only applies to servers that don't support XMPP version 1.0, as defined in RFC 3920.
 * With these servers, we attempt to discover supported authentication modes jia the jabber:iq:auth namespace.
**/
- (BOOL)supportsDeprecatedDigestAuthentication
{
	if(state > STATE_STARTTLS)
	{
		// Search for an iq element within the rootElement.
		// Recall that some servers might stupidly add a "jabber:client" namespace which might cause problems
		// if we simply used the elementForName method.
		
		NSXMLElement *iq = nil;
		
		NSUInteger i, count = [rootElement childCount];
		for(i = 0; i < count; i++)
		{
			NSXMLNode *childNode = [rootElement childAtIndex:i];
			
			if([childNode kind] == NSXMLElementKind)
			{
				if([[childNode name] isEqualToString:@"iq"])
				{
					iq = (NSXMLElement *)childNode;
				}
			}
		}
		
		NSXMLElement *query = [iq elementForName:@"query" xmlns:@"jabber:iq:auth"];
		NSXMLElement *digest = [query elementForName:@"digest"];
		
		return (digest != nil);
	}
	return NO;
}

/**
 * This method attempts to sign-in to the server using the given username and password.
 * The result of this action will be returned via the delegate method xmppStream:didReceiveIQ:
 *
 * If the XMPPStream is not connected, this method does nothing.
**/
- (void)authenticateUser:(NSString *)username
			withPassword:(NSString *)password
				resource:(NSString *)resource
{
	// The only proper time to call this method is after we've connected to the server,
	// and exchanged the opening XML stream headers
	if(state == STATE_CONNECTED)
	{
		if([self supportsDigestMD5Authentication])
		{
			NSString *auth = @"<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' mechanism='DIGEST-MD5'/>";
			
			DDLogSend(@"SEND: %@", auth);
			
			[asyncSocket writeData:[auth dataUsingEncoding:NSUTF8StringEncoding]
					   withTimeout:TIMEOUT_WRITE
							   tag:TAG_WRITE_STREAM];
			
			// Save authentication information
			[authUsername release];
			[authResource release];
			[tempPassword release];
			
			authUsername = [username copy];
			authResource = [resource copy];
			tempPassword = [password copy];
			
			// Update state
			state = STATE_AUTH_1;
		}
		else if([self supportsPlainAuthentication])
		{
			// From RFC 4616 - PLAIN SASL Mechanism:
			// [authzid] UTF8NUL authcid UTF8NUL passwd
			// 
			// authzid: authorization identity
			// authcid: authentication identity (username)
			// passwd : password for authcid
			
			NSString *payload = [NSString stringWithFormat:@"%C%@%C%@", 0, username, 0, password];
			NSString *base64 = [[payload dataUsingEncoding:NSUTF8StringEncoding] base64Encoded];
			
			NSXMLElement *auth = [NSXMLElement elementWithName:@"auth" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
			[auth addAttributeWithName:@"mechanism" stringValue:@"PLAIN"];
			[auth setStringValue:base64];
			
			DDLogSend(@"SEND: %@", [auth XMLString]);
			
			[asyncSocket writeData:[[auth XMLString] dataUsingEncoding:NSUTF8StringEncoding]
					   withTimeout:TIMEOUT_WRITE
							   tag:TAG_WRITE_STREAM];
			
			// Save authentication information
			[authUsername release];
			[authResource release];
						
			authUsername = [username copy];
			authResource = [resource copy];
			
			// Update state
			state = STATE_AUTH_1;
		}
		else
		{
			// The server does not appear to support SASL authentication (at least any type we can use)
			// So we'll revert back to the old fashioned jabber:iq:auth mechanism
			
			NSXMLElement *queryElement = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:auth"];
			[queryElement addChild:[NSXMLElement elementWithName:@"username" stringValue:username]];
			[queryElement addChild:[NSXMLElement elementWithName:@"resource" stringValue:resource]];
			
			if([self supportsDeprecatedDigestAuthentication])
			{
				NSString *rootID = [[[self rootElement] attributeForName:@"id"] stringValue];
				NSString *digestStr = [NSString stringWithFormat:@"%@%@", rootID, password];
				NSData *digestData = [digestStr dataUsingEncoding:NSUTF8StringEncoding];
				
				NSString *digest = [[digestData sha1Digest] hexStringValue];
				
				[queryElement addChild:[NSXMLElement elementWithName:@"digest" stringValue:digest]];
			}
			else
			{
				[queryElement addChild:[NSXMLElement elementWithName:@"password" stringValue:password]];
			}
			
			NSXMLElement *iqElement = [NSXMLElement elementWithName:@"iq"];
			[iqElement addAttributeWithName:@"type" stringValue:@"set"];
			[iqElement addChild:queryElement];
			
			DDLogSend(@"SEND: %@", [iqElement XMLString]);
			
			[asyncSocket writeData:[[iqElement XMLString] dataUsingEncoding:NSUTF8StringEncoding]
					   withTimeout:TIMEOUT_WRITE
							   tag:TAG_WRITE_STREAM];
			
			// Save authentication information
			[authUsername release];
			[authResource release];
			
			authUsername = [username copy];
			authResource = [resource copy];
			
			// Update state
			state = STATE_AUTH_1;
		}
	}
}

- (BOOL)isAuthenticated
{
	return (flags & kIsAuthenticated);
}
- (void)setIsAuthenticated:(BOOL)flag
{
	if(flag)
		flags |= kIsAuthenticated;
	else
		flags &= ~kIsAuthenticated;
}

- (NSString *)authenticatedUsername
{
	return [[authUsername copy] autorelease];
}

- (NSString *)authenticatedResource
{
	return [[authResource copy] autorelease];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark General Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method will return the root element of the document.
 * This element contains the opening <stream:stream/> and <stream:features/> tags received from the server
 * when the XML stream was opened.
 * 
 * Note: The rootElement is empty, and does not contain all the XML elements the stream has received during it's
 * connection.  This is done for performance reasons and for the obvious benefit of being more memory efficient.
**/
- (NSXMLElement *)rootElement
{
	return rootElement;
}

/**
 * Returns the version attribute from the servers's <stream:stream/> element.
 * This should be at least 1.0 to be RFC 3920 compliant.
 * If no version number was set, the server is not RFC compliant, and 0 is returned.
**/
- (float)serverXmppStreamVersionNumber
{
	return [[[rootElement attributeForName:@"version"] stringValue] floatValue];
}

/**
 * This methods handles sending an XML fragment.
 * If the XMPPStream is not connected, this method does nothing.
**/
- (void)sendElement:(NSXMLElement *)element
{
	if(state == STATE_CONNECTED)
	{
		NSString *elementStr = [element XMLString];
		
		DDLogSend(@"SEND: %@", elementStr);
		
		[asyncSocket writeData:[elementStr dataUsingEncoding:NSUTF8StringEncoding]
				   withTimeout:TIMEOUT_WRITE
						   tag:TAG_WRITE_STREAM];
	}
}

/**
 * This method handles sending an XML fragment.
 * If the XMPPStream is not connected, this method does nothing.
 * 
 * After the element has been successfully sent, the xmppStream:didSendElementWithTag: delegate method is called.
**/
- (void)sendElement:(NSXMLElement *)element andNotifyMe:(long)tag
{
	if(state == STATE_CONNECTED)
	{
		NSString *elementStr = [element XMLString];
		
		DDLogSend(@"SEND: %@", elementStr);
		
		[asyncSocket writeData:[elementStr dataUsingEncoding:NSUTF8StringEncoding]
				   withTimeout:TIMEOUT_WRITE
						   tag:tag];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Stream Negotiation:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method handles sending the opening <stream:stream ...> element which is needed in several situations.
**/
- (void)sendOpeningNegotiation
{
	if(state == STATE_CONNECTING)
	{
		// TCP connection was just opened - We need to include the opening XML stanza
		NSString *s1 = @"<?xml version='1.0'?>";
		
		DDLogSend(@"SEND: %@", s1);
		
		[asyncSocket writeData:[s1 dataUsingEncoding:NSUTF8StringEncoding]
				   withTimeout:TIMEOUT_WRITE
						   tag:TAG_WRITE_START];
	}
	
	NSString *xmlns = @"jabber:client";
	NSString *xmlns_stream = @"http://etherx.jabber.org/streams";
	
	NSString *temp, *s2;
	if([xmppHostName length] > 0)
	{
		temp = @"<stream:stream xmlns='%@' xmlns:stream='%@' version='1.0' to='%@'>";
		s2 = [NSString stringWithFormat:temp, xmlns, xmlns_stream, xmppHostName];
	}
	else
	{
		temp = @"<stream:stream xmlns='%@' xmlns:stream='%@' version='1.0'>";
		s2 = [NSString stringWithFormat:temp, xmlns, xmlns_stream];
	}
	
	DDLogSend(@"SEND: %@", s2);
	
	[asyncSocket writeData:[s2 dataUsingEncoding:NSUTF8StringEncoding]
			   withTimeout:TIMEOUT_WRITE
					   tag:TAG_WRITE_START];
	
	// Update status
	state = STATE_OPENING;
}

/**
 * This method handles starting TLS negotiation on the socket, using the proper settings.
**/
- (void)startTLS
{
	NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithCapacity:3];
	
	// Use the highest possible security
	[settings setObject:(NSString *)kCFStreamSocketSecurityLevelNegotiatedSSL
				 forKey:(NSString *)kCFStreamSSLLevel];
	
	// Set the peer name
	if([self allowsSSLHostNameMismatch])
	{
		[settings setObject:[NSNull null] forKey:(NSString *)kCFStreamSSLPeerName];
	}
	else
	{
		if([xmppHostName length] > 0)
			[settings setObject:xmppHostName forKey:(NSString *)kCFStreamSSLPeerName];
		else
			[settings setObject:serverHostName forKey:(NSString *)kCFStreamSSLPeerName];
	}
	
	// Allow self-signed certificates if needed
	if([self allowsSelfSignedCertificates])
	{
		[settings setObject:[NSNumber numberWithBool:YES]
					 forKey:(NSString *)kCFStreamSSLAllowsAnyRoot];
	}
	
	[asyncSocket startTLS:settings];
	
	// Note: We don't need to wait for asyncSocket to complete TLS negotiation.
	// We can just continue reading/writing to the socket, and it will handle queueing everything for us!
}

/**
 * This method is called anytime we receive the server's stream features.
 * This method looks at the stream features, and handles any requirements so communication can continue.
**/
- (void)handleStreamFeatures
{
	// Extract the stream features
	NSXMLElement *features = [rootElement elementForName:@"stream:features"];
	
	// Check to see if TLS is required
	// Don't forget about that NSXMLElement bug you reported to apple (xmlns is required or element won't be found)
	NSXMLElement *f_starttls = [features elementForName:@"starttls" xmlns:@"urn:ietf:params:xml:ns:xmpp-tls"];
	
	if(f_starttls)
	{
		if([f_starttls elementForName:@"required"])
		{
			// TLS is required for this connection
			state = STATE_STARTTLS;
			
			NSString *starttls = @"<starttls xmlns='urn:ietf:params:xml:ns:xmpp-tls'/>";
			
			DDLogSend(@"SEND: %@", starttls);
			
			[asyncSocket writeData:[starttls dataUsingEncoding:NSUTF8StringEncoding]
					   withTimeout:TIMEOUT_WRITE
							   tag:TAG_WRITE_STREAM];
			
			// We're already listening for the response...
			return;
		}
	}
	
	// Check to see if resource binding is required
	// Don't forget about that NSXMLElement bug you reported to apple (xmlns is required or element won't be found)
	NSXMLElement *f_bind = [features elementForName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
	
	if(f_bind)
	{
		// Binding is required for this connection
		state = STATE_BINDING;
		
		if([authResource length] > 0)
		{
			// Ask the server to bind the user specified resource
			
			NSXMLElement *resource = [NSXMLElement elementWithName:@"resource"];
			[resource setStringValue:authResource];
			
			NSXMLElement *bind = [NSXMLElement elementWithName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
			[bind addChild:resource];
			
			NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
			[iq addAttributeWithName:@"type" stringValue:@"set"];
			[iq addChild:bind];
			
			DDLogSend(@"SEND: %@", iq);
			
			[asyncSocket writeData:[[iq XMLString] dataUsingEncoding:NSUTF8StringEncoding]
					   withTimeout:TIMEOUT_WRITE
							   tag:TAG_WRITE_STREAM];
		}
		else
		{
			// The user didn't specify a resource, so we ask the server to bind one for us
			
			NSXMLElement *bind = [NSXMLElement elementWithName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
			
			NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
			[iq addAttributeWithName:@"type" stringValue:@"set"];
			[iq addChild:bind];
						
			DDLogSend(@"SEND: %@", iq);
			
			[asyncSocket writeData:[[iq XMLString] dataUsingEncoding:NSUTF8StringEncoding]
					   withTimeout:TIMEOUT_WRITE
							   tag:TAG_WRITE_STREAM];
		}
		
		// We're already listening for the response...
		return;
	}
	
	// It looks like all has gone well, and the connection should be ready to use now
	state = STATE_CONNECTED;
	
	if(![self isAuthenticated])
	{
		// Setup keep alive timer
		[keepAliveTimer invalidate];
		[keepAliveTimer release];
		keepAliveTimer = [[NSTimer scheduledTimerWithTimeInterval:300
														   target:self
														 selector:@selector(keepAlive:)
														 userInfo:nil
														  repeats:YES] retain];
		
		// Notify delegate
		if([delegate respondsToSelector:@selector(xmppStreamDidOpen:)]) {
			[delegate xmppStreamDidOpen:self];
		}
		else if(DEBUG_DELEGATE) {
			NSLog(@"xmppStreamDidOpen:%p", self);
		}
	}
}

- (void)handleStartTLSResponse:(NSXMLElement *)response
{
	// We're expecting a proceed response
	// If we get anything else we can safely assume it's the equivalent of a failure response
	if(![[response name] isEqualToString:@"proceed"])
	{
		// We can close our TCP connection now
		[self disconnect];
		
		// The onSocketDidDisconnect: method will handle everything else
		return;
	}
	
	// Start TLS negotiation
	[self startTLS];
	
	// Make a note of the switch to TLS
	[self setIsSecure:YES];
	
	// Now we start our negotiation over again...
	[self sendOpeningNegotiation];
}

/**
 * After the registerUser:withPassword: method is invoked, a registration message is sent to the server.
 * We're waiting for the result from this registration request.
**/
- (void)handleRegistration:(NSXMLElement *)response
{
	if([[[response attributeForName:@"type"] stringValue] isEqualToString:@"error"])
	{
		// Revert back to connected state (from authenticating state)
		state = STATE_CONNECTED;
		
		if([delegate respondsToSelector:@selector(xmppStream:didNotRegister:)]) {
			[delegate xmppStream:self didNotRegister:response];
		}
		else if(DEBUG_DELEGATE) {
			NSLog(@"xmppStream:%p didNotRegister:%@", self, [response XMLString]);
		}
	}
	else
	{
		// Revert back to connected state (from authenticating state)
		state = STATE_CONNECTED;
		
		if([delegate respondsToSelector:@selector(xmppStreamDidRegister:)]) {
			[delegate xmppStreamDidRegister:self];
		}
		else if(DEBUG_DELEGATE) {
			NSLog(@"xmppStreamDidRegister:%p", self);
		}
	}
}

/**
 * After the authenticateUser:withPassword:resource method is invoked, a authentication message is sent to the server.
 * If the server supports digest-md5 sasl authentication, it is used.  Otherwise plain sasl authentication is used,
 * assuming the server supports it.
 * 
 * Now if digest-md5 was used, we sent a challenge request, and we're waiting for a challenge response.
 * If plain sasl was used, we sent our authentication information, and we're waiting for a success response.
**/
- (void)handleAuth1:(NSXMLElement *)response
{
	if([self supportsDigestMD5Authentication])
	{
		// We're expecting a challenge response
		// If we get anything else we can safely assume it's the equivalent of a failure response
		if(![[response name] isEqualToString:@"challenge"])
		{
			// Revert back to connected state (from authenticating state)
			state = STATE_CONNECTED;
			
			if([delegate respondsToSelector:@selector(xmppStream:didNotAuthenticate:)]) {
				[delegate xmppStream:self didNotAuthenticate:response];
			}
			else if(DEBUG_DELEGATE) {
				NSLog(@"xmppStream:%p didNotAuthenticate:%@", self, [response XMLString]);
			}
		}
		else
		{
			// Create authentication object from the given challenge
			// We'll release this object at the end of this else block
			XMPPDigestAuthentication *auth = [[XMPPDigestAuthentication alloc] initWithChallenge:response];
			
			// Sometimes the realm isn't specified
			// In this case I believe the realm is implied as the virtual host name
			if(![auth realm])
			{
				if([xmppHostName length] > 0)
					[auth setRealm:xmppHostName];
				else
					[auth setRealm:serverHostName];
			}
			
			// Set digest-uri
			if([xmppHostName length] > 0)
				[auth setDigestURI:[NSString stringWithFormat:@"xmpp/%@", xmppHostName]];
			else
				[auth setDigestURI:[NSString stringWithFormat:@"xmpp/%@", serverHostName]];
			
			// Set username and password
			[auth setUsername:authUsername password:tempPassword];
			
			// Create and send challenge response element
			NSXMLElement *cr = [NSXMLElement elementWithName:@"response" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
			[cr setStringValue:[auth base64EncodedFullResponse]];
			
			DDLogSend(@"SEND: %@", [cr XMLString]);
			
			[asyncSocket writeData:[[cr XMLString] dataUsingEncoding:NSUTF8StringEncoding]
					   withTimeout:TIMEOUT_WRITE
							   tag:TAG_WRITE_STREAM];
			
			// Release unneeded resources
			[auth release];
			[tempPassword release]; tempPassword = nil;
			
			// Update state
			state = STATE_AUTH_2;
		}
	}
	else if([self supportsPlainAuthentication])
	{
		// We're expecting a success response
		// If we get anything else we can safely assume it's the equivalent of a failure response
		if(![[response name] isEqualToString:@"success"])
		{
			// Revert back to connected state (from authenticating state)
			state = STATE_CONNECTED;
			
			if([delegate respondsToSelector:@selector(xmppStream:didNotAuthenticate:)]) {
				[delegate xmppStream:self didNotAuthenticate:response];
			}
			else if(DEBUG_DELEGATE) {
				NSLog(@"xmppStream:%p didNotAuthenticate:%@", self, [response XMLString]);
			}
		}
		else
		{
			// We are successfully authenticated (via sasl:plain)
			[self setIsAuthenticated:YES];
			
			// Now we start our negotiation over again...
			[self sendOpeningNegotiation];
		}
	}
	else
	{
		// We used the old fashioned jabber:iq:auth mechanism
		
		if([[[response attributeForName:@"type"] stringValue] isEqualToString:@"error"])
		{
			// Revert back to connected state (from authenticating state)
			state = STATE_CONNECTED;
			
			if([delegate respondsToSelector:@selector(xmppStream:didNotAuthenticate:)]) {
				[delegate xmppStream:self didNotAuthenticate:response];
			}
			else if(DEBUG_DELEGATE) {
				NSLog(@"xmppStream:%p didNotAuthenticate:%@", self, [response XMLString]);
			}
		}
		else
		{
			// We are successfully authenticated (via non-sasl:digest)
			// And we've binded our resource as well
			[self setIsAuthenticated:YES];
			
			// Revert back to connected state (from authenticating state)
			state = STATE_CONNECTED;
			
			if([delegate respondsToSelector:@selector(xmppStreamDidAuthenticate:)]) {
				[delegate xmppStreamDidAuthenticate:self];
			}
			else if(DEBUG_DELEGATE) {
				NSLog(@"xmppStreamDidAuthenticate:%p", self);
			}
		}
	}
}

/**
 * This method handles the result of our challenge response we sent in handleAuth1 using digest-md5 sasl.
**/
- (void)handleAuth2:(NSXMLElement *)response
{
	if([[response name] isEqualToString:@"challenge"])
	{
		XMPPDigestAuthentication *auth = [[[XMPPDigestAuthentication alloc] initWithChallenge:response] autorelease];
		
		if(![auth rspauth])
		{
			// We're getting another challenge???
			// I'm not sure what this could possibly be, so for now I'll assume it's a failure
			
			// Revert back to connected state (from authenticating state)
			state = STATE_CONNECTED;
			
			if([delegate respondsToSelector:@selector(xmppStream:didNotAuthenticate:)]) {
				[delegate xmppStream:self didNotAuthenticate:response];
			}
			else if(DEBUG_DELEGATE) {
				NSLog(@"xmppStream:%p didNotAuthenticate:%@", self, [response XMLString]);
			}
		}
		else
		{
			// We received another challenge, but it's really just an rspauth
			// This is supposed to be included in the success element (according to the updated RFC)
			// but many implementations incorrectly send it inside a second challenge request.
			
			// Create and send empty challenge response element
			NSXMLElement *cr = [NSXMLElement elementWithName:@"response" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
			
			DDLogSend(@"SEND: %@", [cr XMLString]);
			
			[asyncSocket writeData:[[cr XMLString] dataUsingEncoding:NSUTF8StringEncoding]
					   withTimeout:TIMEOUT_WRITE
							   tag:TAG_WRITE_STREAM];
			
			// The state remains in STATE_AUTH_2
		}
	}
	else if([[response name] isEqualToString:@"success"])
	{
		// We are successfully authenticated (via sasl:digest-md5)
		[self setIsAuthenticated:YES];
		
		// Now we start our negotiation over again...
		[self sendOpeningNegotiation];
	}
	else
	{
		// We received some kind of <failure/> element
		
		// Revert back to connected state (from authenticating state)
		state = STATE_CONNECTED;
		
		if([delegate respondsToSelector:@selector(xmppStream:didNotAuthenticate:)]) {
			[delegate xmppStream:self didNotAuthenticate:response];
		}
		else if(DEBUG_DELEGATE) {
			NSLog(@"xmppStream:%p didNotAuthenticate:%@", self, [response XMLString]);
		}
	}
}

- (void)handleBinding:(NSXMLElement *)response
{
	NSXMLElement *r_bind = [response elementForName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
	NSXMLElement *r_jid = [r_bind elementForName:@"jid"];
	
	if(r_jid)
	{
		// We're properly binded to a resource now
		// Extract and save our resource (it may not be what we originally requested)
		NSString *fullJID = [r_jid stringValue];
		
		[authResource release];
		authResource = [[fullJID lastPathComponent] copy];
		
		// And we may now have to do one last thing before we're ready - start an IM session
		NSXMLElement *features = [rootElement elementForName:@"stream:features"];
		
		// Check to see if a session is required
		// Don't forget about that NSXMLElement bug you reported to apple (xmlns is required or element won't be found)
		NSXMLElement *f_session = [features elementForName:@"session" xmlns:@"urn:ietf:params:xml:ns:xmpp-session"];
		
		if(f_session)
		{
			NSXMLElement *session = [NSXMLElement elementWithName:@"session"];
			[session setXmlns:@"urn:ietf:params:xml:ns:xmpp-session"];
			
			NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
			[iq addAttributeWithName:@"type" stringValue:@"set"];
			[iq addChild:session];
			
			DDLogSend(@"SEND: %@", iq);
			
			[asyncSocket writeData:[[iq XMLString] dataUsingEncoding:NSUTF8StringEncoding]
					   withTimeout:TIMEOUT_WRITE
							   tag:TAG_WRITE_STREAM];
			
			// Update state
			state = STATE_START_SESSION;
		}
		else
		{
			// Revert back to connected state (from binding state)
			state = STATE_CONNECTED;
			
			if([delegate respondsToSelector:@selector(xmppStreamDidAuthenticate:)]) {
				[delegate xmppStreamDidAuthenticate:self];
			}
			else if(DEBUG_DELEGATE) {
				NSLog(@"xmppStreamDidAuthenticate:%p", self);
			}
		}
	}
	else
	{
		// It appears the server didn't allow our resource choice
		// We'll simply let the server choose then
		
		NSXMLElement *bind = [NSXMLElement elementWithName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
		
		NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
		[iq addAttributeWithName:@"type" stringValue:@"set"];
		[iq addChild:bind];
		
		DDLogSend(@"SEND: %@", iq);
		
		[asyncSocket writeData:[[iq XMLString] dataUsingEncoding:NSUTF8StringEncoding]
				   withTimeout:TIMEOUT_WRITE
						   tag:TAG_WRITE_STREAM];
		
		// The state remains in STATE_BINDING
	}
}

- (void)handleStartSessionResponse:(NSXMLElement *)response
{
	if([[[response attributeForName:@"type"] stringValue] isEqualToString:@"result"])
	{
		// Revert back to connected state (from start session state)
		state = STATE_CONNECTED;
		
		if([delegate respondsToSelector:@selector(xmppStreamDidAuthenticate:)]) {
			[delegate xmppStreamDidAuthenticate:self];
		}
		else if(DEBUG_DELEGATE) {
			NSLog(@"xmppStreamDidAuthenticate:%p", self);
		}
	}
	else
	{
		// Revert back to connected state (from start session state)
		state = STATE_CONNECTED;
		
		if([delegate respondsToSelector:@selector(xmppStream:didNotAuthenticate:)]) {
			[delegate xmppStream:self didNotAuthenticate:response];
		}
		else if(DEBUG_DELEGATE) {
			NSLog(@"xmppStream:%p didNotAuthenticate:%@", self, [response XMLString]);
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark AsyncSocket Delegate Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Called when a socket connects and is ready for reading and writing. "host" will be an IP address, not a DNS name.
**/
- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
	// The TCP connection is now established
	
	// Are we using old-style SSL? (Not the upgrade to TLS technique specified in the XMPP RFC)
	if([self isSecure])
	{
		// The connection must be secured immediately (just like with HTTPS)
		[self startTLS];
		
		// Note: We don't need to wait for asyncSocket to complete TLS negotiation.
		// We can just continue reading/writing to the socket, and it will handle queueing everything for us!
	}
	
	// Initialize the XML stream
	[self sendOpeningNegotiation];
	
	// And start reading in the server's XML stream
	[asyncSocket readDataToData:terminator withTimeout:TIMEOUT_READ_START tag:TAG_READ_START];
}

/**
 * Called when a socket has completed reading the requested data. Not called if there is an error.
**/
- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData*)data withTag:(long)tag
{
	NSString *dataAsStr = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
	
	DDLogRecv(@"RECV: %@", dataAsStr);
	
	if(state == STATE_OPENING)
	{
		// Could be either one of the following:
		// <?xml ...>
		// <stream:stream ...>
		
		[buffer appendData:data];
		
		if([dataAsStr hasSuffix:@"?>"])
		{
			// We read in the <?xml version='1.0'?> line
			// We need to keep reading for the <stream:stream ...> line
			[asyncSocket readDataToData:terminator withTimeout:TIMEOUT_READ_START tag:TAG_READ_START];
		}
		else
		{
			// At this point we've sent our XML stream header, and we've received the response XML stream header.
			// We save the root element of our stream for future reference.
			// We've kept everything up to this point in our buffer, so all we need to do is close the stream:stream
			// tag to allow us to parse the data as a valid XML document.
			// Digest Access authentication requires us to know the ID attribute from the <stream:stream/> element.
			
			[buffer appendData:[@"</stream:stream>" dataUsingEncoding:NSUTF8StringEncoding]];
			
			NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithData:buffer options:0 error:nil] autorelease];
			
			[rootElement release];
			rootElement = [[xmlDoc rootElement] retain];
			
			[buffer setLength:0];
			
			// Check for RFC compliance
			if([self serverXmppStreamVersionNumber] >= 1.0)
			{
				// Update state - we're now onto stream negotiations
				state = STATE_NEGOTIATING;
				
				// We need to read in the stream features now
				[asyncSocket readDataToData:terminator withTimeout:TIMEOUT_READ_STREAM tag:TAG_READ_STREAM];
			}
			else
			{
				// The server isn't RFC comliant, and won't be sending any stream features.
				
				// We would still like to know what authentication features it supports though,
				// so we'll use the jabber:iq:auth namespace, which was used prior to the RFC spec.
				
				// Update state - we're onto psuedo negotiation
				state = STATE_NEGOTIATING;
				
				NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:auth"];
				
				NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
				[iq addAttributeWithName:@"type" stringValue:@"get"];
				[iq addChild:query];
				
				if(DEBUG_SEND) {
					NSLog(@"SEND: %@", [iq XMLString]);
				}
				[asyncSocket writeData:[[iq XMLString] dataUsingEncoding:NSUTF8StringEncoding]
						   withTimeout:TIMEOUT_WRITE
								   tag:TAG_WRITE_STREAM];
				
				// Read the response IQ
				[asyncSocket readDataToData:terminator withTimeout:TIMEOUT_READ_STREAM tag:TAG_READ_STREAM];
			}
		}
		return;
	}
	
	// We encountered the end of some tag. IE - we found a ">" character.
	
	// Is it the end of the stream?
	if([dataAsStr hasSuffix:@"</stream:stream>"])
	{
		// We can close our TCP connection now
		[self disconnect];
		
		// The onSocketDidDisconnect: method will handle everything else
		return;
	}
	
	// Add the given data to our buffer, and try parsing the data
	// If the parsing works, we have found an entire XML message fragment.
	
	// Work-around for problem in NSXMLDocument parsing
	// The parser doesn't like <stream:X> tags unless they're properly namespaced
	// This namespacing is declared in the opening <stream:stream> tag, but we only parse individual elements
	if([dataAsStr isEqualToString:@"<stream:features>"])
	{
		NSString *fix = @"<stream:features xmlns:stream='http://etherx.jabber.org/streams'>";
		[buffer appendData:[fix dataUsingEncoding:NSUTF8StringEncoding]];
	}
	else if([dataAsStr isEqualToString:@"<stream:error>"])
	{
		NSString *fix = @"<stream:error xmlns:stream='http://etherx.jabber.org/streams'>";
		[buffer appendData:[fix dataUsingEncoding:NSUTF8StringEncoding]];
	}
	else
	{
		[buffer appendData:data];
	}
	
	NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithData:buffer options:0 error:nil] autorelease];
	
	if(!xmlDoc)
	{
		// We don't have a full XML message fragment yet
		// Keep reading data from the stream until we get a full fragment
		[asyncSocket readDataToData:terminator withTimeout:TIMEOUT_READ_STREAM tag:TAG_READ_STREAM];
		return;
	}
	
	NSXMLElement *element = [xmlDoc rootElement];
	
	if(state == STATE_NEGOTIATING)
	{
		// We've just read in the stream features
		// We considered part of the root element, so we'll add it (replacing any previously sent features)
		[element detach];
		[rootElement setChildren:[NSArray arrayWithObject:element]];
		
		// Call a method to handle any requirements set forth in the features
		[self handleStreamFeatures];
	}
	else if(state == STATE_STARTTLS)
	{
		// The response from our starttls message
		[self handleStartTLSResponse:element];
	}
	else if(state == STATE_REGISTERING)
	{
		// The iq response from our registration request
		[self handleRegistration:element];
	}
	else if(state == STATE_AUTH_1)
	{
		// The challenge response from our auth message
		[self handleAuth1:element];
	}
	else if(state == STATE_AUTH_2)
	{
		// The response from our challenge response
		[self handleAuth2:element];
	}
	else if(state == STATE_BINDING)
	{
		// The response from our binding request
		[self handleBinding:element];
	}
	else if(state == STATE_START_SESSION)
	{
		// The response from our start session request
		[self handleStartSessionResponse:element];
	}
	else if([[element name] isEqualToString:@"iq"])
	{
		if([delegate respondsToSelector:@selector(xmppStream:didReceiveIQ:)])
		{
			[delegate xmppStream:self didReceiveIQ:[XMPPIQ iqFromElement:element]];
		}
		else if(DEBUG_DELEGATE)
		{
			NSLog(@"xmppStream:%p didReceiveIQ:%@", self, [element XMLString]);
		}
	}
	else if([[element name] isEqualToString:@"message"])
	{
		if([delegate respondsToSelector:@selector(xmppStream:didReceiveMessage:)])
		{
			[delegate xmppStream:self didReceiveMessage:[XMPPMessage messageFromElement:element]];
		}
		else if(DEBUG_DELEGATE)
		{
			NSLog(@"xmppStream:%p didReceiveMessage:%@", self, [element XMLString]);
		}
	}
	else if([[element name] isEqualToString:@"presence"])
	{
		if([delegate respondsToSelector:@selector(xmppStream:didReceivePresence:)])
		{
			[delegate xmppStream:self didReceivePresence:[XMPPPresence presenceFromElement:element]];
		}
		else if(DEBUG_DELEGATE)
		{
			NSLog(@"xmppStream:%p didReceivePresence:%@", self, [element XMLString]);
		}
	}
	else
	{
		if([delegate respondsToSelector:@selector(xmppStream:didReceiveError:)])
		{
			[delegate xmppStream:self didReceiveError:element];
		}
		else if(DEBUG_DELEGATE)
		{
			NSLog(@"xmppStream:%p didReceiveError:%@", self, [element XMLString]);
		}
	}
	
	// Clear the buffer
	[buffer setLength:0];
	
	// Continue reading for XML fragments
	// Double-check to make sure we're still connected first though - the delegate could have called disconnect
	if([asyncSocket isConnected])
	{
		[asyncSocket readDataToData:terminator withTimeout:TIMEOUT_READ_STREAM tag:TAG_READ_STREAM];
	}
}

/**
 * Called after data with the given tag has been successfully sent.
**/
- (void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag
{
	if((tag != TAG_WRITE_STREAM) && (tag != TAG_WRITE_START))
	{
		if([delegate respondsToSelector:@selector(xmppStream:didSendElementWithTag:)])
		{
			[delegate xmppStream:self didSendElementWithTag:tag];
		}
	}
}

/**
 * In the event of an error, the socket is closed.  You may call "readDataWithTimeout:tag:" during this call-back to
 * get the last bit of data off the socket.  When connecting, this delegate method may be called
 * before onSocket:didConnectToHost:
**/
- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err
{
	if([delegate respondsToSelector:@selector(xmppStream:didReceiveError:)]) {
		[delegate xmppStream:self didReceiveError:err];
	}
	else if(DEBUG_DELEGATE) {
		NSLog(@"xmppStream:%p didReceiveError:%@", self, err);
	}
}

/**
 * Called when a socket disconnects with or without error.  If you want to release a socket after it disconnects,
 * do so here. It is not safe to do that during "onSocket:willDisconnectWithError:".
**/
- (void)onSocketDidDisconnect:(AsyncSocket *)sock
{
	// Update state
	state = STATE_DISCONNECTED;
	
	// Update configuration
	[self setIsSecure:NO];
	[self setIsAuthenticated:NO];
	
	// Clear the buffer
	[buffer setLength:0];
	
	// Clear the root element
	[rootElement release]; rootElement = nil;
	
	// Clear any saved authentication information
	[authUsername release]; authUsername = nil;
	[authResource release]; authResource = nil;
	[tempPassword release]; tempPassword = nil;
	
	// Stop the keep alive timer
	[keepAliveTimer invalidate];
	[keepAliveTimer release];
	keepAliveTimer = nil;
	
	// Notify delegate
	if([delegate respondsToSelector:@selector(xmppStreamDidClose:)]) {
		[delegate xmppStreamDidClose:self];
	}
	else if(DEBUG_DELEGATE) {
		NSLog(@"xmppStreamDidClose:%p", self);
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Helper Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)keepAlive:(NSTimer *)aTimer
{
	if(state == STATE_CONNECTED)
	{
		[asyncSocket writeData:[@" " dataUsingEncoding:NSUTF8StringEncoding]
				   withTimeout:TIMEOUT_WRITE
						   tag:TAG_WRITE_STREAM];
	}
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPDigestAuthentication

- (id)initWithChallenge:(NSXMLElement *)challenge
{
	if((self = [super init]))
	{
		// Convert the base 64 encoded data into a string
		NSData *base64Data = [[challenge stringValue] dataUsingEncoding:NSASCIIStringEncoding];
		NSData *decodedData = [base64Data base64Decoded];
		
		NSString *authStr = [[[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding] autorelease];
		
		DDLogRecv(@"decoded challenge: %@", authStr);
		
		// Extract all the key=value pairs, and put them in a dictionary for easy lookup
		NSMutableDictionary *auth = [NSMutableDictionary dictionaryWithCapacity:5];
		
		NSArray *components = [authStr componentsSeparatedByString:@","];
		
		int i;
		for(i = 0; i < [components count]; i++)
		{
			NSString *component = [components objectAtIndex:i];
			
			NSRange separator = [component rangeOfString:@"="];
			if(separator.location != NSNotFound)
			{
				NSMutableString *key = [[component substringToIndex:separator.location] mutableCopy];
				NSMutableString *value = [[component substringFromIndex:separator.location+1] mutableCopy];
				
				if(key) CFStringTrimWhitespace((CFMutableStringRef)key);
				if(value) CFStringTrimWhitespace((CFMutableStringRef)value);
				
				if([value hasPrefix:@"\""] && [value hasSuffix:@"\""] && [value length] > 2)
				{
					// Strip quotes from value
					[value deleteCharactersInRange:NSMakeRange(0, 1)];
					[value deleteCharactersInRange:NSMakeRange([value length]-1, 1)];
				}
				
				[auth setObject:value forKey:key];
				
				[value release];
				[key release];
			}
		}
		
		// Extract and retain the elements we need
		rspauth = [[auth objectForKey:@"rspauth"] copy];
		realm = [[auth objectForKey:@"realm"] copy];
		nonce = [[auth objectForKey:@"nonce"] copy];
		qop = [[auth objectForKey:@"qop"] copy];
		
		// Generate cnonce
		CFUUIDRef theUUID = CFUUIDCreate(NULL);
		cnonce = (NSString *)CFUUIDCreateString(NULL, theUUID);
		CFRelease(theUUID);
	}
	return self;
}

- (void)dealloc
{
	[rspauth release];
	[realm release];
	[nonce release];
	[qop release];
	[username release];
	[password release];
	[cnonce release];
	[nc release];
	[digestURI release];
	[super dealloc];
}

- (NSString *)rspauth
{
	return [[rspauth copy] autorelease];
}

- (NSString *)realm
{
	return [[realm copy] autorelease];
}

- (void)setRealm:(NSString *)newRealm
{
	if(![realm isEqual:newRealm])
	{
		[realm release];
		realm = [newRealm copy];
	}
}

- (void)setDigestURI:(NSString *)newDigestURI
{
	if(![digestURI isEqual:newDigestURI])
	{
		[digestURI release];
		digestURI = [newDigestURI copy];
	}
}

- (void)setUsername:(NSString *)newUsername password:(NSString *)newPassword
{
	if(![username isEqual:newUsername])
	{
		[username release];
		username = [newUsername copy];
	}
	
	if(![password isEqual:newPassword])
	{
		[password release];
		password = [newPassword copy];
	}
}

- (NSString *)response
{
	NSString *HA1str = [NSString stringWithFormat:@"%@:%@:%@", username, realm, password];
	NSString *HA2str = [NSString stringWithFormat:@"AUTHENTICATE:%@", digestURI];
	
	NSData *HA1dataA = [[HA1str dataUsingEncoding:NSUTF8StringEncoding] md5Digest];
	NSData *HA1dataB = [[NSString stringWithFormat:@":%@:%@", nonce, cnonce] dataUsingEncoding:NSUTF8StringEncoding];
	
	NSMutableData *HA1data = [NSMutableData dataWithCapacity:([HA1dataA length] + [HA1dataB length])];
	[HA1data appendData:HA1dataA];
	[HA1data appendData:HA1dataB];
	
	NSString *HA1 = [[HA1data md5Digest] hexStringValue];
	
	NSString *HA2 = [[[HA2str dataUsingEncoding:NSUTF8StringEncoding] md5Digest] hexStringValue];
	
	NSString *responseStr = [NSString stringWithFormat:@"%@:%@:00000001:%@:auth:%@",
		HA1, nonce, cnonce, HA2];
	
	NSString *response = [[[responseStr dataUsingEncoding:NSUTF8StringEncoding] md5Digest] hexStringValue];
	
	return response;
}

- (NSString *)base64EncodedFullResponse
{
	NSMutableString *buffer = [NSMutableString stringWithCapacity:100];
	[buffer appendFormat:@"username=\"%@\",", username];
	[buffer appendFormat:@"realm=\"%@\",", realm];
	[buffer appendFormat:@"nonce=\"%@\",", nonce];
	[buffer appendFormat:@"cnonce=\"%@\",", cnonce];
	[buffer appendFormat:@"nc=00000001,"];
	[buffer appendFormat:@"qop=auth,"];
	[buffer appendFormat:@"digest-uri=\"%@\",", digestURI];
	[buffer appendFormat:@"response=%@,", [self response]];
	[buffer appendFormat:@"charset=utf-8"];
	
	DDLogSend(@"decoded response: %@", buffer);
	
	NSData *utf8data = [buffer dataUsingEncoding:NSUTF8StringEncoding];
	
	return [utf8data base64Encoded];
}

@end
