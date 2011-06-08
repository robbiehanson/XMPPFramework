#import "MulticastDelegateTestAppDelegate.h"
#import "Class1.h"
#import "Class2.h"
#import <libkern/OSAtomic.h>

#define dispatch_current_queue_label() dispatch_queue_get_label(dispatch_get_current_queue())

@interface MulticastDelegateTestAppDelegate (PrivateAPI)

- (void)testVoidMethods;
- (void)testAnyBoolMethod;
- (void)testAllBoolMethod;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation MulticastDelegateTestAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	multicastDelegate = [[GCDMulticastDelegate alloc] init];
	
	del1 = [[Class1 alloc] init];
	del2 = [[Class2 alloc] init];
	
	queue1 = dispatch_queue_create("S", NULL);
	queue2 = dispatch_queue_create("1", NULL);
	queue3 = dispatch_queue_create("2", NULL);
	
	[multicastDelegate addDelegate:self delegateQueue:queue1];
	[multicastDelegate addDelegate:del1 delegateQueue:queue2];
	[multicastDelegate addDelegate:del2 delegateQueue:queue3];
	
	[self testVoidMethods];
	[self testAnyBoolMethod];
	[self testAllBoolMethod];
}

- (void)testVoidMethods
{
	[multicastDelegate didSomething];
	[multicastDelegate didSomethingElse:YES];
	
	[multicastDelegate foundString:@"I like cheese"];
	[multicastDelegate foundString:@"The lucky number is" andNumber:[NSNumber numberWithInt:15]];
}

- (void)testAnyBoolMethod
{
	// If ANY of the delegates return YES, then the result is YES.
	// Otherwise the result is NO.
	// If there are no delegates, the default result is NO.
	
	SEL selector = @selector(shouldSing);
	BOOL result = NO;
	
	GCDMulticastDelegateEnumerator *delegateEnum = [multicastDelegate delegateEnumerator];
	
	dispatch_group_t delGroup = dispatch_group_create();
	dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
	
	id del;
	dispatch_queue_t dq;
	
	while ([delegateEnum getNextDelegate:&del delegateQueue:&dq forSelector:selector])
	{
		dispatch_group_async(delGroup, dq, ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			if ([del shouldSing])
			{
				dispatch_semaphore_signal(semaphore);
			}
			
			[pool drain];
		});
	}
	
	dispatch_group_wait(delGroup, DISPATCH_TIME_FOREVER);
	
	if (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW) == 0)
		result = YES;
	else
		result = NO;
	
	dispatch_release(delGroup);
	dispatch_release(semaphore);
	
	NSLog(@"%@ (ANY) = %@", NSStringFromSelector(selector), (result ? @"YES" : @"NO"));
}

- (void)testAllBoolMethod
{
	// If ALL of the delegates return YES, then the result is YES.
	// If ANY of the delegates returns NO, then the result is NO.
	// If there are no delegates, the default answer is YES.
	
	SEL selector = @selector(shouldDance);
	BOOL result = YES;
	
	GCDMulticastDelegateEnumerator *delegateEnum = [multicastDelegate delegateEnumerator];
	
	int32_t total = (int32_t)[delegateEnum countForSelector:selector];
	
	dispatch_group_t delGroup = dispatch_group_create();
	__block int32_t value = 0;
	
	id del;
	dispatch_queue_t dq;
	
	while ([delegateEnum getNextDelegate:&del delegateQueue:&dq forSelector:selector])
	{
		dispatch_group_async(delGroup, dq, ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			if ([del shouldDance])
			{
				OSAtomicIncrement32(&value);
			}
			
			[pool drain];
		});
	}
	
	dispatch_group_wait(delGroup, DISPATCH_TIME_FOREVER);
	OSMemoryBarrier();
	
	if (OSAtomicCompareAndSwap32(total, total, &value))
		result = YES;
	else
		result = NO;
	
	NSLog(@"%@ (ALL) = %@", NSStringFromSelector(selector), (result ? @"YES" : @"NO"));
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Delegate Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)didSomething
{
	NSLog(@"Self(%s)  : didSomething", dispatch_current_queue_label());
}

- (void)didSomethingElse:(BOOL)flag
{
	NSLog(@"Self(%s)  : didSomethingElse:%@", dispatch_current_queue_label(), (flag ? @"YES" : @"NO"));
}

- (void)foundString:(NSString *)str
{
	NSLog(@"Self(%s)  : foundString:\"%@\"", dispatch_current_queue_label(), str);
	
//	[multicastDelegate removeDelegate:self];
//	[multicastDelegate removeDelegate:del2];
}

- (void)foundString:(NSString *)str andNumber:(NSNumber *)num
{
	NSLog(@"Self(%s)  : foundString:\"%@\" andNumber:%@", dispatch_current_queue_label(), str, num);
}

- (BOOL)shouldSing
{
	BOOL answer = NO;
	
	NSLog(@"Self(%s)  : shouldSing: returning %@", dispatch_current_queue_label(), (answer ? @"YES" : @"NO"));
	
	return answer;
}

- (BOOL)shouldDance
{
	BOOL answer = NO;
	
	NSLog(@"Self(%s)  : shouldDance: returning %@", dispatch_current_queue_label(), (answer ? @"YES" : @"NO"));
	
	return answer;
}

- (void)fastTrack
{
	NSLog(@"Self(%s)  : fastTrack", dispatch_current_queue_label());
}

@end
