#import <Foundation/Foundation.h>
#import "XMPPSASLAuthentication.h"
#import "XMPPStream.h"
#import "XMPPModule.h"

@class XMPPRebindAuthentication;


/**
 * Process One has a proprietary module they sell for ejabberd that enables several
 * features such as push notifications and fast reconnect.
 * 
 * This file implements the client side functionality for XMPPFramework.
**/
@interface XMPPProcessOne : XMPPModule

/**
 * Once a connection is authenticated, the module automatically stores the session ID and related JID.
 * The information is stored in the user defaults system, thus it is persisted across launches of the application.
 * 
 * If the session information is available, and the server supports rebind, fast reconnect may be possible.
**/
@property (strong, readwrite) NSString *savedSessionID;
@property (strong, readwrite) XMPPJID *savedSessionJID;
@property (strong, readwrite) NSDate *savedSessionDate;

/**
 * Push Mode Configuration.
 * Options are detailed in the documentation from ejabberd.
 * 
 * An example of a pushConfiguration element you would set:
 * 
 * <push xmlns='p1:push'>
 *    <keepalive max='30'/>
 *    <session duration='60'/>
 *    <body send='all' groupchat='true' from='jid'/>
 *    <status type='xa'>Text Message when in push mode</status>
 *    <offline>false</offline>
 *    <notification>
 *        <type>applepush</type>
 *        <id>DeviceToken</id>
 *    </notification>
 *    <appid>application1</appid>
 * </push>
 * 
 * To enable Apple Push on the ejabberd server, you must set the pushConfiguration element.
 * 
 * You may set the pushConfiguration element at any time.
 * If you set it after the xmpp stream has already authenticated, then the push settings will be sent right away.
 * Otherwise, the push settings will be sent as soon as the stream is authenticated.
 * 
 * After the pushConfiguration element has been set, you can change it at any time.
 * If you do, it will send the updated configuration options to the server.
 * 
 * To disable push, you can simply set the pushConfiguration to nil.
 * 
 * @see pushConfigurationContainer
**/
@property (readwrite, strong) NSXMLElement *pushConfiguration;

/**
 * Standby Mode.
 * The following methods allow you to switch on/off standby mode.
 * 
 * Typical use case looks like this:
 * 
 * - (void)applicationWillResignActive:(NSNotification *)notification
 * {
 *     // Send standby element (via normal asynchronous mechanism)
 *     XMPPElementReceipt *receipt = [xmppProcessOne goOnStandby];
 *     
 *     // Wait until standby element gets sent (pumped through dispatch queues and into OS socket buffer)
 *     [receipt wait:-1.0];
 * }
 * 
 * - (void)applicationDidBecomeActive:(NSNotification *)notification
 * {
 *     [xmppProcessOne goOffStandby];
 * }
**/
- (XMPPElementReceipt *)goOnStandby;
- (XMPPElementReceipt *)goOffStandby;

/**
 * Methods to help create the pushConfiguration required to enable anything on the server.
**/

+ (NSXMLElement *)pushConfigurationContainer;

+ (NSXMLElement *)keepaliveWithMax:(NSTimeInterval)max;
+ (NSXMLElement *)sessionWithDuration:(NSTimeInterval)duration;
+ (NSXMLElement *)statusWithType:(NSString *)type message:(NSString *)message;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface XMPPRebindAuthentication : NSObject <XMPPSASLAuthentication>

- (id)initWithStream:(XMPPStream *)stream sessionID:(NSString *)sessionID sessionJID:(XMPPJID *)sessionJID;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface XMPPStream (XMPPProcessOne)

- (BOOL)supportsPush;
- (BOOL)supportsRebind;

- (NSString *)rebindSessionID;

@end
