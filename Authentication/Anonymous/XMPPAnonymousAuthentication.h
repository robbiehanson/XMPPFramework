#import <Foundation/Foundation.h>
#import "XMPPSASLAuthentication.h"
#import "XMPP.h"

NS_ASSUME_NONNULL_BEGIN
@interface XMPPAnonymousAuthentication : NSObject <XMPPSASLAuthentication>

- (instancetype)initWithStream:(XMPPStream *)stream;

// This class implements the XMPPSASLAuthentication protocol.
// 
// See XMPPSASLAuthentication.h for more information.

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface XMPPStream (XMPPAnonymousAuthentication)

/**
 * Returns whether or not the server support anonymous authentication.
 * 
 * This information is available after the stream is connected.
 * In other words, after the delegate has received xmppStreamDidConnect: notification.
**/
@property (nonatomic, readonly) BOOL supportsAnonymousAuthentication;

/**
 * This method attempts to start the anonymous authentication process.
 * 
 * This method is asynchronous.
 * 
 * If there is something immediately wrong,
 * such as the stream is not connected or doesn't support anonymous authentication,
 * the method will return NO and set the error.
 * Otherwise the delegate callbacks are used to communicate auth success or failure.
 * 
 * @see xmppStreamDidAuthenticate:
 * @see xmppStream:didNotAuthenticate:
**/
- (BOOL)authenticateAnonymously:(NSError **)errPtr;

@end
NS_ASSUME_NONNULL_END
