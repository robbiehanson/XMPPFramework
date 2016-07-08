#import "AppDelegate.h"
#import "MulticastDelegateTest.h"


@implementation AppDelegate

@synthesize window = _window;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	double delayInSeconds = 2.0;
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		NSLog(@"Starting test in 2 seconds...");
	});
	
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
		
		[[MulticastDelegateTest sharedInstance] test];
	});
	
	self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	self.window.backgroundColor = [UIColor whiteColor];
	[self.window makeKeyAndVisible];
	return YES;
}

@end
