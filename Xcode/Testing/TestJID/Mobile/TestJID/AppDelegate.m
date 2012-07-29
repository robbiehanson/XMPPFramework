#import "AppDelegate.h"
#import "XMPPJID.h"

#define COUNT 250000

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface XMPPJID (PerformanceTest)
- (NSUInteger)oldHash;
@end

@implementation XMPPJID (PerformanceTest)
- (NSUInteger)oldHash
{
	return [[self full] hash];
}
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation AppDelegate

@synthesize window = _window;

- (void)testOldHash:(XMPPJID *)jid
{
	NSDate *start = [NSDate date];
	
	for (int i = 0; i < COUNT; i++)
	{
		(void)[jid oldHash];
	}
	
	NSTimeInterval elapsed = [start timeIntervalSinceNow] * -1.0;
	NSLog(@"%@ - %.5f", NSStringFromSelector(_cmd), elapsed);
}

- (void)testNewHash:(XMPPJID *)jid
{
	NSDate *start = [NSDate date];
	
	for (int i = 0; i < COUNT; i++)
	{
		(void)[jid hash];
	}
	
	NSTimeInterval elapsed = [start timeIntervalSinceNow] * -1.0;
	NSLog(@"%@ - %.5f", NSStringFromSelector(_cmd), elapsed);
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	XMPPJID *jid = [XMPPJID jidWithString:@"robbiehanson@deusty.com/rSrC"];
	
	[self testOldHash:jid];
	[self testNewHash:jid];
	
	self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	self.window.backgroundColor = [UIColor whiteColor];
	[self.window makeKeyAndVisible];
	return YES;
}

@end
