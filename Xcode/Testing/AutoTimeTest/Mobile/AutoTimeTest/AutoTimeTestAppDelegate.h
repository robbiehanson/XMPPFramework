#import <UIKit/UIKit.h>
#import "XMPPFramework.h"

@class AutoTimeTestViewController;


@interface AutoTimeTestAppDelegate : NSObject <UIApplicationDelegate>
{
	XMPPStream *xmppStream;
	XMPPAutoTime *xmppAutoTime;
}

@property (nonatomic) IBOutlet UIWindow *window;
@property (nonatomic) IBOutlet AutoTimeTestViewController *viewController;

@end
