#import <Foundation/Foundation.h>
#import "MulticastDelegate.h"

#if TARGET_OS_IPHONE
  #import "DDXML.h"
#endif

@class AsyncSocket;
@class RFSRVResolver;
@class XMPPParser;
@class XMPPJID;
@class XMPPIQ;
@class XMPPMessage;
@class XMPPPresence;
@class XMPPModule;
@protocol XMPPStreamDelegate;

#if TARGET_OS_IPHONE
  #define DEFAULT_KEEPALIVE_INTERVAL 120.0 // 2 Minutes
#else
  #define DEFAULT_KEEPALIVE_INTERVAL 300.0 // 5 Minutes
#endif

extern NSString *const XMPPStreamErrorDomain;

enum XMPPStreamErrorCode
{
	XMPPStreamInvalidType,       // Attempting to access P2P methods in a non-P2P stream, or vice-versa
	XMPPStreamInvalidState,      // Invalid state for requested action, such as connect when already connected
	XMPPStreamInvalidProperty,   // Missing a required property, such as hostName or myJID
	XMPPStreamInvalidParameter,  // Invalid parameter, such as a nil JID
	XMPPStreamUnsupportedAction, // The server doesn't support the requested action
};
typedef enum XMPPStreamErrorCode XMPPStreamErrorCode;


@interface XMPPStream : NSObject
{
	MulticastDelegate <XMPPStreamDelegate> *multicastDelegate;
	
	int state;
	AsyncSocket *asyncSocket;
	NSMutableData *socketBuffer;
	
	UInt64 numberOfBytesSent;
	UInt64 numberOfBytesReceived;
	
	XMPPParser *parser;
	
	Byte flags;
	
	NSString *hostName;
	UInt16 hostPort;
	
	NSString *tempPassword;
	
	XMPPJID *myJID;
	XMPPJID *remoteJID;
	
	NSXMLElement *rootElement;
	
	NSTimeInterval keepAliveInterval;
	NSTimer *keepAliveTimer;
	
	id registeredModules;
	NSMutableDictionary *autoDelegateDict;
	
	id userTag;
	
	RFSRVResolver *_srvResolver;
}

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
- (void)addDelegate:(id)delegate;
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
**/
@property (nonatomic, readwrite, copy) NSString *hostName;

/**
 * The port the xmpp server is running on.
 * If you do not explicitly set the port, the default port will be used.
 * If you set the port to zero, the default port will be used.
 * 
 * The default port is 5222.
**/
@property (nonatomic, readwrite, assign) UInt16 hostPort;

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
@property (nonatomic, readwrite, copy) XMPPJID *myJID;

/**
 * Only used in P2P streams.
**/
@property (nonatomic, readonly) XMPPJID *remoteJID;

/**
 * Many routers will teardown a socket mapping if there is no activity on the socket.
 * For this reason, the xmpp stream supports sending keep alive data.
 * This is simply whitespace, which is ignored by the xmpp protocol.
 * 
 * The default value is defined in DEFAULT_KEEPALIVE_INTERVAL.
 * 
 * To disable keepalive, set the interval to zero.
**/
@property (nonatomic, readwrite, assign) NSTimeInterval keepAliveInterval;

/**
 * Returns the total number of bytes bytes sent/received by the xmpp stream.
 * 
 * By default this is the byte count since the xmpp stream object has been created.
 * If the stream has connected/disconnected/reconnected multiple times,
 * the count will be the summation of all connections.
 * 
 * The functionality may optionaly be changed to count only the current socket connection.
 * See the resetByteCountPerConnection property.
**/
@property (nonatomic, readonly) UInt64 numberOfBytesSent;
@property (nonatomic, readonly) UInt64 numberOfBytesReceived;

/**
 * Affects the funtionality of the byte counter.
 * 
 * The default value is NO.
 * 
 * If set to YES, the byte count will be reset just prior to a new connection (in the connect methods).
**/
@property (nonatomic, readwrite, assign) BOOL resetByteCountPerConnection;

/**
 * Returns a list of all currently registered modules.
 * That is, instances of xmpp extension classes that subclass XMPPModule.
 * 
 * The returned variable is an instance of MulticastDelegate.
**/
@property (nonatomic, readonly) id registeredModules;

/**
 * The tag property allows you to associated user defined information with the stream.
 * Tag values are not used internally, and should not be used by xmpp modules.
**/
@property (nonatomic, readwrite, retain) id tag;

@property (nonatomic, readwrite, retain) RFSRVResolver *srvResolver;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark State
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns YES if the connection is closed, and thus no stream is open.
 * If the stream is neither disconnected, nor connected, then a connection is currently being established.
**/
- (BOOL)isDisconnected;

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
 * If the hostName or myJID are not set, this method will return NO and set the error parameter.
**/
- (BOOL)connect:(NSError **)errPtr;

/**
 * THIS IS DEPRECATED BY THE XMPP SPECIFICATION.
 * 
 * The xmpp specification outlines the proper use of SSL/TLS by negotiating
 * the startTLS upgrade within the stream negotiation.
 * This method exists for those ancient servers that still require the connection to be secured prematurely.
 * 
 * Note: Such servers generally use port 5223 for this, which you will need to set.
**/
- (BOOL)oldSchoolSecureConnect:(NSError **)errPtr;

/**
 * Starts a P2P connection to the given user and given address.
 * This method only works with XMPPStream objects created using the initP2P method.
 * 
 * The given address is specified as a sockaddr structure wrapped in a NSData object.
 * For example, a NSData object returned from NSNetservice's addresses method.
**/
- (BOOL)connectTo:(XMPPJID *)remoteJID withAddress:(NSData *)remoteAddr error:(NSError **)errPtr;

/**
 * Starts a P2P connection with the given accepted socket.
 * This method only works with XMPPStream objects created using the initP2P method.
 * 
 * The given socket should be a socket that has already been accepted.
 * The remoteJID will be extracted from the opening stream negotiation.
**/
- (BOOL)connectP2PWithSocket:(AsyncSocket *)acceptedSocket error:(NSError **)errPtr;

/**
 * Disconnects from the remote host by closing the underlying TCP socket connection.
 * 
 * The disconnect method is synchronous.
 * Meaning that the disconnect will happen immediately, even if there are pending elements yet to be sent.
 * The xmppStreamDidDisconnect: method will be invoked before the disconnect method returns.
 * 
 * The disconnectAfterSending method is asynchronous.
 * The disconnect will happen after all pending elements have been sent.
 * Attempting to send elements after this method is called will not result in the elements getting sent.
 * The disconnectAfterSending method will return immediately,
 * and the xmppStreamDidDisconnect: delegate method will be invoked at a later time.
**/
- (void)disconnect;
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
 * The reason for the error will be reported via the xmppStream:didReceiveError: delegate method.
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
 * The registerWithPassword:error: method is asynchronous.
 * It will return immediately, and the delegate methods are used to determine success.
 * See the xmppStreamDidRegister: and xmppStream:didNotRegister: methods.
 * 
 * If there is something immediately wrong, such as the stream is not connected,
 * this method will return NO and set the error.
 * 
 * The errPtr parameter is optional - you may pass nil.
 * 
 * Security Note:
 * The password will be sent in the clear unless the stream has been secured.
**/
- (BOOL)supportsInBandRegistration;
- (BOOL)registerWithPassword:(NSString *)password error:(NSError **)errPtr;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Authentication
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Authentication.
 * 
 * The authenticateWithPassword:error: method is asynchronous.
 * It will return immediately, and the delegate methods are used to determine success.
 * See the xmppStreamDidAuthenticate: and xmppStream:didNotAuthenticate: methods.
 * 
 * If there is something immediately wrong, such as the stream is not connected,
 * this method will return NO and set the error.
 * 
 * The errPtr parameter is optional - you may pass nil.
 * 
 * The authenticateWithPassword:error: method will choose the most secure protocol to send the password.
 * 
 * Security Note:
 * Care should be taken if sending passwords in the clear is not acceptable.
 * You may use the supportsXAuthentication methods below to determine
 * if an acceptable authentication protocol is supported.
**/
- (BOOL)isAuthenticated;
- (BOOL)supportsAnonymousAuthentication;
- (BOOL)supportsPlainAuthentication;
- (BOOL)supportsDigestMD5Authentication;
- (BOOL)supportsDeprecatedPlainAuthentication;
- (BOOL)supportsDeprecatedDigestAuthentication;
- (BOOL)authenticateWithPassword:(NSString *)password error:(NSError **)errPtr;
- (BOOL)authenticateAnonymously:(NSError **)errPtr;

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
 * Note: The rootElement is "empty", in so much as it does not contain all the XML elements the stream has
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
 * but allows you to receive notification after the element has been sent.
 * 
 * Implement the xmppStream:didSendElementWithTag: delegate method for notification.
 * 
 * It is important to understand what the notification means.
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
- (void)sendElement:(NSXMLElement *)element andNotifyMe:(UInt16)tag;

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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Module Plug-In System
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * The XMPPModule class automatically invokes these methods when it is initialized/deallocated.
**/
- (void)registerModule:(XMPPModule *)module;
- (void)unregisterModule:(XMPPModule *)module;

/**
 * Automatically registers the given delegate with all current and future registered modules of the given class.
 * 
 * That is, the given delegate will be added to the delegate list ([module addDelegate:delegate]) to
 * all current and future registered modules that respond YES to [module isKindOfClass:aClass].
 * 
 * This method is used by modules to automatically integrate with other modules.
 * For example, a module may auto add itself as a delegate to XMPPCapabilities
 * so that it can broadcast its implemented features.
 * 
 * This may be also useful to clients, for example, to add a delegate to instances of something like XMPPChatRoom,
 * where there may be multiple instances of the module that get created during the course of an xmpp session.
 * 
 * If you auto register for multiple classes, you can remove all registrations with a single
 * call to removeAutoDelegate:fromModulesOfClass: by passing nil as the 'aClass' parameter.
**/
- (void)autoAddDelegate:(id)delegate toModulesOfClass:(Class)aClass;
- (void)removeAutoDelegate:(id)delegate fromModulesOfClass:(Class)aClass;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPStreamDelegate
@optional

/**
 * This method is called immediately prior to the stream being secured via TLS/SSL.
 * Note that this delegate may be called even if you do not explicitly invoke the startTLS method.
 * Servers have the option of requiring connections to be secured during the opening process.
 * If this is the case, the XMPPStream will automatically attempt to properly secure the connection.
 * 
 * The possible keys and values for the security settings are well documented.
 * Some possible keys are:
 * - kCFStreamSSLLevel
 * - kCFStreamSSLAllowsExpiredCertificates
 * - kCFStreamSSLAllowsExpiredRoots
 * - kCFStreamSSLAllowsAnyRoot
 * - kCFStreamSSLValidatesCertificateChain
 * - kCFStreamSSLPeerName
 * - kCFStreamSSLCertificates
 * 
 * Please refer to Apple's documentation for associated values, as well as other possible keys.
 * 
 * The dictionary of settings is what will be passed to the startTLS method of ther underlying AsyncSocket.
 * The AsyncSocket header file also contains a discussion of the security consequences of various options.
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
**/
- (void)xmppStream:(XMPPStream *)sender willSecureWithSettings:(NSMutableDictionary *)settings;

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
- (void)xmppStream:(XMPPStream *)sender didNotConnect:(NSError *)error;

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
 * These methods are called after their respective XML elements are received on the stream.
 * 
 * In the case of an IQ, the delegate method should return YES if it has or will respond to the given IQ.
 * If the IQ is of type 'get' or 'set', and no delegates respond to the IQ,
 * then xmpp stream will automatically send an error response.
**/
- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq;
- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message;
- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence;

/**
 * There are two types of errors: TCP errors and XMPP errors.
 * If a TCP error is encountered (failure to connect, broken connection, etc) a standard NSError object is passed.
 * If an XMPP error is encountered (<stream:error> for example) an NSXMLElement object is passed.
 * 
 * Note that standard errors (<iq type='error'/> for example) are delivered normally,
 * via the other didReceive...: methods.
**/
- (void)xmppStream:(XMPPStream *)sender didReceiveError:(id)error;

/**
 * These methods are called before their respective XML elements are sent over the stream.
 * These methods can be used to customize elements on the fly.
 * (E.g. add standard information for custom protocols.)
**/
- (void)xmppStream:(XMPPStream *)sender willSendIQ:(XMPPIQ *)iq;
- (void)xmppStream:(XMPPStream *)sender willSendMessage:(XMPPMessage *)message;
- (void)xmppStream:(XMPPStream *)sender willSendPresence:(XMPPPresence *)presence;

/**
 * These methods are called after their respective XML elements are sent over the stream.
 * These methods may be used to listen for certain events (such as an unavailable presence having been sent),
 * or for general logging purposes. (E.g. a central history logging mechanism).
**/
- (void)xmppStream:(XMPPStream *)sender didSendIQ:(XMPPIQ *)iq;
- (void)xmppStream:(XMPPStream *)sender didSendMessage:(XMPPMessage *)message;
- (void)xmppStream:(XMPPStream *)sender didSendPresence:(XMPPPresence *)presence;

/**
 * This method is called for every sendElement:andNotifyMe: method.
**/
- (void)xmppStream:(XMPPStream *)sender didSendElementWithTag:(UInt16)tag;

/**
 * This method is called if the disconnect method is called.
 * It may be used to determine if a disconnection was purposeful, or due to an error.
**/
- (void)xmppStreamWasToldToDisconnect:(XMPPStream *)sender;

/**
 * This method is called after the stream is closed.
**/
- (void)xmppStreamDidDisconnect:(XMPPStream *)sender;

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

@end
