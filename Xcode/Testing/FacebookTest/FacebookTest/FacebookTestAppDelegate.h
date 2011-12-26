#import <UIKit/UIKit.h>
#import "FBConnect.h"

@class XMPPStream;
@class FacebookTestViewController;


@interface FacebookTestAppDelegate : NSObject <UIApplicationDelegate, FBSessionDelegate>
{
	Facebook *facebook;
	XMPPStream *xmppStream;
}

@property (nonatomic, strong) IBOutlet UIWindow *window;
@property (nonatomic, strong) IBOutlet FacebookTestViewController *viewController;

@end
