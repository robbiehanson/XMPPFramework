#import <Cocoa/Cocoa.h>
@class  AsyncSocket;

@interface XMPPStream : NSObject
{
	id delegate;
	
	int state;
	AsyncSocket *asyncSocket;
	
	BOOL isSecure;
	BOOL isAuthenticated;
	BOOL allowsSelfSignedCertificates;
	NSString *xmppHostName;
	
	NSMutableData *buffer;
	NSXMLElement *rootElement;
	
	NSData *terminator;
	
	NSString *authUsername;
	NSString *authResource;
	NSString *tempPassword;
	
	NSTimer *keepAliveTimer;
}

- (id)init;
- (id)initWithDelegate:(id)delegate;

- (id)delegate;
- (void)setDelegate:(id)delegate;

- (BOOL)allowsSelfSignedCertificates;
- (void)setAllowsSelfSignedCertificates:(BOOL)flag;

- (BOOL)isDisconnected;
- (BOOL)isConnected;
- (BOOL)isSecure;
- (void)connectToHost:(NSString *)hostName onPort:(int)portNumber withVirtualHost:(NSString *)vHostName;
- (void)connectToSecureHost:(NSString *)hostName onPort:(int)portNumber withVirtualHost:(NSString *)vHostName;

- (void)disconnect;

- (BOOL)supportsInBandRegistration;
- (void)registerUser:(NSString *)username withPassword:(NSString *)password;

- (BOOL)supportsPlainAuthentication;
- (BOOL)supportsDigestMD5Authentication;
- (void)authenticateUser:(NSString *)username withPassword:(NSString *)password resource:(NSString *)resource;

- (BOOL)isAuthenticated;
- (NSString *)authenticatedUsername;
- (NSString *)authenticatedResource;

- (NSXMLElement *)rootElement;

- (void)sendElement:(NSXMLElement *)element;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Delegate Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface NSObject (XMPPStreamDelegate)

/**
 * This method is called after an XML stream has been opened.
 * More precisely, this method is called after an opening <xml/> and <stream:stream/> tag have been sent and received,
 * and after the stream features have been received, and any required features have been fullfilled.
 * At this point it's safe to begin communication with the server.
**/
- (void)xmppStreamDidOpen:(XMPPStream *)xs;

/**
 * This method is called after registration of a new user has successfully finished.
 * If registration fails for some reason, the xmppStream:didReceiveError: method will be called instead.
**/
- (void)xmppStreamDidRegister:(XMPPStream *)xs;

/**
 * This method is called after authentication has successfully finished.
 * If authentication fails for some reason, the xmppStream:didReceiveError: method will be called instead.
**/
- (void)xmppStreamDidAuthenticate:(XMPPStream *)xs;

/**
 * These methods are called after their respective XML elements are received on the stream.
**/
- (void)xmppStream:(XMPPStream *)xs didReceiveIQ:(NSXMLElement *)iq;
- (void)xmppStream:(XMPPStream *)xs didReceiveMessage:(NSXMLElement *)message;
- (void)xmppStream:(XMPPStream *)xs didReceivePresence:(NSXMLElement *)presence;

/**
 * There are two types of errors: TCP errors and XMPP errors.
 * If a TCP error is encountered (failure to connect, broken connection, etc) a standard NSError object is passed.
 * If an XMPP error is encountered (<stream:error> for example) an NSXMLElement object is passed.
 * 
 * Note that standard errors (<iq type='error'/> for example) are delivered normally,
 * via the other didReceive...: methods.
**/
- (void)xmppStream:(XMPPStream *)xs didReceiveError:(id)error;

/**
 * This method is called after the stream is closed.
**/
- (void)xmppStreamDidClose:(XMPPStream *)xs;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NSXMLElement Category:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface NSXMLElement (XMPPStreamAdditions)

- (NSXMLElement *)elementForName:(NSString *)name;
- (NSXMLElement *)elementForName:(NSString *)name xmlns:(NSString *)xmlns;
- (NSString *)xmlns;
- (NSDictionary *)attributesAsDictionary;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// DIGEST ACCESS AUTHENTICATION
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
