#import <UIKit/UIKit.h>
#import "FBConnect.h"

@class XMPPStreamFacebook;
@class FacebookTestViewController;


@interface FacebookTestAppDelegate : NSObject <UIApplicationDelegate, FBSessionDelegate>
{
	Facebook *facebook;
	XMPPStreamFacebook *xmppStream;
	
	BOOL allowSelfSignedCertificates;
	BOOL allowSSLHostNameMismatch;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet FacebookTestViewController *viewController;

@end
