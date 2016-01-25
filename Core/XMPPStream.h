#import <Foundation/Foundation.h>
#import "XMPPSASLAuthentication.h"
#import "XMPPCustomBinding.h"
#import "GCDMulticastDelegate.h"
#import "CocoaAsyncSocket/GCDAsyncSocket.h"

@import KissXML;

@class XMPPSRVResolver;
@class XMPPParser;
@class XMPPJID;
@class XMPPIQ;
@class XMPPMessage;
@class XMPPPresence;
@class XMPPModule;
@class XMPPElement;
@class XMPPElementReceipt;
@protocol XMPPStreamDelegate;

#if TARGET_OS_IPHONE
  #define MIN_KEEPALIVE_INTERVAL      20.0 // 20 Seconds
  #define DEFAULT_KEEPALIVE_INTERVAL 120.0 //  2 Minutes
#else
  #define MIN_KEEPALIVE_INTERVAL      10.0 // 10 Seconds
  #define DEFAULT_KEEPALIVE_INTERVAL 300.0 //  5 Minutes
#endif

extern NSString *const XMPPStreamErrorDomain;

typedef NS_ENUM(NSUInteger, XMPPStreamErrorCode) {
	XMPPStreamInvalidType,       // Attempting to access P2P methods in a non-P2P stream, or vice-versa
	XMPPStreamInvalidState,      // Invalid state for requested action, such as connect when already connected
	XMPPStreamInvalidProperty,   // Missing a required property, such as myJID
	XMPPStreamInvalidParameter,  // Invalid parameter, such as a nil JID
	XMPPStreamUnsupportedAction, // The server doesn't support the requested action
};

typedef NS_ENUM(NSUInteger, XMPPStreamStartTLSPolicy) {
    XMPPStreamStartTLSPolicyAllowed,   // TLS will be used if the server requires it
    XMPPStreamStartTLSPolicyPreferred, // TLS will be used if the server offers it
    XMPPStreamStartTLSPolicyRequired   // TLS will be used if the server offers it, else the stream won't connect
};

extern const NSTimeInterval XMPPStreamTimeoutNone;

@interface XMPPStream : NSObject <GCDAsyncSocketDelegate>

/**
 * Standard XMPP initialization.
 * The stream is a standard client to server connection.
 * 
 * P2P streams using XEP-0174 are also supported.
 * See the P2P section below.
**/
- (id)init;

/**
 * Peer to Peer XMPP initialization.
 * The stream is a direct client to client connection as outlined in XEP-0174.
**/
- (id)initP2PFrom:(XMPPJID *)myJID;

/**
 * XMPPStream uses a multicast delegate.
 * This allows one to add multiple delegates to a single XMPPStream instance,
 * which makes it easier to separate various components and extensions.
 * 
 * For example, if you were implementing two different custom extensions on top of XMPP,
 * you could put them in separate classes, and simply add each as a delegate.
**/
- (void)addDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue;
- (void)removeDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue;
- (void)removeDelegate:(id)delegate;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * The server's hostname that should be used to make the TCP connection.
 * This may be a domain name (e.g. "deusty.com") or an IP address (e.g. "70.85.193.226").
 * 
 * Note that this may be different from the virtual xmpp hostname.
 * Just as HTTP servers can support mulitple virtual hosts from a single server, so too can xmpp servers.
 * A prime example is google via google apps.
 * 
 * For example, say you own the domain "mydomain.com".
 * If you go to mydomain.com in a web browser,
 * you are directed to your apache server running on your webserver somewhere in the cloud.
 * But you use google apps for your email and xmpp needs.
 * So if somebody sends you an email, it actually goes to google's servers, where you later access it from.
 * Similarly, you connect to google's servers to sign into xmpp.
 * 
 * In the example above, your hostname is "talk.google.com" and your JID is "me@mydomain.com".
 * 
 * This hostName property is optional.
 * If you do not set the hostName, then the framework will follow the xmpp specification using jid's domain.
 * That is, it first do an SRV lookup (as specified in the xmpp RFC).
 * If that fails, it will fall back to simply attempting to connect to the jid's domain.
**/
@property (readwrite, copy) NSString *hostName;

/**
 * The port the xmpp server is running on.
 * If you do not explicitly set the port, the default port will be used.
 * If you set the port to zero, the default port will be used.
 * 
 * The default port is 5222.
**/
@property (readwrite, assign) UInt16 hostPort;

/**
 * The stream's policy on when to Start TLS.
 *
 * The default is XMPPStreamStartTLSPolicyAllowed.
 *
 * @see XMPPStreamStartTLSPolicy
**/
@property (readwrite, assign) XMPPStreamStartTLSPolicy startTLSPolicy;

/**
 * The JID of the user.
 * 
 * This value is required, and is used in many parts of the underlying implementation.
 * When connecting, the domain of the JID is used to properly specify the correct xmpp virtual host.
 * It is used during registration to supply the username of the user to create an account for.
 * It is used during authentication to supply the username of the user to authenticate with.
 * And the resource may be used post-authentication during the required xmpp resource binding step.
 * 
 * A proper JID is of the form user@domain/resource.
 * For example: robbiehanson@deusty.com/work
 * 
 * The resource is optional, in the sense that if one is not supplied,
 * one will be automatically generated for you (either by us or by the server).
 * 
 * Please note:
 * Resource collisions are handled in different ways depending on server configuration.
 * 
 * For example:
 * You are signed in with user1@domain.com/home on your desktop.
 * Then you attempt to sign in with user1@domain.com/home on your laptop.
 * 
 * The server could possibly:
 * - Reject the resource request for the laptop.
 * - Accept the resource request for the laptop, and immediately disconnect the desktop.
 * - Automatically assign the laptop another resource without a conflict.
 * 
 * For this reason, you may wish to check the myJID variable after the stream has been connected,
 * just in case the resource was changed by the server.
**/
@property (readwrite, copy) XMPPJID *myJID;

/**
 * Only used in P2P streams.
**/
@property (strong, readonly) XMPPJID *remoteJID;

/**
 * Many routers will teardown a socket mapping if there is no activity on the socket.
 * For this reason, the xmpp stream supports sending keep-alive data.
 * This is simply whitespace, which is ignored by the xmpp protocol.
 * 
 * Keep-alive data is only sent in the absence of any other data being sent/received.
 * 
 * The default value is defined in DEFAULT_KEEPALIVE_INTERVAL.
 * The minimum value is defined in MIN_KEEPALIVE_INTERVAL.
 * 
 * To disable keep-alive, set the interval to zero (or any non-positive number).
 * 
 * The keep-alive timer (if enabled) fires every (keepAliveInterval / 4) seconds.
 * Upon firing it checks when data was last sent/received,
 * and sends keep-alive data if the elapsed time has exceeded the keepAliveInterval.
 * Thus the effective resolution of the keepalive timer is based on the interval.
 * 
 * @see keepAliveWhitespaceCharacter
**/
@property (readwrite, assign) NSTimeInterval keepAliveInterval;

/**
 * The keep-alive mechanism sends whitespace which is ignored by the xmpp protocol.
 * The default whitespace character is a space (' ').
 * 
 * This can be changed, for whatever reason, to another whitespace character.
 * Valid whitespace characters are space(' '), tab('\t') and newline('\n').
 * 
 * If you attempt to set the character to any non-whitespace character, the attempt is ignored.
 * 
 * @see keepAliveInterval
**/
@property (readwrite, assign) char keepAliveWhitespaceCharacter;

/**
 * Represents the last sent presence element concerning the presence of myJID on the server.
 * In other words, it represents the presence as others see us.
 * 
 * This excludes presence elements sent concerning subscriptions, MUC rooms, etc.
 * 
 * @see resendMyPresence
**/
@property (strong, readonly) XMPPPresence *myPresence;

/**
 * Returns the total number of bytes bytes sent/received by the xmpp stream.
 * 
 * By default this is the byte count since the xmpp stream object has been created.
 * If the stream has connected/disconnected/reconnected multiple times,
 * the count will be the summation of all connections.
 * 
 * The functionality may optionaly be changed to count only the current socket connection.
 * @see resetByteCountPerConnection
**/
@property (readonly) uint64_t numberOfBytesSent;
@property (readonly) uint64_t numberOfBytesReceived;

/**
 * Same as the individual properties,
 * but provides a way to fetch them in one atomic operation.
**/
- (void)getNumberOfBytesSent:(uint64_t *)bytesSentPtr numberOfBytesReceived:(uint64_t *)bytesReceivedPtr;

/**
 * Affects the funtionality of the byte counter.
 * 
 * The default value is NO.
 * 
 * If set to YES, the byte count will be reset just prior to a new connection (in the connect methods).
**/
@property (readwrite, assign) BOOL resetByteCountPerConnection;

/**
 * The tag property allows you to associate user defined information with the stream.
 * Tag values are not used internally, and should not be used by xmpp modules.
**/
@property (readwrite, strong) id tag;

/**
 * RFC 6121 states that starting a session is no longer required.
 * To skip this step set skipStartSession to YES.
 *
 * [RFC3921] specified one additional
 * precondition: formal establishment of an instant messaging and
 * presence session.  Implementation and deployment experience has
 * shown that this additional step is unnecessary.  However, for
 * backward compatibility an implementation MAY still offer that
 * feature.  This enables older software to connect while letting
 * newer software save a round trip.
 *
 * The default value is NO.
**/
@property (readwrite, assign) BOOL skipStartSession;

/**
 * Validates that a response element is FROM the jid that the request element was sent TO.
 * Supports validating responses when request didn't specify a TO.
 *
 * @see isValidResponseElementFrom:forRequestElementTo:
 * @see isValidResponseElement:forRequestElement:
 *
 * The default value is NO.
**/
@property (readwrite, assign) BOOL validatesResponses;

#if TARGET_OS_IPHONE

/**
 * If set, the kCFStreamNetworkServiceTypeVoIP flags will be set on the underlying CFRead/Write streams.
 * 
 * The default value is NO.
**/
@property (readwrite, assign) BOOL enableBackgroundingOnSocket;

#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark State
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns YES if the connection is closed, and thus no stream is open.
 * If the stream is neither disconnected, nor connected, then a connection is currently being established.
**/
- (BOOL)isDisconnected;

/**
 * Returns YES is the connection is currently connecting
**/
- (BOOL)isConnecting;

/**
 * Returns YES if the connection is open, and the stream has been properly established.
 * If the stream is neither disconnected, nor connected, then a connection is currently being established.
 * 
 * If this method returns YES, then it is ready for you to start sending and receiving elements.
**/
- (BOOL)isConnected;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Connect & Disconnect
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Connects to the configured hostName on the configured hostPort.
 * The timeout is optional. To not time out use XMPPStreamTimeoutNone.
 * If the hostName or myJID are not set, this method will return NO and set the error parameter.
**/
- (BOOL)connectWithTimeout:(NSTimeInterval)timeout error:(NSError **)errPtr;

/**
 * THIS IS DEPRECATED BY THE XMPP SPECIFICATION.
 * 
 * The xmpp specification outlines the proper use of SSL/TLS by negotiating
 * the startTLS upgrade within the stream negotiation.
 * This method exists for those ancient servers that still require the connection to be secured prematurely.
 * The timeout is optional. To not time out use XMPPStreamTimeoutNone.
 *
 * Note: Such servers generally use port 5223 for this, which you will need to set.
**/
- (BOOL)oldSchoolSecureConnectWithTimeout:(NSTimeInterval)timeout error:(NSError **)errPtr;

/**
 * Starts a P2P connection to the given user and given address.
 * The timeout is optional. To not time out use XMPPStreamTimeoutNone.
 * This method only works with XMPPStream objects created using the initP2P method.
 * 
 * The given address is specified as a sockaddr structure wrapped in a NSData object.
 * For example, a NSData object returned from NSNetservice's addresses method.
**/
- (BOOL)connectTo:(XMPPJID *)remoteJID
      withAddress:(NSData *)remoteAddr
      withTimeout:(NSTimeInterval)timeout
            error:(NSError **)errPtr;

/**
 * Starts a P2P connection with the given accepted socket.
 * This method only works with XMPPStream objects created using the initP2P method.
 * 
 * The given socket should be a socket that has already been accepted.
 * The remoteJID will be extracted from the opening stream negotiation.
**/
- (BOOL)connectP2PWithSocket:(GCDAsyncSocket *)acceptedSocket error:(NSError **)errPtr;

/**
 * Disconnects from the remote host by closing the underlying TCP socket connection.
 * The terminating </stream:stream> element is not sent to the server.
 * 
 * This method is synchronous.
 * Meaning that the disconnect will happen immediately, even if there are pending elements yet to be sent.
 * 
 * The xmppStreamDidDisconnect:withError: delegate method will immediately be dispatched onto the delegate queue.
**/
- (void)disconnect;

/**
 * Disconnects from the remote host by sending the terminating </stream:stream> element,
 * and then closing the underlying TCP socket connection.
 * 
 * This method is asynchronous.
 * The disconnect will happen after all pending elements have been sent.
 * Attempting to send elements after this method has been called will not work (the elements won't get sent).
**/
- (void)disconnectAfterSending;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Security
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns YES if SSL/TLS was used to establish a connection to the server.
 * 
 * Some servers may require an "upgrade to TLS" in order to start communication,
 * so even if the connection was not explicitly secured, an ugrade to TLS may have occured.
 * 
 * See also the xmppStream:willSecureWithSettings: delegate method.
**/
- (BOOL)isSecure;

/**
 * Returns whether or not the server supports securing the connection via SSL/TLS.
 * 
 * Some servers will actually require a secure connection,
 * in which case the stream will attempt to secure the connection during the opening process.
 * 
 * If the connection has already been secured, this method may return NO.
**/
- (BOOL)supportsStartTLS;

/**
 * Attempts to secure the connection via SSL/TLS.
 * 
 * This method is asynchronous.
 * The SSL/TLS handshake will occur in the background, and
 * the xmppStreamDidSecure: delegate method will be called after the TLS process has completed.
 * 
 * This method returns immediately.
 * If the secure process was started, it will return YES.
 * If there was an issue while starting the security process,
 * this method will return NO and set the error parameter.
 * 
 * The errPtr parameter is optional - you may pass nil.
 * 
 * You may wish to configure the security settings via the xmppStream:willSecureWithSettings: delegate method.
 * 
 * If the SSL/TLS handshake fails, the connection will be closed.
 * The reason for the error will be reported via the xmppStreamDidDisconnect:withError: delegate method.
 * The error parameter will be an NSError object, and may have an error domain of kCFStreamErrorDomainSSL.
 * The corresponding error code is documented in Apple's Security framework, in SecureTransport.h
**/
- (BOOL)secureConnection:(NSError **)errPtr;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Registration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * In Band Registration.
 * Creating a user account on the xmpp server within the xmpp protocol.
 * 
 * The registerWithElements:error: method is asynchronous.
 * It will return immediately, and the delegate methods are used to determine success.
 * See the xmppStreamDidRegister: and xmppStream:didNotRegister: methods.
 * 
 * If there is something immediately wrong, such as the stream is not connected,
 * this method will return NO and set the error.
 * 
 * The errPtr parameter is optional - you may pass nil.
 * 
 * registerWithPassword:error: is a convience method for creating an account using the given username and password.
 *
 * Security Note:
 * The password will be sent in the clear unless the stream has been secured.
**/
- (BOOL)supportsInBandRegistration;
- (BOOL)registerWithElements:(NSArray *)elements error:(NSError **)errPtr;
- (BOOL)registerWithPassword:(NSString *)password error:(NSError **)errPtr;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Authentication
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns the server's list of supported authentication mechanisms.
 * Each item in the array will be of type NSString.
 * 
 * For example, if the server supplied this stanza within it's reported stream:features:
 * 
 * <mechanisms xmlns="urn:ietf:params:xml:ns:xmpp-sasl">
 *     <mechanism>DIGEST-MD5</mechanism>
 *     <mechanism>PLAIN</mechanism>
 * </mechanisms>
 * 
 * Then this method would return [@"DIGEST-MD5", @"PLAIN"].
**/
- (NSArray *)supportedAuthenticationMechanisms;

/**
 * Returns whether or not the given authentication mechanism name was specified in the
 * server's list of supported authentication mechanisms.
 * 
 * Note: The authentication classes often provide a category on XMPPStream, adding useful methods.
 * 
 * @see XMPPPlainAuthentication - supportsPlainAuthentication
 * @see XMPPDigestMD5Authentication - supportsDigestMD5Authentication
 * @see XMPPXFacebookPlatformAuthentication - supportsXFacebookPlatformAuthentication
 * @see XMPPDeprecatedPlainAuthentication - supportsDeprecatedPlainAuthentication
 * @see XMPPDeprecatedDigestAuthentication - supportsDeprecatedDigestAuthentication
**/
- (BOOL)supportsAuthenticationMechanism:(NSString *)mechanism;

/**
 * This is the root authentication method.
 * All other authentication methods go through this one.
 * 
 * This method attempts to start the authentication process given the auth instance.
 * That is, this method will invoke start: on the given auth instance.
 * If it returns YES, then the stream will enter into authentication mode.
 * It will then continually invoke the handleAuth: method on the given instance until authentication is complete.
 * 
 * This method is asynchronous.
 * 
 * If there is something immediately wrong, such as the stream is not connected,
 * the method will return NO and set the error.
 * Otherwise the delegate callbacks are used to communicate auth success or failure.
 * 
 * @see xmppStreamDidAuthenticate:
 * @see xmppStream:didNotAuthenticate:
 * 
 * @see authenticateWithPassword:error:
 * 
 * Note: The security process is abstracted in order to provide flexibility,
 *       and allow developers to easily implement their own custom authentication protocols.
 *       The authentication classes often provide a category on XMPPStream, adding useful methods.
 * 
 * @see XMPPXFacebookPlatformAuthentication - authenticateWithFacebookAccessToken:error:
**/
- (BOOL)authenticate:(id <XMPPSASLAuthentication>)auth error:(NSError **)errPtr;

/**
 * This method applies to standard password authentication schemes only.
 * This is NOT the primary authentication method.
 * 
 * @see authenticate:error:
 * 
 * This method exists for backwards compatibility, and may disappear in future versions.
**/
- (BOOL)authenticateWithPassword:(NSString *)password error:(NSError **)errPtr;

/**
 * Returns whether or not the xmpp stream is currently authenticating with the XMPP Server.
**/
- (BOOL)isAuthenticating;

/**
 * Returns whether or not the xmpp stream has successfully authenticated with the server.
**/
- (BOOL)isAuthenticated;

/**
 * Returns the date when the xmpp stream successfully authenticated with the server.
 **/
- (NSDate *)authenticationDate;


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Compression
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/**
 * Returns the server's list of supported compression methods in accordance to XEP-0138: Stream Compression
 * Each item in the array will be of type NSString.
 *
 * For example, if the server supplied this stanza within it's reported stream:features:
 *
 * <compression xmlns='http://jabber.org/features/compress'>
 *	  <method>zlib</method>
 *    <method>lzw</method>
 * </compression>
 *
 * Then this method would return [@"zlib", @"lzw"].
 **/
- (NSArray *)supportedCompressionMethods;


/**
 * Returns whether or not the given compression method name was specified in the
 * server's list of supported compression methods.
 *
 * Note: The XMPPStream doesn't currently support any compression methods 
**/

- (BOOL)supportsCompressionMethod:(NSString *)compressionMethod;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Server Info
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method will return the root element of the document.
 * This element contains the opening <stream:stream/> and <stream:features/> tags received from the server.
 * 
 * If multiple <stream:features/> have been received during the course of stream negotiation,
 * the root element contains only the most recent (current) version.
 * 
 * Note: The rootElement is "empty", in-so-far as it does not contain all the XML elements the stream has
 * received during it's connection. This is done for performance reasons and for the obvious benefit
 * of being more memory efficient.
**/
- (NSXMLElement *)rootElement;

/**
 * Returns the version attribute from the servers's <stream:stream/> element.
 * This should be at least 1.0 to be RFC 3920 compliant.
 * If no version number was set, the server is not RFC compliant, and 0 is returned.
**/
- (float)serverXmppStreamVersionNumber;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Sending
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Sends the given XML element.
 * If the stream is not yet connected, this method does nothing.
**/
- (void)sendElement:(NSXMLElement *)element;

/**
 * Just like the sendElement: method above,
 * but allows you to receive a receipt that can later be used to verify the element has been sent.
 * 
 * If you later want to check to see if the element has been sent:
 * 
 * if ([receipt wait:0]) {
 *   // Element has been sent
 * }
 * 
 * If you later want to wait until the element has been sent:
 * 
 * if ([receipt wait:-1]) {
 *   // Element was sent
 * } else {
 *   // Element failed to send due to disconnection
 * }
 * 
 * It is important to understand what it means when [receipt wait:timeout] returns YES.
 * It does NOT mean the server has received the element.
 * It only means the data has been queued for sending in the underlying OS socket buffer.
 * 
 * So at this point the OS will do everything in its capacity to send the data to the server,
 * which generally means the server will eventually receive the data.
 * Unless, of course, something horrible happens such as a network failure,
 * or a system crash, or the server crashes, etc.
 * 
 * Even if you close the xmpp stream after this point, the OS will still do everything it can to send the data.
**/
- (void)sendElement:(NSXMLElement *)element andGetReceipt:(XMPPElementReceipt **)receiptPtr;

/**
 * Fetches and resends the myPresence element (if available) in a single atomic operation.
 * 
 * There are various xmpp extensions that hook into the xmpp stream and append information to outgoing presence stanzas.
 * For example, the XMPPCapabilities module automatically appends capabilities information (as a hash).
 * When these modules need to update/change their appended information,
 * they should use this method to do so.
 * 
 * The alternative is to fetch the myPresence element, and resend it manually using the sendElement method.
 * However, that is 2 seperate operations, and the user, may send a different presence element inbetween.
 * Using this method guarantees everything is done as an atomic operation.
**/
- (void)resendMyPresence;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Stanza Validation
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Validates that a response element is FROM the jid that the request element was sent TO.
 * Supports validating responses when request didn't specify a TO.
**/
- (BOOL)isValidResponseElementFrom:(XMPPJID *)from forRequestElementTo:(XMPPJID *)to;

- (BOOL)isValidResponseElement:(XMPPElement *)response forRequestElement:(XMPPElement *)request;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Module Plug-In System
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * The XMPPModule class automatically invokes these methods when it is activated/deactivated.
 * 
 * The registerModule method registers the module with the xmppStream.
 * If there are any other modules that have requested to be automatically added as delegates to modules of this type,
 * then those modules are automatically added as delegates during the asynchronous execution of this method.
 * 
 * The registerModule method is asynchronous.
 * 
 * The unregisterModule method unregisters the module with the xmppStream,
 * and automatically removes it as a delegate of any other module.
 * 
 * The unregisterModule method is fully synchronous.
 * That is, after this method returns, the module will not be scheduled in any more delegate calls from other modules.
 * However, if the module was already scheduled in an existing asynchronous delegate call from another module,
 * the scheduled delegate invocation remains queued and will fire in the near future.
 * Since the delegate invocation is already queued,
 * the module's retainCount has been incremented,
 * and the module will not be deallocated until after the delegate invocation has fired.
**/
- (void)registerModule:(XMPPModule *)module;
- (void)unregisterModule:(XMPPModule *)module;

/**
 * Automatically registers the given delegate with all current and future registered modules of the given class.
 * 
 * That is, the given delegate will be added to the delegate list ([module addDelegate:delegate delegateQueue:dq]) to
 * all current and future registered modules that respond YES to [module isKindOfClass:aClass].
 * 
 * This method is used by modules to automatically integrate with other modules.
 * For example, a module may auto-add itself as a delegate to XMPPCapabilities
 * so that it can broadcast its implemented features.
 * 
 * This may also be useful to clients, for example, to add a delegate to instances of something like XMPPChatRoom,
 * where there may be multiple instances of the module that get created during the course of an xmpp session.
 * 
 * If you auto register on multiple queues, you can remove all registrations with a single
 * call to removeAutoDelegate::: by passing NULL as the 'dq' parameter.
 * 
 * If you auto register for multiple classes, you can remove all registrations with a single
 * call to removeAutoDelegate::: by passing nil as the 'aClass' parameter.
**/
- (void)autoAddDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue toModulesOfClass:(Class)aClass;
- (void)removeAutoDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue fromModulesOfClass:(Class)aClass;

/**
 * Allows for enumeration of the currently registered modules.
 * 
 * This may be useful if the stream needs to be queried for modules of a particular type.
**/
- (void)enumerateModulesWithBlock:(void (^)(XMPPModule *module, NSUInteger idx, BOOL *stop))block;

/**
 * Allows for enumeration of the currently registered modules that are a kind of Class.
 * idx is in relation to all modules not just those of the given class.
**/
- (void)enumerateModulesOfClass:(Class)aClass withBlock:(void (^)(XMPPModule *module, NSUInteger idx, BOOL *stop))block;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Generates and returns a new autoreleased UUID.
 * UUIDs (Universally Unique Identifiers) may also be known as GUIDs (Globally Unique Identifiers).
 * 
 * The UUID is generated using the CFUUID library, which generates a unique 128 bit value.
 * The uuid is then translated into a string using the standard format for UUIDs:
 * "68753A44-4D6F-1226-9C60-0050E4C00067"
 * 
 * This method is most commonly used to generate a unique id value for an xmpp element.
**/
+ (NSString *)generateUUID;
- (NSString *)generateUUID;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface XMPPElementReceipt : NSObject
{
	uint32_t atomicFlags;
	dispatch_semaphore_t semaphore;
}

/**
 * Element receipts allow you to check to see if the element has been sent.
 * The timeout parameter allows you to do any of the following:
 * 
 * - Do an instantaneous check (pass timeout == 0)
 * - Wait until the element has been sent (pass timeout < 0)
 * - Wait up to a certain amount of time (pass timeout > 0)
 * 
 * It is important to understand what it means when [receipt wait:timeout] returns YES.
 * It does NOT mean the server has received the element.
 * It only means the data has been queued for sending in the underlying OS socket buffer.
 * 
 * So at this point the OS will do everything in its capacity to send the data to the server,
 * which generally means the server will eventually receive the data.
 * Unless, of course, something horrible happens such as a network failure,
 * or a system crash, or the server crashes, etc.
 * 
 * Even if you close the xmpp stream after this point, the OS will still do everything it can to send the data.
**/
- (BOOL)wait:(NSTimeInterval)timeout;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPStreamDelegate
@optional

/**
 * This method is called before the stream begins the connection process.
 *
 * If developing an iOS app that runs in the background, this may be a good place to indicate
 * that this is a task that needs to continue running in the background.
**/
- (void)xmppStreamWillConnect:(XMPPStream *)sender;

/**
 * This method is called after the tcp socket has connected to the remote host.
 * It may be used as a hook for various things, such as updating the UI or extracting the server's IP address.
 * 
 * If developing an iOS app that runs in the background,
 * please use XMPPStream's enableBackgroundingOnSocket property as opposed to doing it directly on the socket here.
**/
- (void)xmppStream:(XMPPStream *)sender socketDidConnect:(GCDAsyncSocket *)socket;

/**
 * This method is called after a TCP connection has been established with the server,
 * and the opening XML stream negotiation has started.
**/
- (void)xmppStreamDidStartNegotiation:(XMPPStream *)sender;

/**
 * This method is called immediately prior to the stream being secured via TLS/SSL.
 * Note that this delegate may be called even if you do not explicitly invoke the startTLS method.
 * Servers have the option of requiring connections to be secured during the opening process.
 * If this is the case, the XMPPStream will automatically attempt to properly secure the connection.
 * 
 * The dictionary of settings is what will be passed to the startTLS method of the underlying GCDAsyncSocket.
 * The GCDAsyncSocket header file contains a discussion of the available key/value pairs,
 * as well as the security consequences of various options.
 * It is recommended reading if you are planning on implementing this method.
 * 
 * The dictionary of settings that are initially passed will be an empty dictionary.
 * If you choose not to implement this method, or simply do not edit the dictionary,
 * then the default settings will be used.
 * That is, the kCFStreamSSLPeerName will be set to the configured host name,
 * and the default security validation checks will be performed.
 * 
 * This means that authentication will fail if the name on the X509 certificate of
 * the server does not match the value of the hostname for the xmpp stream.
 * It will also fail if the certificate is self-signed, or if it is expired, etc.
 * 
 * These settings are most likely the right fit for most production environments,
 * but may need to be tweaked for development or testing,
 * where the development server may be using a self-signed certificate.
 * 
 * Note: If your development server is using a self-signed certificate,
 * you likely need to add GCDAsyncSocketManuallyEvaluateTrust=YES to the settings.
 * Then implement the xmppStream:didReceiveTrust:completionHandler: delegate method to perform custom validation.
**/
- (void)xmppStream:(XMPPStream *)sender willSecureWithSettings:(NSMutableDictionary *)settings;

/**
 * Allows a delegate to hook into the TLS handshake and manually validate the peer it's connecting to.
 *
 * This is only called if the stream is secured with settings that include:
 * - GCDAsyncSocketManuallyEvaluateTrust == YES
 * That is, if a delegate implements xmppStream:willSecureWithSettings:, and plugs in that key/value pair.
 *
 * Thus this delegate method is forwarding the TLS evaluation callback from the underlying GCDAsyncSocket.
 *
 * Typically the delegate will use SecTrustEvaluate (and related functions) to properly validate the peer.
 *
 * Note from Apple's documentation:
 *   Because [SecTrustEvaluate] might look on the network for certificates in the certificate chain,
 *   [it] might block while attempting network access. You should never call it from your main thread;
 *   call it only from within a function running on a dispatch queue or on a separate thread.
 *
 * This is why this method uses a completionHandler block rather than a normal return value.
 * The idea is that you should be performing SecTrustEvaluate on a background thread.
 * The completionHandler block is thread-safe, and may be invoked from a background queue/thread.
 * It is safe to invoke the completionHandler block even if the socket has been closed.
 * 
 * Keep in mind that you can do all kinds of cool stuff here.
 * For example:
 * 
 * If your development server is using a self-signed certificate,
 * then you could embed info about the self-signed cert within your app, and use this callback to ensure that
 * you're actually connecting to the expected dev server.
 * 
 * Also, you could present certificates that don't pass SecTrustEvaluate to the client.
 * That is, if SecTrustEvaluate comes back with problems, you could invoke the completionHandler with NO,
 * and then ask the client if the cert can be trusted. This is similar to how most browsers act.
 * 
 * Generally, only one delegate should implement this method.
 * However, if multiple delegates implement this method, then the first to invoke the completionHandler "wins".
 * And subsequent invocations of the completionHandler are ignored.
**/
- (void)xmppStream:(XMPPStream *)sender didReceiveTrust:(SecTrustRef)trust
                                      completionHandler:(void (^)(BOOL shouldTrustPeer))completionHandler;

/**
 * This method is called after the stream has been secured via SSL/TLS.
 * This method may be called if the server required a secure connection during the opening process,
 * or if the secureConnection: method was manually invoked.
**/
- (void)xmppStreamDidSecure:(XMPPStream *)sender;

/**
 * This method is called after the XML stream has been fully opened.
 * More precisely, this method is called after an opening <xml/> and <stream:stream/> tag have been sent and received,
 * and after the stream features have been received, and any required features have been fullfilled.
 * At this point it's safe to begin communication with the server.
**/
- (void)xmppStreamDidConnect:(XMPPStream *)sender;

/**
 * This method is called after registration of a new user has successfully finished.
 * If registration fails for some reason, the xmppStream:didNotRegister: method will be called instead.
**/
- (void)xmppStreamDidRegister:(XMPPStream *)sender;

/**
 * This method is called if registration fails.
**/
- (void)xmppStream:(XMPPStream *)sender didNotRegister:(NSXMLElement *)error;

/**
 * This method is called after authentication has successfully finished.
 * If authentication fails for some reason, the xmppStream:didNotAuthenticate: method will be called instead.
**/
- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender;

/**
 * This method is called if authentication fails.
**/
- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error;

/**
 * Binding a JID resource is a standard part of the authentication process,
 * and occurs after SASL authentication completes (which generally authenticates the JID username).
 * 
 * This delegate method allows for a custom binding procedure to be used.
 * For example:
 * - a custom SASL authentication scheme might combine auth with binding
 * - stream management (xep-0198) replaces binding if it can resume a previous session
 * 
 * Return nil (or don't implement this method) if you wish to use the standard binding procedure.
**/
- (id <XMPPCustomBinding>)xmppStreamWillBind:(XMPPStream *)sender;

/**
 * This method is called if the XMPP server doesn't allow our resource of choice
 * because it conflicts with an existing resource.
 * 
 * Return an alternative resource or return nil to let the server automatically pick a resource for us.
**/
- (NSString *)xmppStream:(XMPPStream *)sender alternativeResourceForConflictingResource:(NSString *)conflictingResource;

/**
 * These methods are called before their respective XML elements are broadcast as received to the rest of the stack.
 * These methods can be used to modify elements on the fly.
 * (E.g. perform custom decryption so the rest of the stack sees readable text.)
 * 
 * You may also filter incoming elements by returning nil.
 * 
 * When implementing these methods to modify the element, you do not need to copy the given element.
 * You can simply edit the given element, and return it.
 * The reason these methods return an element, instead of void, is to allow filtering.
 * 
 * Concerning thread-safety, delegates implementing the method are invoked one-at-a-time to
 * allow thread-safe modification of the given elements.
 *
 * You should NOT implement these methods unless you have good reason to do so.
 * For general processing and notification of received elements, please use xmppStream:didReceiveX: methods.
 * 
 * @see xmppStream:didReceiveIQ:
 * @see xmppStream:didReceiveMessage:
 * @see xmppStream:didReceivePresence:
**/
- (XMPPIQ *)xmppStream:(XMPPStream *)sender willReceiveIQ:(XMPPIQ *)iq;
- (XMPPMessage *)xmppStream:(XMPPStream *)sender willReceiveMessage:(XMPPMessage *)message;
- (XMPPPresence *)xmppStream:(XMPPStream *)sender willReceivePresence:(XMPPPresence *)presence;

/**
 * This method is called if any of the xmppStream:willReceiveX: methods filter the incoming stanza.
 * 
 * It may be useful for some extensions to know that something was received,
 * even if it was filtered for some reason.
**/
- (void)xmppStreamDidFilterStanza:(XMPPStream *)sender;

/**
 * These methods are called after their respective XML elements are received on the stream.
 * 
 * In the case of an IQ, the delegate method should return YES if it has or will respond to the given IQ.
 * If the IQ is of type 'get' or 'set', and no delegates respond to the IQ,
 * then xmpp stream will automatically send an error response.
 * 
 * Concerning thread-safety, delegates shouldn't modify the given elements.
 * As documented in NSXML / KissXML, elements are read-access thread-safe, but write-access thread-unsafe.
 * If you have need to modify an element for any reason,
 * you should copy the element first, and then modify and use the copy.
**/
- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq;
- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message;
- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence;

/**
 * This method is called if an XMPP error is received.
 * In other words, a <stream:error/>.
 * 
 * However, this method may also be called for any unrecognized xml stanzas.
 * 
 * Note that standard errors (<iq type='error'/> for example) are delivered normally,
 * via the other didReceive...: methods.
**/
- (void)xmppStream:(XMPPStream *)sender didReceiveError:(NSXMLElement *)error;

/**
 * These methods are called before their respective XML elements are sent over the stream.
 * These methods can be used to modify outgoing elements on the fly.
 * (E.g. add standard information for custom protocols.)
 * 
 * You may also filter outgoing elements by returning nil.
 * 
 * When implementing these methods to modify the element, you do not need to copy the given element.
 * You can simply edit the given element, and return it.
 * The reason these methods return an element, instead of void, is to allow filtering.
 * 
 * Concerning thread-safety, delegates implementing the method are invoked one-at-a-time to
 * allow thread-safe modification of the given elements.
 * 
 * You should NOT implement these methods unless you have good reason to do so.
 * For general processing and notification of sent elements, please use xmppStream:didSendX: methods.
 * 
 * @see xmppStream:didSendIQ:
 * @see xmppStream:didSendMessage:
 * @see xmppStream:didSendPresence:
**/
- (XMPPIQ *)xmppStream:(XMPPStream *)sender willSendIQ:(XMPPIQ *)iq;
- (XMPPMessage *)xmppStream:(XMPPStream *)sender willSendMessage:(XMPPMessage *)message;
- (XMPPPresence *)xmppStream:(XMPPStream *)sender willSendPresence:(XMPPPresence *)presence;

/**
 * These methods are called after their respective XML elements are sent over the stream.
 * These methods may be used to listen for certain events (such as an unavailable presence having been sent),
 * or for general logging purposes. (E.g. a central history logging mechanism).
**/
- (void)xmppStream:(XMPPStream *)sender didSendIQ:(XMPPIQ *)iq;
- (void)xmppStream:(XMPPStream *)sender didSendMessage:(XMPPMessage *)message;
- (void)xmppStream:(XMPPStream *)sender didSendPresence:(XMPPPresence *)presence;

/**
 * These methods are called after failing to send the respective XML elements over the stream.
 * This occurs when the stream gets disconnected before the element can get sent out.
**/
- (void)xmppStream:(XMPPStream *)sender didFailToSendIQ:(XMPPIQ *)iq error:(NSError *)error;
- (void)xmppStream:(XMPPStream *)sender didFailToSendMessage:(XMPPMessage *)message error:(NSError *)error;
- (void)xmppStream:(XMPPStream *)sender didFailToSendPresence:(XMPPPresence *)presence error:(NSError *)error;

/**
 * This method is called if the XMPP Stream's jid changes.
**/
- (void)xmppStreamDidChangeMyJID:(XMPPStream *)xmppStream;

/**
 * This method is called if the disconnect method is called.
 * It may be used to determine if a disconnection was purposeful, or due to an error.
 * 
 * Note: A disconnect may be either "clean" or "dirty".
 * A "clean" disconnect is when the stream sends the closing </stream:stream> stanza before disconnecting.
 * A "dirty" disconnect is when the stream simply closes its TCP socket.
 * In most cases it makes no difference how the disconnect occurs,
 * but there are a few contexts in which the difference has various protocol implications.
 * 
 * @see xmppStreamDidSendClosingStreamStanza
**/
- (void)xmppStreamWasToldToDisconnect:(XMPPStream *)sender;

/**
 * This method is called after the stream has sent the closing </stream:stream> stanza.
 * This signifies a "clean" disconnect.
 * 
 * Note: A disconnect may be either "clean" or "dirty".
 * A "clean" disconnect is when the stream sends the closing </stream:stream> stanza before disconnecting.
 * A "dirty" disconnect is when the stream simply closes its TCP socket.
 * In most cases it makes no difference how the disconnect occurs,
 * but there are a few contexts in which the difference has various protocol implications.
**/
- (void)xmppStreamDidSendClosingStreamStanza:(XMPPStream *)sender;

/**
 * This method is called if the XMPP stream's connect times out.
**/
- (void)xmppStreamConnectDidTimeout:(XMPPStream *)sender;

/**
 * This method is called after the stream is closed.
 * 
 * The given error parameter will be non-nil if the error was due to something outside the general xmpp realm.
 * Some examples:
 * - The TCP socket was unexpectedly disconnected.
 * - The SRV resolution of the domain failed.
 * - Error parsing xml sent from server.
 * 
 * @see xmppStreamConnectDidTimeout:
**/
- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error;

/**
 * This method is only used in P2P mode when the connectTo:withAddress: method was used.
 * 
 * It allows the delegate to read the <stream:features/> element if/when they arrive.
 * Recall that the XEP specifies that <stream:features/> SHOULD be sent.
**/
- (void)xmppStream:(XMPPStream *)sender didReceiveP2PFeatures:(NSXMLElement *)streamFeatures;

/**
 * This method is only used in P2P mode when the connectTo:withSocket: method was used.
 * 
 * It allows the delegate to customize the <stream:features/> element,
 * adding any specific featues the delegate might support.
**/
- (void)xmppStream:(XMPPStream *)sender willSendP2PFeatures:(NSXMLElement *)streamFeatures;

/**
 * These methods are called as xmpp modules are registered and unregistered with the stream.
 * This generally corresponds to xmpp modules being initailzed and deallocated.
 * 
 * The methods may be useful, for example, if a more precise auto delegation mechanism is needed
 * than what is available with the autoAddDelegate:toModulesOfClass: method.
**/
- (void)xmppStream:(XMPPStream *)sender didRegisterModule:(id)module;
- (void)xmppStream:(XMPPStream *)sender willUnregisterModule:(id)module;

/**
 * Custom elements are Non-XMPP elements.
 * In other words, not <iq>, <message> or <presence> elements.
 * 
 * Typically these kinds of elements are not allowed by the XMPP server.
 * But some custom implementations may use them.
 * The standard example is XEP-0198, which uses <r> & <a> elements.
 * 
 * If you're using custom elements, you must register the custom element name(s).
 * Otherwise the xmppStream will treat non-XMPP elements as errors (xmppStream:didReceiveError:).
 * 
 * @see registerCustomElementNames (in XMPPInternal.h)
**/
- (void)xmppStream:(XMPPStream *)sender didSendCustomElement:(NSXMLElement *)element;
- (void)xmppStream:(XMPPStream *)sender didReceiveCustomElement:(NSXMLElement *)element;

@end
