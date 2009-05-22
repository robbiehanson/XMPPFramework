#import <Foundation/Foundation.h>
#import "DDXML.h"

@class AsyncSocket;
@class XMPPIQ;
@class XMPPMessage;
@class XMPPPresence;


@interface XMPPStream : NSObject
{
	id delegate;
	
	int state;
	AsyncSocket *asyncSocket;
	
	Byte flags;
	
	NSString *serverHostName;
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

- (BOOL)allowsSSLHostNameMismatch;
- (void)setAllowsSSLHostNameMismatch:(BOOL)flag;

- (BOOL)isDisconnected;
- (BOOL)isConnected;
- (BOOL)isSecure;
- (void)connectToHost:(NSString *)hostName onPort:(UInt16)portNumber withVirtualHost:(NSString *)vHostName;
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

- (NSXMLElement *)rootElement;
- (float)serverXmppStreamVersionNumber;

- (void)sendElement:(NSXMLElement *)element;
- (void)sendElement:(NSXMLElement *)element andNotifyMe:(long)tag;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface NSObject (XMPPStreamDelegate)

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

@end

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
