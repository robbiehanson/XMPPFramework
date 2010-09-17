#import "MulticastDelegateTestAppDelegate.h"
#import "Class1.h"
#import "Class2.h"

@interface MulticastDelegateTestAppDelegate (PrivateAPI)

- (void)testVoidMethods;
- (void)testAnyBoolMethod;
- (void)testAllBoolMethod;
- (void)testForwardingFastPath;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation MulticastDelegateTestAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	multicastDelegate = [[MulticastDelegate alloc] init];
	
	del1 = [[Class1 alloc] init];
	del2 = [[Class2 alloc] init];
	
	[multicastDelegate addDelegate:self];
	[multicastDelegate addDelegate:del1];
	[multicastDelegate addDelegate:del2];	
	
	[self testVoidMethods];
	[self testAnyBoolMethod];
	[self testAllBoolMethod];
	[self testForwardingFastPath];
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
	
	MulticastDelegateEnumerator *delegateEnum = [multicastDelegate delegateEnumerator];
	id delegate;
	
	while(!result && (delegate = [delegateEnum nextDelegateForSelector:selector]))
	{
		result = [delegate shouldSing];
	}
	
	NSLog(@"%@ = %@", NSStringFromSelector(selector), (result ? @"YES" : @"NO"));
}

- (void)testAllBoolMethod
{
	// If ALL of the delegates return YES, then the result is YES.
	// If ANY of the delegates returns NO, then the result is NO.
	// If there are no delegates, the default answer is YES.
	
	SEL selector = @selector(shouldDance);
	BOOL result = YES;
	
	MulticastDelegateEnumerator *delegateEnum = [multicastDelegate delegateEnumerator];
	id delegate;
	
	while(result && (delegate = [delegateEnum nextDelegateForSelector:selector]))
	{
		result = [delegate shouldDance];
	}
	
	NSLog(@"%@ = %@", NSStringFromSelector(selector), (result ? @"YES" : @"NO"));
}

- (void)testForwardingFastPath
{
	// We are testing the forwardingTargetForSelector method in MulticastDelegate.
	// Only a single delegate should implement the fastTrack method.
	
	[multicastDelegate fastTrack];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Delegate Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)didSomething
{
	NSLog(@"Self: didSomething");
}

- (void)didSomethingElse:(BOOL)flag
{
	NSLog(@"Self: didSomethingElse:%@", (flag ? @"YES" : @"NO"));
}

- (void)foundString:(NSString *)str
{
	NSLog(@"Self: foundString:\"%@\"", str);
	
//	[multicastDelegate removeDelegate:self];
//	[multicastDelegate removeDelegate:del2];
}

- (void)foundString:(NSString *)str andNumber:(NSNumber *)num
{
	NSLog(@"Self: foundString:\"%@\" andNumber:%@", str, num);
}

- (BOOL)shouldSing
{
	BOOL answer = NO;
	
	NSLog(@"Self: shouldSing: returning %@", (answer ? @"YES" : @"NO"));
	
	return answer;
}

- (BOOL)shouldDance
{
	BOOL answer = YES;
	
	NSLog(@"Self: shouldDance: returning %@", (answer ? @"YES" : @"NO"));
	
	return answer;
}

- (void)fastTrack
{
	NSLog(@"Self: fastTrack");
}

@end
