#import <UIKit/UIKit.h>
#import "XMPPFramework.h"

@class AutoTimeTestViewController;


@interface AutoTimeTestAppDelegate : NSObject <UIApplicationDelegate>
{
	XMPPStream *xmppStream;
	XMPPAutoTime *xmppAutoTime;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet AutoTimeTestViewController *viewController;

@end
