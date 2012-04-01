#import <UIKit/UIKit.h>
#import "XMPPFramework.h"

@class AutoPingTestViewController;

@interface AutoPingTestAppDelegate : NSObject <UIApplicationDelegate>
{
	XMPPStream *xmppStream;
	XMPPAutoPing *xmppAutoPing;
}

@property (nonatomic) IBOutlet UIWindow *window;
@property (nonatomic) IBOutlet AutoPingTestViewController *viewController;

@end
