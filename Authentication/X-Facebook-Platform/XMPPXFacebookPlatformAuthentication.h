#import <Foundation/Foundation.h>
#import "XMPPSASLAuthentication.h"
#import "XMPPStream.h"


@interface XMPPXFacebookPlatformAuthentication : NSObject <XMPPSASLAuthentication>

/**
 * You should use this init method (as opposed the one defined in the XMPPSASLAuthentication protocol).
**/
- (id)initWithStream:(XMPPStream *)stream appId:(NSString *)appId accessToken:(NSString *)accessToken;

@end 

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface XMPPStream (XMPPXFacebookPlatformAuthentication)

/**
 * Facebook Chat X-FACEBOOK-PLATFORM SASL authentication initialization.
 * This is a convienence init method to help configure Facebook Chat.
**/
- (id)initWithFacebookAppId:(NSString *)fbAppId;

/**
 * The appId can be passed to custom authentication classes.
 * For example, the appId is used for Facebook Chat X-FACEBOOK-PLATFORM SASL authentication.
**/
@property (readwrite, copy) NSString *facebookAppId;

/**
 * Returns whether or not the server supports X-FACEBOOK-PLATFORM authentication.
 * 
 * This information is available after the stream is connected.
 * In other words, after the delegate has received xmppStreamDidConnect: notification.
**/
- (BOOL)supportsXFacebookPlatformAuthentication;

/**
 * This method attempts to start the facebook oauth authentication process.
 * 
 * This method is asynchronous.
 * 
 * If there is something immediately wrong,
 * such as the stream is not connected or doesn't have a set appId or accessToken,
 * the method will return NO and set the error.
 * Otherwise the delegate callbacks are used to communicate auth success or failure.
 * 
 * @see xmppStreamDidAuthenticate:
 * @see xmppStream:didNotAuthenticate:
 **/
- (BOOL)authenticateWithFacebookAccessToken:(NSString *)accessToken error:(NSError **)errPtr;

@end
