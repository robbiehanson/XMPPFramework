#import "TestXEP82AppDelegate.h"
#import "TestXEP82ViewController.h"
#import "TestXEP82.h"


@implementation TestXEP82AppDelegate

@synthesize window=_window;
@synthesize viewController=_viewController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	[TestXEP82 runTests];
	 
	self.window.rootViewController = self.viewController;
	[self.window makeKeyAndVisible];
    return YES;
}

@end
