#import <Foundation/Foundation.h>
#import "DDXML.h"

@class AsyncSocket;
@class XMPPParser;
@class XMPPJID;
@class XMPPIQ;
@class XMPPMessage;
@class XMPPPresence;


@interface XMPPStream : NSObject
{
	id delegate;
	id userTag;
	
	int state;
	AsyncSocket *asyncSocket;
	
	XMPPParser *parser;
	
	Byte flags;
	
	NSString *serverHostName;
	NSString *xmppHostName;
    
    XMPPJID *myJID;
    XMPPJID *remoteJID;
	
	NSXMLElement *rootElement;
	
	NSString *authUsername;
	NSString *authResource;
	NSString *tempPassword;
	
	NSTimer *keepAliveTimer;
}

@property (nonatomic, assign) id delegate;
@property (nonatomic, retain) id tag;

/**
 * Standard XMPP initialization.
 * The stream is a client to server connection.
**/
- (id)init;
- (id)initWithDelegate:(id)delegate;

/**
 * Some xmpp servers use a self-signed certificate.
 * Maybe because they're test servers, or maybe because certificates are expensive.
 * If you're connecting to such a server, you may want to enable this setting.
**/
- (BOOL)allowsSelfSignedCertificates;
- (void)setAllowsSelfSignedCertificates:(BOOL)flag;

/**
 * Some xmpp servers host multiple domains, and are not configured correctly.
 * A prime example is google, whose certificate always uses "gmail.com",
 * even if you connect with "googlemail.com" or some other domain that google is hosting (google apps).
 * If you're connecting to such a server, you may want to enable this setting.
 * 
 * Note: If you use this setting, you may want to manually check the certificate afterwards.
 * To do so you can use the X509Certificate class, which is part of the CocoaAsyncSocket open source project.
**/
- (BOOL)allowsSSLHostNameMismatch;
- (void)setAllowsSSLHostNameMismatch:(BOOL)flag;

/**
 * Returns YES if the connection is closed, and thus no stream is open.
 * If the stream is neither disconnected, nor connected, then a connection is currently being established.
**/
- (BOOL)isDisconnected;

/**
 * Returns YES if the connection is open, and the stream has been properly established.
 * If the stream is neither disconnected, nor connected, then a connection is currently being established.
**/
- (BOOL)isConnected;

/**
 * Returns YES if SSL/TLS was used to establish a connection to the server.
 * Some servers may require an "upgrade to TLS" in order to start communication,
 * so even if the connectToHost:onPort:withVirtualHost: method was used, an ugrade to TLS may have occured.
**/
- (BOOL)isSecure;

/**
 * Connects to the given host on the given port number.
 * If you pass a port number of 0, the default port number for XMPP traffic (5222) is used.
 * The virtual host name is the name of the XMPP host at the given address that we should communicate with.
 * This is generally the domain identifier of the JID. IE: "gmail.com"
 * 
 * If the virtual host name is nil, or an empty string, a virtual host will not be specified in the XML stream
 * connection. This may be OK in some cases, but some servers require it to start a connection.
**/
- (void)connectToHost:(NSString *)hostName onPort:(UInt16)portNumber withVirtualHost:(NSString *)vHostName;

/**
 * THIS IS DEPRECATED BY THE XMPP SPECIFICATION.
 * 
 * The xmpp specification outlines the proper use of SSL/TLS by negotiating
 * the startTLS upgrade within the stream negotiation.
 * This method exists for those ancient servers that still require the connection to be secured prematurely.
 * 
 * If you pass a port number of 0, the default port number for secure XMPP traffic (5223) is used.
**/
- (void)connectToSecureHost:(NSString *)hostName onPort:(UInt16)portNumber withVirtualHost:(NSString *)vHostName;

- (void)disconnect;
- (void)disconnectAfterSending;

- (BOOL)supportsInBandRegistration;
- (void)registerUser:(NSString *)username withPassword:(NSString *)password;

- (BOOL)supportsPlainAuthentication;
- (BOOL)supportsDigestMD5Authentication;
- (BOOL)supportsDeprecatedPlainAuthentication;
- (BOOL)supportsDeprecatedDigestAuthentication;
- (void)authenticateUser:(NSString *)username withPassword:(NSString *)password resource:(NSString *)resource;

- (BOOL)isAuthenticated;
- (NSString *)authenticatedUsername;
- (NSString *)authenticatedResource;

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

- (void)sendElement:(NSXMLElement *)element;
- (void)sendElement:(NSXMLElement *)element andNotifyMe:(long)tag;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark P2P
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
 
// 
// The following methods may be used to create a P2P XMPPStream using XEP-0174.
// 

/**
 * Peer to Peer XMPP initialization.
 * The stream is a direct client to client connection as outlined in XEP-0174.
**/
- (id)initP2PFrom:(XMPPJID *)myJID;

/**
 * Starts a P2P connection to the given user and given address.
 * This method only works with XMPPStream objects created using the initP2P method.
 * 
 * The given address is specified as a sockaddr structure wrapped in a NSData object.
 * For example, a NSData object returned from NSNetservice's addresses method.
**/
- (void)connectTo:(XMPPJID *)remoteJID withAddress:(NSData *)remoteAddr;

/**
 * Starts a P2P connection with the given accepted socket.
 * This method only works with XMPPStream objects created using the initP2P method.
 * 
 * The given socket should be a socket that has already been accepted.
 * The remoteJID will be extracted from the opening stream negotiation.
**/
- (void)connectP2PWithSocket:(AsyncSocket *)acceptedSocket;

/**
 * P2P connection variables.
**/
- (XMPPJID *)myJID;
- (XMPPJID *)remoteJID;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPStreamDelegate
@optional

/**
 * This method is called after an XML stream has been opened.
 * More precisely, this method is called after an opening <xml/> and <stream:stream/> tag have been sent and received,
 * and after the stream features have been received, and any required features have been fullfilled.
 * At this point it's safe to begin communication with the server.
**/
- (void)xmppStreamDidOpen:(XMPPStream *)sender;

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
**/
- (void)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq;
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
 * This method is called for every sendElement:andNotifyMe: method.
**/
- (void)xmppStream:(XMPPStream *)sender didSendElementWithTag:(long)tag;

/**
 * This method is called after the stream is closed.
**/
- (void)xmppStreamDidClose:(XMPPStream *)sender;

/**
 * This method is only used in P2P mode when the connectTo:withAddress: method was used.
 * It allows the delegate to read the <stream:features/> element if/when they arrive.
 * Recall that the XEP specifies that <stream:features/> SHOULD be sent.
**/
- (void)xmppStream:(XMPPStream *)sender didReceiveP2PFeatures:(NSXMLElement *)streamFeatures;

/**
 * This method is only used in P2P mode when the connectTo:withSocket: method was used.
 * It allows the delegate to customize the <stream:features/> element,
 * adding any specific featues the delegate might support.
**/
- (void)xmppStream:(XMPPStream *)sender willSendP2PFeatures:(NSXMLElement *)streamFeatures;

@end
