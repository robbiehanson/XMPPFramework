#import "AppDelegate.h"
#import "XMPPJID.h"

#define COUNT 250000

@interface XMPPJID (PerformanceTest)
- (NSUInteger)oldHash;
@end

@implementation XMPPJID (PerformanceTest)
- (NSUInteger)oldHash
{
	return [[self full] hash];
}
@end


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

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	XMPPJID *jid = [XMPPJID jidWithString:@"robbiehanson@deusty.com/rSrC"];
	
	[self testOldHash:jid];
	[self testNewHash:jid];
}

@end
