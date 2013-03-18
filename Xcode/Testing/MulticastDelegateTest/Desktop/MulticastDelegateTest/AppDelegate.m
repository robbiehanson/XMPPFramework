#import "AppDelegate.h"
#import "MulticastDelegateTest.h"


@implementation AppDelegate

@synthesize window = _window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[[MulticastDelegateTest sharedInstance] test];
}

@end
