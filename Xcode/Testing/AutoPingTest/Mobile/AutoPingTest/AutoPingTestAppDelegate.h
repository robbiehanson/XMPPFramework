#import <UIKit/UIKit.h>
#import "XMPPFramework.h"

@class AutoPingTestViewController;

@interface AutoPingTestAppDelegate : NSObject <UIApplicationDelegate>
{
	XMPPStream *xmppStream;
	XMPPAutoPing *xmppAutoPing;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet AutoPingTestViewController *viewController;

@end
