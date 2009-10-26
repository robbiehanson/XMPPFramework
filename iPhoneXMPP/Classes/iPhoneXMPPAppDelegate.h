#import <UIKit/UIKit.h>

@class XMPPClient;


@interface iPhoneXMPPAppDelegate : NSObject <UIApplicationDelegate>
{
	XMPPClient *xmppClient;
    
    UIWindow *window;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;

@end

