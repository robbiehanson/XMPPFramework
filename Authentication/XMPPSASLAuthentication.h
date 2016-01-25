#import <Foundation/Foundation.h>
@import KissXML;

@class XMPPStream;


typedef NS_ENUM(NSInteger, XMPPHandleAuthResponse) {
	
	XMPP_AUTH_FAIL,     // Authentication failed.
	                    // The delegate will be informed via xmppStream:didNotAuthenticate:
	
	XMPP_AUTH_SUCCESS,  // Authentication succeeded.
	                    // The delegate will be informed via xmppStreamDidAuthenticate:
	
	XMPP_AUTH_CONTINUE, // The authentication process is still ongoing.
};


@protocol XMPPSASLAuthentication <NSObject>
@required

/**
 * Returns the associated mechanism name.
 * 
 * An xmpp server sends a list of supported authentication mechanisms during the xmpp handshake.
 * The list looks something like this:
 * 
 * <stream:features>
 *    <mechanisms xmlns="urn:ietf:params:xml:ns:xmpp-sasl">
 *       <mechanism>DIGEST-MD5</mechanism>
 *       <mechanism>X-FACEBOOK-PLATFORM</mechanism>
 *       <mechanism>X-YOUR-CUSTOM-AUTH-SCHEME</mechanism>
 *    </mechanisms>
 * </stream:features>
 * 
 * The mechanismName returned should match the value inside the <mechanism>HERE</mechanism>.
**/
+ (NSString *)mechanismName;

/**
 * Standard init method.
 * 
 * The XMPPStream class natively supports the standard authentication scheme (auth with password).
 * If that method is used, then xmppStream will automatically create an authentication instance via this method.
 * Which authentication class it chooses is based on the configured authentication priorities,
 * and the auth mechanisms supported by the server.
 * 
 * Not all authentication mechanisms will use this init method.
 * For example:
 *  - they require an appId and authToken
 *  - they require a userName (not related to JID), privilegeLevel, and password
 *  - they require an eyeScan and voiceFingerprint
 * 
 * In this case, the authentication mechanism class should provide it's own custom init method.
 * However it should still implement this method, and then use the start method to notify of errors.
**/
- (id)initWithStream:(XMPPStream *)stream password:(NSString *)password;


/**
 * Attempts to start the authentication process.
 * The auth mechanism should send whatever stanzas are needed to begin the authentication process.
 * 
 * If it isn't possible to start the authentication process (perhaps due to missing information),
 * this method should return NO and set an appropriate error message.
 * For example: "X-Custom-Platform authentication requires authToken"
 * Otherwise this method should return YES.
 * 
 * This method is called by automatically XMPPStream (via the authenticate: method).
 * You should NOT invoke this method manually.
**/
- (BOOL)start:(NSError **)errPtr;

/**
 * After the authentication process has started, all incoming xmpp stanzas are routed to this method.
 * The authentication mechanism should process the stanza as appropriate, and return the coresponding result.
 * If the authentication is not yet complete, it should return XMPP_AUTH_CONTINUE,
 * meaning the xmpp stream will continue to forward all incoming xmpp stanzas to this method.
 * 
 * This method is called automatically by XMPPStream (via the authenticate: method).
 * You should NOT invoke this method manually.
**/
- (XMPPHandleAuthResponse)handleAuth:(NSXMLElement *)auth;

@optional

/**
 * Use this init method if the username used for authentication does not match the user part of the JID.
 * If username is nil, the user part of the JID will be used.
 * The standard init method uses this init method, passing nil for the username.
 **/
- (id)initWithStream:(XMPPStream *)stream username:(NSString *)username password:(NSString *)password;

/**
 * Optionally implement this method to override the default behavior.
 * The default value is YES.
**/
- (BOOL)shouldResendOpeningNegotiationAfterSuccessfulAuthentication;

@end
