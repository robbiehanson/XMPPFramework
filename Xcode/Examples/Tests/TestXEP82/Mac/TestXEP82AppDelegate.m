#import "TestXEP82AppDelegate.h"
#import "TestXEP82.h"


@implementation TestXEP82AppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[TestXEP82 runTests];
}

@end
