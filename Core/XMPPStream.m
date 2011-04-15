#import "XMPPStream.h"
#import "AsyncSocket.h"
#import "MulticastDelegate.h"
#import "RFSRVResolver.h"
#import "XMPPParser.h"
#import "XMPPJID.h"
#import "XMPPIQ.h"
#import "XMPPMessage.h"
#import "XMPPPresence.h"
#import "XMPPModule.h"
#import "NSDataAdditions.h"
#import "NSXMLElementAdditions.h"

#if TARGET_OS_IPHONE
  // Note: You may need to add the CFNetwork Framework to your project
  #import <CFNetwork/CFNetwork.h>
#endif


NSString *const XMPPStreamErrorDomain = @"XMPPStreamErrorDomain";

enum XMPPStreamFlags
{
	kP2PMode                      = 1 << 0,  // If set, the XMPPStream was initialized in P2P mode
	kP2PInitiator                 = 1 << 1,  // If set, we are the P2P initializer
	kIsSecure                     = 1 << 2,  // If set, connection has been secured via SSL/TLS
	kIsAuthenticated              = 1 << 3,  // If set, authentication has succeeded
	kResetByteCountPerConnection  = 1 << 4,  // If set, byte count should be reset per connection
	kSynchronousSendPending       = 1 << 5,  // If set, a synchronous send is in progress
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface XMPPDigestAuthentication : NSObject
{
	NSString *rspauth;
	NSString *realm;
	NSString *nonce;
	NSString *qop;
	NSString *username;
	NSString *password;
	NSString *cnonce;
	NSString *nc;
	NSString *digestURI;
}

- (id)initWithChallenge:(NSXMLElement *)challenge;

- (NSString *)rspauth;

- (NSString *)realm;
- (void)setRealm:(NSString *)realm;

- (void)setDigestURI:(NSString *)digestURI;

- (void)setUsername:(NSString *)username password:(NSString *)password;

- (NSString *)response;
- (NSString *)base64EncodedFullResponse;

@end

@interface XMPPStream (PrivateAPI)

- (void)setIsSecure:(BOOL)flag;

- (void)sendOpeningNegotiation;
- (void)setupKeepAliveTimer;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPStream

@synthesize hostName;
@synthesize hostPort;
@synthesize myJID;
@synthesize remoteJID;
@synthesize keepAliveInterval;
@synthesize myPresence;
@synthesize numberOfBytesSent;
@synthesize numberOfBytesReceived;
@synthesize registeredModules;
@synthesize tag = userTag;

@dynamic resetByteCountPerConnection;

/**
 * Shared initialization between the various init methods.
**/
- (void)commonInit
{
	multicastDelegate = [[MulticastDelegate alloc] init];
	
	state = STATE_DISCONNECTED;
	
	numberOfBytesSent = 0;
	numberOfBytesReceived = 0;
	
	parser = [(XMPPParser *)[XMPPParser alloc] initWithDelegate:self];
	
	hostPort = 5222;
	keepAliveInterval = DEFAULT_KEEPALIVE_INTERVAL;
	
	registeredModules = [[MulticastDelegate alloc] init];
	autoDelegateDict = [[NSMutableDictionary alloc] init];
}

/**
 * Standard XMPP initialization.
 * The stream is a standard client to server connection.
**/
- (id)init
{
	if ((self = [super init]))
	{
		// Common initialization
		[self commonInit];
		
		// Initialize socket
		asyncSocket = [(AsyncSocket *)[AsyncSocket alloc] initWithDelegate:self];
		
		// Initialize configuration
		flags = 0;
	}
	return self;
}

/**
 * Peer to Peer XMPP initialization.
 * The stream is a direct client to client connection as outlined in XEP-0174.
**/
- (id)initP2PFrom:(XMPPJID *)jid
{
    if ((self = [super init]))
    {
		// Common initialization
		[self commonInit];
		
		// Store JID
		myJID = [jid retain];
        
        // We do not initialize the socket, since the connectP2PWithSocket: method might be used.
        
        // Initialize configuration
        flags = kP2PMode;
    }
	return self;
}

/**
 * Standard deallocation method.
 * Every object variable declared in the header file should be released here.
**/
- (void)dealloc
{
	[multicastDelegate release];
	
	[asyncSocket setDelegate:nil];
	[asyncSocket disconnect];
	[asyncSocket release];
	
	[parser stop];
	[parser release];
	
	[hostName release];
	
	[tempPassword release];
	
	[myJID release];
	[remoteJID release];
	
	[myPresence release];
	[rootElement release];
	
	[keepAliveTimer invalidate];
	[keepAliveTimer release];
	
	[registeredModules release];
	[autoDelegateDict release];
	
	[srvResolver release];
	[srvResults release];
	
	[synchronousUUID release];
    
    [userTag release];
	
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Configuration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)addDelegate:(id)delegate
{
	[multicastDelegate addDelegate:delegate];
}

- (void)removeDelegate:(id)delegate
{
	[multicastDelegate removeDelegate:delegate];
}

/**
 * Returns YES if the stream was opened in P2P mode.
 * In other words, the stream was created via initP2PFrom: to use XEP-0174.
**/
- (BOOL)isP2P
{
    return (flags & kP2PMode) ? YES : NO;
}

- (BOOL)isP2PInitiator
{
    return (flags & (kP2PMode | kP2PInitiator)) ? YES : NO;
}

- (BOOL)isP2PRecipient
{
    if (flags & kP2PMode)
    {
        return (flags & kP2PInitiator) ? NO : YES;
    }
    return NO;
}

- (BOOL)resetByteCountPerConnection
{
	return (flags & kResetByteCountPerConnection) ? YES : NO;
}

- (void)setResetByteCountPerConnection:(BOOL)flag
{
	if (flag)
		flags |= kResetByteCountPerConnection;
	else
		flags &= ~kResetByteCountPerConnection;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Connection State
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark C2S Connection
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)connectToHost:(NSString *)host onPort:(UInt16)port error:(NSError **)errPtr
{
	state = STATE_CONNECTING;
	
	BOOL result = [asyncSocket connectToHost:host onPort:port error:errPtr];
	
	if (result == NO)
	{
		state = STATE_DISCONNECTED;
	}
	else if ([self resetByteCountPerConnection])
	{
		numberOfBytesSent = 0;
		numberOfBytesReceived = 0;
	}
	
	return result;
}

- (BOOL)connect:(NSError **)errPtr
{
	if (state > STATE_RESOLVING_SRV)
	{
		if (errPtr)
		{
			NSString *errMsg = @"Attempting to connect while already connected or connecting.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			*errPtr = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
		}
		return NO;
	}
	
	if ([self isP2P])
    {
		if (errPtr)
		{
			NSString *errMsg = @"P2P streams must use either connectTo:withAddress: or connectP2PWithSocket:.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			*errPtr = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidType userInfo:info];
		}
		return NO;
    }
	
	if (myJID == nil)
	{
		// Note: If you wish to use anonymous authentication, you should still set myJID prior to calling connect.
		// You can simply set it to something like "anonymous@<domain>", where "<domain>" is the proper domain.
		// After the authentication process, you can query the myJID property to see what your assigned JID is.
		// 
		// Setting myJID allows the framework to follow the xmpp protocol properly,
		// and it allows the framework to connect to servers without a DNS entry.
		// 
		// For example, one may setup a private xmpp server for internal testing on their local network.
		// The xmpp domain of the server may be something like "testing.mycompany.com",
		// but since the server is internal, an IP (192.168.1.22) is used as the hostname to connect.
		// 
		// Proper connection requires a TCP connection to the IP (192.168.1.22),
		// but the xmpp handshake requires the xmpp domain (testing.mycompany.com).
		
		if (errPtr)
		{
			NSString *errMsg = @"You must set myJID before calling connect.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			*errPtr = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidProperty userInfo:info];
		}
		return NO;
	}

    // Notify delegates
    [multicastDelegate xmppStreamWillConnect:self];

	if ([hostName length] == 0)
	{
		// Resolve the hostName via myJID SRV resolution
		
		state = STATE_RESOLVING_SRV;
		
		[srvResolver release];
		srvResolver = [[RFSRVResolver resolveWithStream:self delegate:self] retain];
		
		return YES;
	}
	else
	{
		// Open TCP connection to the configured hostName.
		
		return [self connectToHost:hostName onPort:hostPort error:errPtr];
	}
}

- (BOOL)oldSchoolSecureConnect:(NSError **)errPtr
{
	// Mark the secure flag.
	// We will check the flag in onSocket:didConnectToHost:port:
	[self setIsSecure:YES];
	
	// Then go through the regular connect routine
	return [self connect:errPtr];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark P2P Connection
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Starts a P2P connection to the given user and given address.
 * This method only works with XMPPStream objects created using the initP2P method.
 * 
 * The given address is specified as a sockaddr structure wrapped in a NSData object.
 * For example, a NSData object returned from NSNetservice's addresses method.
**/
- (BOOL)connectTo:(XMPPJID *)jid withAddress:(NSData *)remoteAddr error:(NSError **)errPtr
{
	if (state != STATE_DISCONNECTED)
	{
		if (errPtr)
		{
			NSString *errMsg = @"Attempting to connect while already connected or connecting.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			*errPtr = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
		}
		return NO;
	}
	
	if (![self isP2P])
    {
		if (errPtr)
		{
			NSString *errMsg = @"Non P2P streams must use the connect: method";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			*errPtr = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidType userInfo:info];
		}
		return NO;
    }
    
	// Turn on P2P initiator flag
	flags |= kP2PInitiator;
	
	// Store remoteJID
    [remoteJID release];
	remoteJID = [jid copy];
	
	NSAssert((asyncSocket == nil), @"Forgot to release the previous asyncSocket instance.");

    // Notify delegates
    [multicastDelegate xmppStreamWillConnect:self];

	// Update state
	state = STATE_CONNECTING;
	
	// Initailize socket
	asyncSocket = [(AsyncSocket *)[AsyncSocket alloc] initWithDelegate:self];
	
	BOOL result = [asyncSocket connectToAddress:remoteAddr error:errPtr];
	
	if (result == NO)
	{
		state = STATE_DISCONNECTED;
    }
	else if ([self resetByteCountPerConnection])
	{
		numberOfBytesSent = 0;
		numberOfBytesReceived = 0;
	}
	
	return result;
}

/**
 * Starts a P2P connection with the given accepted socket.
 * This method only works with XMPPStream objects created using the initP2P method.
 * 
 * The given socket should be a socket that has already been accepted.
 * The remoteJID will be extracted from the opening stream negotiation.
**/
- (BOOL)connectP2PWithSocket:(AsyncSocket *)acceptedSocket error:(NSError **)errPtr
{
	if (state != STATE_DISCONNECTED)
	{
		if (errPtr)
		{
			NSString *errMsg = @"Attempting to connect while already connected or connecting.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			*errPtr = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
		}
		return NO;
	}
	
	if (![self isP2P])
    {
		if (errPtr)
		{
			NSString *errMsg = @"Non P2P streams must use the connect: method";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			*errPtr = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidType userInfo:info];
		}
		return NO;
    }
	
	if (acceptedSocket == nil)
	{
		if (errPtr)
		{
			NSString *errMsg = @"Parameter acceptedSocket is nil.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			*errPtr = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidParameter userInfo:info];
		}
		return NO;
	}
	
    // Turn off P2P initiator flag
	flags &= ~kP2PInitiator;
	
	NSAssert((asyncSocket == nil), @"Forgot to release the previous asyncSocket instance.");
	
	// Store and configure socket
    asyncSocket = [acceptedSocket retain];
	[asyncSocket setDelegate:self];
	
    // Notify delegates
    [multicastDelegate xmppStreamWillConnect:self];

	// Update state
	state = STATE_CONNECTING;
	
	if ([self resetByteCountPerConnection])
	{
		numberOfBytesSent = 0;
		numberOfBytesReceived = 0;
	}
	
	if ([acceptedSocket isConnected])
	{
		// Initialize the XML stream
		[self sendOpeningNegotiation];
		
		// And start reading in the server's XML stream
		[asyncSocket readDataWithTimeout:TIMEOUT_READ_START tag:TAG_READ_START];
	}
	else
	{
		// We'll wait for the onSocket:didConnectToHost:onPort: method which will handle everything for us.
	}
	
    return YES;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Disconnect
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Closes the connection to the remote host.
**/
- (void)disconnect
{
	[multicastDelegate xmppStreamWasToldToDisconnect:self];
	[asyncSocket disconnect];
	
	// Note: The state is updated automatically in the onSocketDidDisconnect: method.
}

- (void)disconnectAfterSending
{
	[multicastDelegate xmppStreamWasToldToDisconnect:self];
	[asyncSocket disconnectAfterWriting];
	
	// Note: The state is updated automatically in the onSocketDidDisconnect: method.
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Security
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns YES if SSL/TLS has been used to secure the connection.
**/
- (BOOL)isSecure
{
	return (flags & kIsSecure) ? YES : NO;
}
- (void)setIsSecure:(BOOL)flag
{
	if(flag)
		flags |= kIsSecure;
	else
		flags &= ~kIsSecure;
}

- (BOOL)supportsStartTLS
{
	// The root element can be properly queried for authentication mechanisms anytime after the
	//stream:features are received, and TLS has been setup (if required)
	if (state > STATE_STARTTLS)
	{
		NSXMLElement *features = [rootElement elementForName:@"stream:features"];
		NSXMLElement *starttls = [features elementForName:@"starttls" xmlns:@"urn:ietf:params:xml:ns:xmpp-tls"];
		
		return (starttls != nil);
	}
	return NO;
}

- (void)sendStartTLSRequest
{
	NSString *starttls = @"<starttls xmlns='urn:ietf:params:xml:ns:xmpp-tls'/>";
	
	NSData *outgoingData = [starttls dataUsingEncoding:NSUTF8StringEncoding];
	
	DDLogSend(@"SEND: %@", starttls);
	numberOfBytesSent += [outgoingData length];
	
	[asyncSocket writeData:outgoingData
			   withTimeout:TIMEOUT_WRITE
					   tag:TAG_WRITE_STREAM];
}

- (BOOL)secureConnection:(NSError **)errPtr
{
	if (state != STATE_CONNECTED)
	{
		if (errPtr)
		{
			NSString *errMsg = @"Please wait until the stream is connected.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			*errPtr = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
		}
		return NO;
	}
	
	if (![self supportsStartTLS])
	{
		if (errPtr)
		{
			NSString *errMsg = @"The server does not support startTLS.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			*errPtr = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamUnsupportedAction userInfo:info];
		}
		return NO;
	}
	
	// Update state
	state = STATE_STARTTLS;
	
	// Send the startTLS XML request
	[self sendStartTLSRequest];
	
	// We do not mark the stream as secure yet.
	// We're waiting to receive the <proceed/> response from the
	// server before we actually start the TLS handshake.
	
	return YES;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Registration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method checks the stream features of the connected server to determine if in-band registartion is supported.
 * If we are not connected to a server, this method simply returns NO.
**/
- (BOOL)supportsInBandRegistration
{
	// The root element can be properly queried for authentication mechanisms anytime after the
	//stream:features are received, and TLS has been setup (if required)
	if (state > STATE_STARTTLS)
	{
		NSXMLElement *features = [rootElement elementForName:@"stream:features"];
		NSXMLElement *reg = [features elementForName:@"register" xmlns:@"http://jabber.org/features/iq-register"];
		
		return (reg != nil);
	}
	return NO;
}

/**
 * This method attempts to register a new user on the server using the given username and password.
 * The result of this action will be returned via the delegate methods.
 * 
 * If the XMPPStream is not connected, or the server doesn't support in-band registration, this method does nothing.
**/
- (BOOL)registerWithPassword:(NSString *)password error:(NSError **)errPtr
{
	if (state != STATE_CONNECTED)
	{
		if (errPtr)
		{
			NSString *errMsg = @"Please wait until the stream is connected.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			*errPtr = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
		}
		return NO;
	}
	
	if (myJID == nil)
	{
		if (errPtr)
		{
			NSString *errMsg = @"You must set myJID before calling registerWithPassword:error:.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			*errPtr = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidProperty userInfo:info];
		}
		return NO;
	}
	
	if (![self supportsInBandRegistration])
	{
		if (errPtr)
		{
			NSString *errMsg = @"The server does not support in band registration.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			*errPtr = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamUnsupportedAction userInfo:info];
		}
		return NO;
	}
	
	NSString *username = [myJID user];
	
	NSXMLElement *queryElement = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:register"];
	[queryElement addChild:[NSXMLElement elementWithName:@"username" stringValue:username]];
	[queryElement addChild:[NSXMLElement elementWithName:@"password" stringValue:password]];
	
	NSXMLElement *iqElement = [NSXMLElement elementWithName:@"iq"];
	[iqElement addAttributeWithName:@"type" stringValue:@"set"];
	[iqElement addChild:queryElement];
	
	NSString *outgoingStr = [iqElement compactXMLString];
	NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
	
	DDLogSend(@"SEND: %@", outgoingStr);
	numberOfBytesSent += [outgoingData length];
	
	[asyncSocket writeData:outgoingData
	           withTimeout:TIMEOUT_WRITE
	                   tag:TAG_WRITE_STREAM];
	
	// Update state
	state = STATE_REGISTERING;
	
	return YES;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Authentication
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method checks the stream features of the connected server to determine if SASL Anonymous Authentication (XEP-0175)
 * is supported. If we are not connected to a server, this method simply returns NO.
 **/
- (BOOL)supportsAnonymousAuthentication
{
	// The root element can be properly queried for authentication mechanisms anytime after the
	// stream:features are received, and TLS has been setup (if required)
	if (state > STATE_STARTTLS)
	{
		NSXMLElement *features = [rootElement elementForName:@"stream:features"];
		NSXMLElement *mech = [features elementForName:@"mechanisms" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
		
		NSArray *mechanisms = [mech elementsForName:@"mechanism"];
		
		for (NSXMLElement *mechanism in mechanisms)
		{
			if ([[mechanism stringValue] isEqualToString:@"ANONYMOUS"])
			{
				return YES;
			}
		}
	}
	return NO;
}

/**
 * This method checks the stream features of the connected server to determine if plain authentication is supported.
 * If we are not connected to a server, this method simply returns NO.
**/
- (BOOL)supportsPlainAuthentication
{
	// The root element can be properly queried for authentication mechanisms anytime after the
	//stream:features are received, and TLS has been setup (if required)
	if (state > STATE_STARTTLS)
	{
		NSXMLElement *features = [rootElement elementForName:@"stream:features"];
		NSXMLElement *mech = [features elementForName:@"mechanisms" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
		
		NSArray *mechanisms = [mech elementsForName:@"mechanism"];
		
		for (NSXMLElement *mechanism in mechanisms)
		{
			if ([[mechanism stringValue] isEqualToString:@"PLAIN"])
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
	// The root element can be properly queried for authentication mechanisms anytime after the
	// stream:features are received, and TLS has been setup (if required)
	if (state > STATE_STARTTLS)
	{
		NSXMLElement *features = [rootElement elementForName:@"stream:features"];
		NSXMLElement *mech = [features elementForName:@"mechanisms" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
		
		NSArray *mechanisms = [mech elementsForName:@"mechanism"];
		
		for (NSXMLElement *mechanism in mechanisms)
		{
			if ([[mechanism stringValue] isEqualToString:@"DIGEST-MD5"])
			{
				return YES;
			}
		}
	}
	return NO;
}

/**
 * This method only applies to servers that don't support XMPP version 1.0, as defined in RFC 3920.
 * With these servers, we attempt to discover supported authentication modes via the jabber:iq:auth namespace.
**/
- (BOOL)supportsDeprecatedPlainAuthentication
{
	// The root element can be properly queried for authentication mechanisms anytime after the
	// stream:features are received, and TLS has been setup (if required)
	if (state > STATE_STARTTLS)
	{
		// Search for an iq element within the rootElement.
		// Recall that some servers might stupidly add a "jabber:client" namespace which might cause problems
		// if we simply used the elementForName method.
		
		NSXMLElement *iq = nil;
		
		NSUInteger i, count = [rootElement childCount];
		for (i = 0; i < count; i++)
		{
			NSXMLNode *childNode = [rootElement childAtIndex:i];
			
			if ([childNode kind] == NSXMLElementKind)
			{
				if ([[childNode name] isEqualToString:@"iq"])
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
 * With these servers, we attempt to discover supported authentication modes via the jabber:iq:auth namespace.
**/
- (BOOL)supportsDeprecatedDigestAuthentication
{
	// The root element can be properly queried for authentication mechanisms anytime after the
	// stream:features are received, and TLS has been setup (if required)
	if (state > STATE_STARTTLS)
	{
		// Search for an iq element within the rootElement.
		// Recall that some servers might stupidly add a "jabber:client" namespace which might cause problems
		// if we simply used the elementForName method.
		
		NSXMLElement *iq = nil;
		
		NSUInteger i, count = [rootElement childCount];
		for (i = 0; i < count; i++)
		{
			NSXMLNode *childNode = [rootElement childAtIndex:i];
			
			if ([childNode kind] == NSXMLElementKind)
			{
				if ([[childNode name] isEqualToString:@"iq"])
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
 * This method attempts to sign-in to the server using the configured myJID and given password.
 * If this method immediately fails
**/
- (BOOL)authenticateWithPassword:(NSString *)password error:(NSError **)errPtr
{
	if (state != STATE_CONNECTED)
	{
		if (errPtr)
		{
			NSString *errMsg = @"Please wait until the stream is connected.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			*errPtr = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
		}
		return NO;
	}
	
	if (myJID == nil)
	{
		if (errPtr)
		{
			NSString *errMsg = @"You must set myJID before calling authenticateWithPassword:error:.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			*errPtr = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidProperty userInfo:info];
		}
		return NO;
	}
	
	if ([self supportsDigestMD5Authentication])
	{
		NSString *auth = @"<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' mechanism='DIGEST-MD5'/>";
		
		NSData *outgoingData = [auth dataUsingEncoding:NSUTF8StringEncoding];
		
		DDLogSend(@"SEND: %@", auth);
		numberOfBytesSent += [outgoingData length];
		
		[asyncSocket writeData:outgoingData
				   withTimeout:TIMEOUT_WRITE
						   tag:TAG_WRITE_STREAM];
		
		// Save authentication information
		[tempPassword release];
		tempPassword = [password copy];
		
		// Update state
		state = STATE_AUTH_1;
	}
	else if ([self supportsPlainAuthentication])
	{
		// From RFC 4616 - PLAIN SASL Mechanism:
		// [authzid] UTF8NUL authcid UTF8NUL passwd
		// 
		// authzid: authorization identity
		// authcid: authentication identity (username)
		// passwd : password for authcid
		
		NSString *username = [myJID user];
		
		NSString *payload = [NSString stringWithFormat:@"%C%@%C%@", 0, username, 0, password];
		NSString *base64 = [[payload dataUsingEncoding:NSUTF8StringEncoding] base64Encoded];
		
		NSXMLElement *auth = [NSXMLElement elementWithName:@"auth" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
		[auth addAttributeWithName:@"mechanism" stringValue:@"PLAIN"];
		[auth setStringValue:base64];
		
		NSString *outgoingStr = [auth compactXMLString];
		NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
		
		DDLogSend(@"SEND: %@", outgoingStr);
		numberOfBytesSent += [outgoingData length];
		
		[asyncSocket writeData:outgoingData
				   withTimeout:TIMEOUT_WRITE
						   tag:TAG_WRITE_STREAM];
		
		// Update state
		state = STATE_AUTH_1;
	}
	else
	{
		// The server does not appear to support SASL authentication (at least any type we can use)
		// So we'll revert back to the old fashioned jabber:iq:auth mechanism
		
		NSString *username = [myJID user];
		NSString *resource = [myJID resource];
		
		if ([resource length] == 0)
		{
			// If resource is nil or empty, we need to auto-create one
			
			resource = [self generateUUID];
		}
		
		NSXMLElement *queryElement = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:auth"];
		[queryElement addChild:[NSXMLElement elementWithName:@"username" stringValue:username]];
		[queryElement addChild:[NSXMLElement elementWithName:@"resource" stringValue:resource]];
		
		if ([self supportsDeprecatedDigestAuthentication])
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
		
		NSString *outgoingStr = [iqElement compactXMLString];
		NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
		
		DDLogSend(@"SEND: %@", outgoingStr);
		numberOfBytesSent += [outgoingData length];
		
		[asyncSocket writeData:outgoingData
				   withTimeout:TIMEOUT_WRITE
						   tag:TAG_WRITE_STREAM];
		
		// Update state
		state = STATE_AUTH_1;
	}
	
	return YES;
}

/**
 * This method attempts to sign-in to the using SASL Anonymous Authentication (XEP-0175)
 **/
- (BOOL)authenticateAnonymously:(NSError **)errPtr
{
	if (state != STATE_CONNECTED)
	{
		if (errPtr)
		{
			NSString *errMsg = @"Please wait until the stream is connected.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			*errPtr = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
		}
		return NO;
	}
	
	if (![self supportsAnonymousAuthentication])
	{
		if (errPtr)
		{
			NSString *errMsg = @"The server does not support anonymous authentication.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			*errPtr = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamUnsupportedAction userInfo:info];
			
		}
		return NO;
	}
	
	NSXMLElement *auth = [NSXMLElement elementWithName:@"auth" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
	[auth addAttributeWithName:@"mechanism" stringValue:@"ANONYMOUS"];
	
	NSString *outgoingStr = [auth compactXMLString];
	NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
	
	DDLogSend(@"SEND: %@", outgoingStr);
	numberOfBytesSent += [outgoingData length];
	
	[asyncSocket writeData:outgoingData
	           withTimeout:TIMEOUT_WRITE
	                   tag:TAG_WRITE_STREAM];
	
	// Update state
	state = STATE_AUTH_3;
	
	return YES;
}

- (BOOL)isAuthenticated
{
	return (flags & kIsAuthenticated) ? YES : NO;
}
- (void)setIsAuthenticated:(BOOL)flag
{
	if(flag)
		flags |= kIsAuthenticated;
	else
		flags &= ~kIsAuthenticated;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark General Methods
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
	return [rootElement attributeFloatValueForName:@"version" withDefaultValue:0.0F];
}

/**
 * Private method.
 * Presencts a common method for the various public sendElement methods.
**/
- (void)sendElement:(NSXMLElement *)element withTag:(long)tag
{
	if ([element isKindOfClass:[XMPPIQ class]])
	{
		[multicastDelegate xmppStream:self willSendIQ:(XMPPIQ *)element];
	}
	else if ([element isKindOfClass:[XMPPMessage class]])
	{
		[multicastDelegate xmppStream:self willSendMessage:(XMPPMessage *)element];
	}
	else if ([element isKindOfClass:[XMPPPresence class]])
	{
		[multicastDelegate xmppStream:self willSendPresence:(XMPPPresence *)element];
	}
	else
	{
		NSString *elementName = [element name];
		
		if ([elementName isEqualToString:@"iq"])
		{
			[multicastDelegate xmppStream:self willSendIQ:[XMPPIQ iqFromElement:element]];
		}
		else if ([elementName isEqualToString:@"message"])
		{
			[multicastDelegate xmppStream:self willSendMessage:[XMPPMessage messageFromElement:element]];
		}
		else if ([elementName isEqualToString:@"presence"])
		{
			[multicastDelegate xmppStream:self willSendPresence:[XMPPPresence presenceFromElement:element]];
		}
	}
	
	NSString *outgoingStr = [element compactXMLString];
	NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
	
	DDLogSend(@"SEND: %@", outgoingStr);
	numberOfBytesSent += [outgoingData length];
	
	[asyncSocket writeData:outgoingData
	           withTimeout:TIMEOUT_WRITE
	                   tag:tag];
	
	if ([element isKindOfClass:[XMPPIQ class]])
	{
		[multicastDelegate xmppStream:self didSendIQ:(XMPPIQ *)element];
	}
	else if ([element isKindOfClass:[XMPPMessage class]])
	{
		[multicastDelegate xmppStream:self didSendMessage:(XMPPMessage *)element];
	}
	else if ([element isKindOfClass:[XMPPPresence class]])
	{
		// Update myPresence if this is a normal presence element.
		// In other words, ignore presence subscription stuff, MUC room stuff, etc.
		
		XMPPPresence *presence = (XMPPPresence *)element;
		
		// We use the built-in [presence type] which guarantees lowercase strings,
		// and will return @"available" if there was no set type (as available is implicit).
		
		NSString *type = [presence type];
		if ([type isEqualToString:@"available"] || [type isEqualToString:@"unavailable"])
		{
			if ([presence toStr] == nil)
			{
				[myPresence release];
				myPresence = [presence retain];
			}
		}
		
		[multicastDelegate xmppStream:self didSendPresence:(XMPPPresence *)element];
	}
}

/**
 * This methods handles sending an XML fragment.
 * If the XMPPStream is not connected, this method does nothing.
**/
- (void)sendElement:(NSXMLElement *)element
{
	if (state == STATE_CONNECTED)
	{
		[self sendElement:element withTag:TAG_WRITE_STREAM];
	}
}

/**
 * This method handles sending an XML fragment.
 * If the XMPPStream is not connected, this method does nothing.
 * 
 * After the element has been successfully sent,
 * the xmppStream:didSendElementWithTag: delegate method is called.
**/
- (void)sendElement:(NSXMLElement *)element andNotifyMe:(UInt16)tag
{
	if (state == STATE_CONNECTED)
	{
		[self sendElement:element withTag:tag];
	}
}

- (BOOL)synchronouslySendElement:(NSXMLElement *)element
{
	if (state == STATE_CONNECTED)
	{
		NSString *innerRunLoopMode = @"XMPPStreamSynchronousMode";
		
		[self retain];
		[asyncSocket addRunLoopMode:innerRunLoopMode];
		
		flags |= kSynchronousSendPending;
		[self sendElement:element withTag:TAG_WRITE_SYNCHRONOUS];
		
		NSString *uuid = [self generateUUID];
		
		[synchronousUUID release];
		synchronousUUID = [uuid retain];
		
		BOOL noError = YES;
		while (noError && (uuid == synchronousUUID) && (flags & kSynchronousSendPending))
		{
			NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
			
			noError = [[NSRunLoop currentRunLoop] runMode:innerRunLoopMode
			                                   beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
			[innerPool release];
		}
		
		[asyncSocket removeRunLoopMode:innerRunLoopMode];
		[self autorelease];
		
		BOOL result = noError && (uuid == synchronousUUID);
		
		[synchronousUUID release];
		synchronousUUID = nil;
		
		return result;
	}
	
	return NO;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Stream Negotiation
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method handles sending the opening <stream:stream ...> element which is needed in several situations.
**/
- (void)sendOpeningNegotiation
{
	BOOL isRenegotiation = NO;
	
	if (state == STATE_CONNECTING)
	{
		// TCP connection was just opened - We need to include the opening XML stanza
		NSString *s1 = @"<?xml version='1.0'?>";
		
		NSData *outgoingData = [s1 dataUsingEncoding:NSUTF8StringEncoding];
		
		DDLogSend(@"SEND: %@", s1);
		numberOfBytesSent += [outgoingData length];
		
		[asyncSocket writeData:outgoingData
				   withTimeout:TIMEOUT_WRITE
						   tag:TAG_WRITE_START];
	}
	
	if (state != STATE_CONNECTING)
	{
		// We're restarting our negotiation.
		// This happens, for example, after securing the connection with SSL/TLS.
		isRenegotiation = YES;
		
		// Since we're restarting the XML stream, we need to reset the parser.
		[parser stop];
		[parser release];
		
		parser = [(XMPPParser *)[XMPPParser alloc] initWithDelegate:self];
	}
	else if (parser == nil)
	{
		// Need to create parser (it was destroyed when the socket was last disconnected)
		parser = [(XMPPParser *)[XMPPParser alloc] initWithDelegate:self];
	}
	
	NSString *xmlns = @"jabber:client";
	NSString *xmlns_stream = @"http://etherx.jabber.org/streams";
	
	NSString *temp, *s2;
    if ([self isP2P])
    {
		if (myJID && remoteJID)
		{
			temp = @"<stream:stream xmlns='%@' xmlns:stream='%@' version='1.0' from='%@' to='%@'>";
			s2 = [NSString stringWithFormat:temp, xmlns, xmlns_stream, [myJID bare], [remoteJID bare]];
		}
		else if (myJID)
		{
			temp = @"<stream:stream xmlns='%@' xmlns:stream='%@' version='1.0' from='%@'>";
			s2 = [NSString stringWithFormat:temp, xmlns, xmlns_stream, [myJID bare]];
		}
		else if (remoteJID)
		{
			temp = @"<stream:stream xmlns='%@' xmlns:stream='%@' version='1.0' to='%@'>";
			s2 = [NSString stringWithFormat:temp, xmlns, xmlns_stream, [remoteJID bare]];
		}
		else
		{
			temp = @"<stream:stream xmlns='%@' xmlns:stream='%@' version='1.0'>";
			s2 = [NSString stringWithFormat:temp, xmlns, xmlns_stream];
		}
    }
    else
    {
		if (myJID)
		{
			temp = @"<stream:stream xmlns='%@' xmlns:stream='%@' version='1.0' to='%@'>";
            s2 = [NSString stringWithFormat:temp, xmlns, xmlns_stream, [myJID domain]];
		}
        else if ([hostName length] > 0)
        {
            temp = @"<stream:stream xmlns='%@' xmlns:stream='%@' version='1.0' to='%@'>";
            s2 = [NSString stringWithFormat:temp, xmlns, xmlns_stream, hostName];
        }
        else
        {
            temp = @"<stream:stream xmlns='%@' xmlns:stream='%@' version='1.0'>";
            s2 = [NSString stringWithFormat:temp, xmlns, xmlns_stream];
        }
    }
	
	NSData *outgoingData = [s2 dataUsingEncoding:NSUTF8StringEncoding];
	
	DDLogSend(@"SEND: %@", s2);
	numberOfBytesSent += [outgoingData length];
	
	[asyncSocket writeData:outgoingData
			   withTimeout:TIMEOUT_WRITE
					   tag:TAG_WRITE_START];
	
	// Update status
	state = STATE_OPENING;
	
	// For a reneogitation, we need to manually read from the socket.
	// This is because we had to reset our parser, which is usually used to continue the reading process.
	if (isRenegotiation)
	{
		[asyncSocket readDataWithTimeout:TIMEOUT_READ_START tag:TAG_READ_START];
	}
}

/**
 * This method handles starting TLS negotiation on the socket, using the proper settings.
**/
- (void)startTLS
{
	// Create a mutable dictionary for security settings
	NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithCapacity:5];
	
	// Prompt the delegate(s) to populate the security settings
	[multicastDelegate xmppStream:self willSecureWithSettings:settings];
	
	// If the delegates didn't respond
	if ([settings count] == 0)
	{
		// Use the default settings, and set the peer name
		if (hostName)
		{
			[settings setObject:hostName forKey:(NSString *)kCFStreamSSLPeerName];
		}
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
	
	if (f_starttls)
	{
		if ([f_starttls elementForName:@"required"])
		{
			// TLS is required for this connection
			
			// Update state
			state = STATE_STARTTLS;
			
			// Send the startTLS XML request
			[self sendStartTLSRequest];
			
			// We do not mark the stream as secure yet.
			// We're waiting to receive the <proceed/> response from the
			// server before we actually start the TLS handshake.
			
			// We're already listening for the response...
			return;
		}
	}
	
	// Check to see if resource binding is required
	// Don't forget about that NSXMLElement bug you reported to apple (xmlns is required or element won't be found)
	NSXMLElement *f_bind = [features elementForName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
	
	if (f_bind)
	{
		// Binding is required for this connection
		state = STATE_BINDING;
		
		NSString *requestedResource = [myJID resource];
		
		if ([requestedResource length] > 0)
		{
			// Ask the server to bind the user specified resource
			
			NSXMLElement *resource = [NSXMLElement elementWithName:@"resource"];
			[resource setStringValue:requestedResource];
			
			NSXMLElement *bind = [NSXMLElement elementWithName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
			[bind addChild:resource];
			
			NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
			[iq addAttributeWithName:@"type" stringValue:@"set"];
			[iq addChild:bind];
			
			NSString *outgoingStr = [iq compactXMLString];
			NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
			
			DDLogSend(@"SEND: %@", outgoingStr);
			numberOfBytesSent += [outgoingData length];
			
			[asyncSocket writeData:outgoingData
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
			
			NSString *outgoingStr = [iq compactXMLString];
			NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
			
			DDLogSend(@"SEND: %@", outgoingStr);
			numberOfBytesSent += [outgoingData length];
			
			[asyncSocket writeData:outgoingData
					   withTimeout:TIMEOUT_WRITE
							   tag:TAG_WRITE_STREAM];
		}
		
		// We're already listening for the response...
		return;
	}
	
	// It looks like all has gone well, and the connection should be ready to use now
	state = STATE_CONNECTED;
	
	if (![self isAuthenticated])
	{
		[self setupKeepAliveTimer];
		
		// Notify delegates
		[multicastDelegate xmppStreamDidConnect:self];
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
		
		[multicastDelegate xmppStream:self didNotRegister:response];
	}
	else
	{
		// Revert back to connected state (from authenticating state)
		state = STATE_CONNECTED;
		
		[multicastDelegate xmppStreamDidRegister:self];
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
			
			[multicastDelegate xmppStream:self didNotAuthenticate:response];
		}
		else
		{
			// Create authentication object from the given challenge
			// We'll release this object at the end of this else block
			XMPPDigestAuthentication *auth = [[XMPPDigestAuthentication alloc] initWithChallenge:response];
			
			NSString *virtualHostName = [myJID domain];
			NSString *serverHostName = hostName;
			
			// Sometimes the realm isn't specified
			// In this case I believe the realm is implied as the virtual host name
			if (![auth realm])
			{
				if([virtualHostName length] > 0)
					[auth setRealm:virtualHostName];
				else
					[auth setRealm:serverHostName];
			}
			
			// Set digest-uri
			if([virtualHostName length] > 0)
				[auth setDigestURI:[NSString stringWithFormat:@"xmpp/%@", virtualHostName]];
			else
				[auth setDigestURI:[NSString stringWithFormat:@"xmpp/%@", serverHostName]];
			
			// Set username and password
			[auth setUsername:[myJID user] password:tempPassword];
			
			// Create and send challenge response element
			NSXMLElement *cr = [NSXMLElement elementWithName:@"response" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
			[cr setStringValue:[auth base64EncodedFullResponse]];
			
			NSString *outgoingStr = [cr compactXMLString];
			NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
			
			DDLogSend(@"SEND: %@", outgoingStr);
			numberOfBytesSent += [outgoingData length];
			
			[asyncSocket writeData:outgoingData
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
			
			[multicastDelegate xmppStream:self didNotAuthenticate:response];
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
			
			[multicastDelegate xmppStream:self didNotAuthenticate:response];
		}
		else
		{
			// We are successfully authenticated (via non-sasl:digest)
			// And we've binded our resource as well
			[self setIsAuthenticated:YES];
			
			// Revert back to connected state (from authenticating state)
			state = STATE_CONNECTED;
			
			[multicastDelegate xmppStreamDidAuthenticate:self];
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
			
			[multicastDelegate xmppStream:self didNotAuthenticate:response];
		}
		else
		{
			// We received another challenge, but it's really just an rspauth
			// This is supposed to be included in the success element (according to the updated RFC)
			// but many implementations incorrectly send it inside a second challenge request.
			
			// Create and send empty challenge response element
			NSXMLElement *cr = [NSXMLElement elementWithName:@"response" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
			
			NSString *outgoingStr = [cr compactXMLString];
			NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
			
			DDLogSend(@"SEND: %@", outgoingStr);
			numberOfBytesSent += [outgoingData length];
			
			[asyncSocket writeData:outgoingData
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
		
		[multicastDelegate xmppStream:self didNotAuthenticate:response];
	}
}

/**
 * This method handles the result of our SASL Anonymous Authentication challenge
**/
- (void)handleAuth3:(NSXMLElement *)response
{
	// We're expecting a success response
	// If we get anything else we can safely assume it's the equivalent of a failure response
	if(![[response name] isEqualToString:@"success"])
	{
		// Revert back to connected state (from authenticating state)
		state = STATE_CONNECTED;
		
		[multicastDelegate xmppStream:self didNotAuthenticate:response];
	}
	else
	{
		// We are successfully authenticated (via sasl:x-facebook-platform or sasl:plain)
		[self setIsAuthenticated:YES];
		
		// Now we start our negotiation over again...
		[self sendOpeningNegotiation];
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
		NSString *fullJIDStr = [r_jid stringValue];
		
		[myJID release];
		myJID = [[XMPPJID jidWithString:fullJIDStr] retain];
		
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
			
			NSString *outgoingStr = [iq compactXMLString];
			NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
			
			DDLogSend(@"SEND: %@", outgoingStr);
			numberOfBytesSent += [outgoingData length];
			
			[asyncSocket writeData:outgoingData
					   withTimeout:TIMEOUT_WRITE
							   tag:TAG_WRITE_STREAM];
			
			// Update state
			state = STATE_START_SESSION;
		}
		else
		{
			// Revert back to connected state (from binding state)
			state = STATE_CONNECTED;
			
			[multicastDelegate xmppStreamDidAuthenticate:self];
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
		
		NSString *outgoingStr = [iq compactXMLString];
		NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
		
		DDLogSend(@"SEND: %@", outgoingStr);
		numberOfBytesSent += [outgoingData length];
		
		[asyncSocket writeData:outgoingData
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
		
		[multicastDelegate xmppStreamDidAuthenticate:self];
	}
	else
	{
		// Revert back to connected state (from start session state)
		state = STATE_CONNECTED;
		
		[multicastDelegate xmppStream:self didNotAuthenticate:response];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark RFSRVResolver Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)tryNextSrvResult
{
    DDLogTrace();
	NSError *connectError = nil;
	BOOL success = NO;
	
	while (srvResultsIndex < [srvResults count])
	{
		RFSRVRecord *srvRecord = [srvResults objectAtIndex:srvResultsIndex];
		NSString *srvHost = srvRecord.target;
		UInt16 srvPort    = srvRecord.port;
		
		success = [self connectToHost:srvHost onPort:srvPort error:&connectError];
		
		if (success)
		{
			break;
		}
		else
		{
			srvResultsIndex++;
		}
	}
	
	if (!success)
	{
		// SRV resolution of the JID domain failed.
		// As per the RFC:
		// 
		// "If the SRV lookup fails, the fallback is a normal IPv4/IPv6 address record resolution
		// to determine the IP address, using the "xmpp-client" port 5222, registered with the IANA."
		// 
		// In other words, just try connecting to the domain specified in the JID.
		
		success = [self connectToHost:[myJID domain] onPort:5222 error:&connectError];
	}
	
	if (!success)
	{
		state = STATE_DISCONNECTED;
		
		[multicastDelegate xmppStream:self didReceiveError:connectError];
		[multicastDelegate xmppStreamDidDisconnect:self];
	}
}

- (void)srvResolverDidResoveSRV:(RFSRVResolver *)sender
{
    DDLogTrace();
	srvResults = [[sender results] copy];
	srvResultsIndex = 0;
	
	[self tryNextSrvResult];
}

- (void)srvResolver:(RFSRVResolver *)sender didNotResolveSRVWithError:(NSError *)srvError
{
    DDLogError(@"%s %@",__PRETTY_FUNCTION__,srvError);
    
	[self tryNextSrvResult];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark AsyncSocket Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)onSocketWillConnect:(AsyncSocket *)socket {
    [multicastDelegate xmppStream:self socketWillConnect:socket];

	return YES;
}

/**
 * Called when a socket connects and is ready for reading and writing. "host" will be an IP address, not a DNS name.
**/
- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
	// The TCP connection is now established
	
	[srvResolver release];
	srvResolver = nil;
	
	[srvResults release];
	srvResults = nil;
	
	// Are we using old-style SSL? (Not the upgrade to TLS technique specified in the XMPP RFC)
	if ([self isSecure])
	{
		// The connection must be secured immediately (just like with HTTPS)
		[self startTLS];
		
		// Note: We don't need to wait for asyncSocket to complete TLS negotiation.
		// We can just continue reading/writing to the socket, and it will handle queueing everything for us!
	}
	
	// Initialize the XML stream
	[self sendOpeningNegotiation];
	
	// Inform delegate that the TCP connection is open, and the stream handshake has begun
	[multicastDelegate xmppStreamDidStartNegotiation:self];
	
	// And start reading in the server's XML stream
	[asyncSocket readDataWithTimeout:TIMEOUT_READ_START tag:TAG_READ_START];
}

- (void)onSocketDidSecure:(AsyncSocket *)sock
{
	[multicastDelegate xmppStreamDidSecure:self];
}

/**
 * Called when a socket has completed reading the requested data. Not called if there is an error.
**/
- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
	if (DEBUG_RECV_PRE)
	{
		NSString *dataAsStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		
		DDLogRecvPre(@"RECV: %@", dataAsStr);
		
		[dataAsStr release];
	}
	
	numberOfBytesReceived += [data length];
	
	[parser parseData:data];
}

/**
 * Called after data with the given tag has been successfully sent.
**/
- (void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag
{
	if ((tag >= 0) && (tag <= UINT16_MAX))
	{
		[multicastDelegate xmppStream:self didSendElementWithTag:tag];
	}
	else if (tag == TAG_WRITE_SYNCHRONOUS)
	{
		flags &= ~kSynchronousSendPending;
	}
}

/**
 * In the event of an error, the socket is closed.
 * When connecting, this delegate method may be called before onSocket:didConnectToHost:
**/
- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err
{
	[multicastDelegate xmppStream:self didReceiveError:err];
}

/**
 * Called when a socket disconnects with or without error.  If you want to release a socket after it disconnects,
 * do so here. It is not safe to do that during "onSocket:willDisconnectWithError:".
**/
- (void)onSocketDidDisconnect:(AsyncSocket *)sock
{
	if (srvResults && (++srvResultsIndex < [srvResults count]))
	{
		[self tryNextSrvResult];
	}
	else
	{
		// Update state
		state = STATE_DISCONNECTED;
		
		// Update configuration
		[self setIsSecure:NO];
		[self setIsAuthenticated:NO];
		
		// Release the parser (to free underlying resources)
		[parser stop];
		[parser release];
		parser = nil;
		
		// Clear stored elements
		[myPresence release]; myPresence = nil;
		[rootElement release]; rootElement = nil;
		
		// Clear any saved authentication information
		[tempPassword release]; tempPassword = nil;
		
		// Clear srv results
		[srvResolver release]; srvResolver = nil;
		[srvResults release];  srvResults = nil;
		
		// Clear any synchronous send attempts
		[synchronousUUID release]; synchronousUUID = nil;
		
		// Stop the keep alive timer
		[keepAliveTimer invalidate];
		[keepAliveTimer release];
		keepAliveTimer = nil;
		
		// Notify delegate
		[multicastDelegate xmppStreamDidDisconnect:self];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPParser Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Called when the xmpp parser has read in the entire root element.
**/
- (void)xmppParser:(XMPPParser *)sender didReadRoot:(NSXMLElement *)root
{
	DDLogRecvPost(@"RECV: %@", [root compactXMLString]);
	
	// At this point we've sent our XML stream header, and we've received the response XML stream header.
	// We save the root element of our stream for future reference.
	// Digest Access authentication requires us to know the ID attribute from the <stream:stream/> element.
	
	[rootElement release];
	rootElement = [root retain];
	
    if([self isP2P])
    {
        // XEP-0174 specifies that <stream:features/> SHOULD be sent by the receiver.
        // In other words, if we're the recipient we will now send our features.
        // But if we're the initiator, we can't depend on receiving their features.
        
        // Either way, we're connected at this point.
        state = STATE_CONNECTED;
        
        if([self isP2PRecipient])
        {
			// Extract the remoteJID:
			// 
			// <stream:stream ... from='<remoteJID>' to='<myJID>'>
			
			NSString *from = [[rootElement attributeForName:@"from"] stringValue];
			remoteJID = [[XMPPJID jidWithString:from] retain];
			
			// Send our stream features.
			// To do so we need to ask the delegate to fill it out for us.
			
            NSXMLElement *streamFeatures = [NSXMLElement elementWithName:@"stream:features"];
            
			[multicastDelegate xmppStream:self willSendP2PFeatures:streamFeatures];
			
			NSString *outgoingStr = [streamFeatures compactXMLString];
			NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
			
            DDLogSend(@"SEND: %@", outgoingStr);
			numberOfBytesSent += [outgoingData length];
			
            [asyncSocket writeData:outgoingData
                       withTimeout:TIMEOUT_WRITE
                               tag:TAG_WRITE_STREAM];
            
        }
        
        // Make sure the delegate didn't disconnect us in the xmppStream:willSendP2PFeatures: method.
        
        if([self isConnected])
        {
			[multicastDelegate xmppStreamDidConnect:self];
        }
    }
    else
    {
        // Check for RFC compliance
        if([self serverXmppStreamVersionNumber] >= 1.0)
        {
            // Update state - we're now onto stream negotiations
            state = STATE_NEGOTIATING;
            
            // Note: We're waiting for the <stream:features> now
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
            
			NSString *outgoingStr = [iq compactXMLString];
			NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
			
            DDLogSend(@"SEND: %@", outgoingStr);
			numberOfBytesSent += [outgoingData length];
			
            [asyncSocket writeData:outgoingData
                       withTimeout:TIMEOUT_WRITE
                               tag:TAG_WRITE_STREAM];
            
            // Now wait for the response IQ
        }
    }
}

- (void)xmppParser:(XMPPParser *)sender didReadElement:(NSXMLElement *)element
{
	DDLogRecvPost(@"RECV: %@", [element compactXMLString]);
	
	NSString *elementName = [element name];
	
	if([elementName isEqualToString:@"stream:error"] || [elementName isEqualToString:@"error"])
	{
		[multicastDelegate xmppStream:self didReceiveError:element];
		return;
	}
	
	if(state == STATE_NEGOTIATING)
	{
		// We've just read in the stream features
		// We consider this part of the root element, so we'll add it (replacing any previously sent features)
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
	else if(state == STATE_AUTH_3)
	{
		// The response from our x-facebook-platform or authenticateAnonymously challenge
		[self handleAuth3:element];
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
	else
	{
		if([elementName isEqualToString:@"iq"])
		{
			XMPPIQ *iq = [XMPPIQ iqFromElement:element];
			
			BOOL responded = NO;
			
			MulticastDelegateEnumerator *delegateEnumerator = [multicastDelegate delegateEnumerator];
			id delegate;
			SEL selector = @selector(xmppStream:didReceiveIQ:);
			
			while((delegate = [delegateEnumerator nextDelegateForSelector:selector]))
			{
				BOOL delegateDidRespond = [delegate xmppStream:self didReceiveIQ:iq];
				
				responded = responded || delegateDidRespond;
			}
			
			// An entity that receives an IQ request of type "get" or "set" MUST reply
			// with an IQ response of type "result" or "error".
			// 
			// The response MUST preserve the 'id' attribute of the request.
			
			if (!responded && [iq requiresResponse])
			{
				// Return error message:
				// 
				// <iq to="jid" type="error" id="id">
				//   <query xmlns="ns"/>
				//   <error type="cancel" code="501">
				//     <feature-not-implemented xmlns="urn:ietf:params:xml:ns:xmpp-stanzas"/>
				//   </error>
				// </iq>
				
				NSXMLElement *reason = [NSXMLElement elementWithName:@"feature-not-implemented"
				                                               xmlns:@"urn:ietf:params:xml:ns:xmpp-stanzas"];
				
				NSXMLElement *error = [NSXMLElement elementWithName:@"error"];
				[error addAttributeWithName:@"type" stringValue:@"cancel"];
				[error addAttributeWithName:@"code" stringValue:@"501"];
				[error addChild:reason];
				
				XMPPIQ *iqResponse = [XMPPIQ iqWithType:@"error" to:[iq from] elementID:[iq elementID] child:error];
				
				NSXMLElement *iqChild = [iq childElement];
				if (iqChild)
				{
					NSXMLNode *iqChildCopy = [iqChild copy];
					[iqResponse insertChild:iqChildCopy atIndex:0];
					[iqChildCopy release];
				}
				
				[self sendElement:iqResponse];
			}
		}
		else if([elementName isEqualToString:@"message"])
		{
			[multicastDelegate xmppStream:self didReceiveMessage:[XMPPMessage messageFromElement:element]];
		}
		else if([elementName isEqualToString:@"presence"])
		{
			[multicastDelegate xmppStream:self didReceivePresence:[XMPPPresence presenceFromElement:element]];
		}
		else if([self isP2P] &&
		       ([elementName isEqualToString:@"stream:features"] || [elementName isEqualToString:@"features"]))
		{
			[multicastDelegate xmppStream:self didReceiveP2PFeatures:element];
		}
		else
		{
			[multicastDelegate xmppStream:self didReceiveError:element];
		}
	}
}

- (void)xmppParserDidEnd:(XMPPParser *)sender
{
	[asyncSocket disconnect];
}

- (void)xmppParser:(XMPPParser *)sender didFail:(NSError *)error
{
	[multicastDelegate xmppStream:self didReceiveError:error];
	
	[asyncSocket disconnect];
}

- (void)xmppParser:(XMPPParser *)sender didParseDataOfLength:(NSUInteger)length
{
	// The chunk we read has now been fully parsed.
	// Continue reading for XML elements.
	if(state == STATE_OPENING)
	{
		[asyncSocket readDataWithTimeout:TIMEOUT_READ_START tag:TAG_READ_START];
	}
	else
	{
		[asyncSocket readDataWithTimeout:TIMEOUT_READ_STREAM tag:TAG_READ_STREAM];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Keep Alive
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setKeepAliveInterval:(NSTimeInterval)interval
{
	if (keepAliveInterval != interval)
	{
		keepAliveInterval = interval;
		
		[self setupKeepAliveTimer];
	}
}

- (void)setupKeepAliveTimer
{
	[keepAliveTimer invalidate];
	[keepAliveTimer release];
	keepAliveTimer = nil;
	
	if (state == STATE_CONNECTED)
	{
		if (keepAliveInterval > 0)
		{
			keepAliveTimer = [[NSTimer scheduledTimerWithTimeInterval:keepAliveInterval
															   target:self
															 selector:@selector(keepAlive:)
															 userInfo:nil
															  repeats:YES] retain];
		}
	}
}

- (void)keepAlive:(NSTimer *)aTimer
{
  DDLogTrace();
	if (state == STATE_CONNECTED)
	{
		NSData *outgoingData = [@" " dataUsingEncoding:NSUTF8StringEncoding];
		
		numberOfBytesSent += [outgoingData length];
		
		[asyncSocket writeData:outgoingData
		           withTimeout:TIMEOUT_WRITE
		                   tag:TAG_WRITE_STREAM];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSString *)generateUUID
{
	NSString *result = nil;
	
	CFUUIDRef uuid = CFUUIDCreate(NULL);
	if (uuid)
	{
		result = NSMakeCollectable(CFUUIDCreateString(NULL, uuid));
		CFRelease(uuid);
	}
	
	return [result autorelease];
}

- (NSString *)generateUUID
{
	return [[self class] generateUUID];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Module Plug-In System
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)registerModule:(XMPPModule *)module
{
	if (module == nil) return;
	
	// Register module
	
	[registeredModules addDelegate:module];
	
	// Add auto delegates (if there are any)
	
	NSString *className = NSStringFromClass([module class]);
	id delegates = [autoDelegateDict objectForKey:className];
	
	MulticastDelegateEnumerator *delegatesEnumerator = [delegates delegateEnumerator];
	id delegate;
	
	while ((delegate = [delegatesEnumerator nextDelegate]))
	{
		[module addDelegate:delegate];
	}
	
	// Notify our own delegate(s)
	
	[multicastDelegate xmppStream:self didRegisterModule:module];
}

- (void)unregisterModule:(XMPPModule *)module
{
	if (module == nil) return;
	
	// Notify our own delegate(s)
	
	[multicastDelegate xmppStream:self willUnregisterModule:module];
	
	// Auto remove delegates (if there are any)
	
	NSString *className = NSStringFromClass([module class]);
	id delegates = [autoDelegateDict objectForKey:className];
	
	MulticastDelegateEnumerator *delegatesEnumerator = [delegates delegateEnumerator];
	id delegate;
	
	while ((delegate = [delegatesEnumerator nextDelegate]))
	{
		[module removeDelegate:delegate];
	}
	
	// Unregister modules
	
	[registeredModules removeDelegate:module];
}

- (void)autoAddDelegate:(id)delegate toModulesOfClass:(Class)aClass
{
	if (aClass == nil) return;
	
	NSString *className = NSStringFromClass(aClass);
	
	// Add the delegate to all currently registered modules of the given class.
	
	MulticastDelegateEnumerator *registeredModulesEnumerator = [registeredModules delegateEnumerator];
	XMPPModule *module;
	
	while ((module = [registeredModulesEnumerator nextDelegateOfClass:aClass]))
	{
		[module addDelegate:delegate];
	}
	
	// Add the delegate to list of auto delegates for the given class,
	// so that it will be added as a delegate to future registered modules of the given class.
	
	id delegates = [autoDelegateDict objectForKey:className];
	
	if (delegates == nil)
	{
		delegates = [[[MulticastDelegate alloc] init] autorelease];
		
		[autoDelegateDict setObject:delegates forKey:className];
	}
	
	[delegates addDelegate:delegate];
}

- (void)removeAutoDelegate:(id)delegate fromModulesOfClass:(Class)aClass
{
	if (aClass == nil)
	{
		// Remove the delegate from all currently registered modules of any class.
		
		[registeredModules removeDelegate:delegate];
		
		// Remove the delegate from list of auto delegates for all classes,
		// so that it will not be auto added as a delegate to future registered modules.
		
		NSEnumerator *delegatesEnumerator = [autoDelegateDict objectEnumerator];
		id delegates;
		
		while ((delegates = [delegatesEnumerator nextObject]))
		{
			[delegates removeDelegate:self];
		}
	}
	else
	{
		NSString *className = NSStringFromClass(aClass);
		
		// Remove the delegate from all currently registered modules of the given class.
		
		MulticastDelegateEnumerator *registeredModulesEnumerator = [registeredModules delegateEnumerator];
		XMPPModule *module;
		
		while ((module = [registeredModulesEnumerator nextDelegateOfClass:aClass]))
		{
			[module removeDelegate:delegate];
		}
		
		// Remove the delegate from list of auto delegates for the given class,
		// so that it will not be added as a delegate to future registered modules of the given class.
		
		id delegates = [autoDelegateDict objectForKey:className];
		
		if (delegates != nil)
		{
			[delegates removeDelegate:delegate];
		}
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
		
		if (DEBUG_RECV_PRE || DEBUG_RECV_POST)
		{
			NSLog(@"decoded challenge: %@", authStr);
		}
		
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
		cnonce = [[XMPPStream generateUUID] retain];
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
