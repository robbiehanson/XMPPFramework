#import "MulticastDelegateTest.h"
#import "GCDMulticastDelegate.h"
#import "MyProtocol.h"
#import "DelegateTesters.h"


@interface MulticastDelegateTest ()
{
	GCDMulticastDelegate <MyProtocol> *multicastDelegate;
	
	dispatch_queue_t queue1;
	dispatch_queue_t queue2;
	dispatch_queue_t queue3;
	
	DelegateTester1 *del1;
	DelegateTester2 *del2;
	DelegateTester3 *del3;
}

- (void)testVoidMethods;
- (void)testBoolMethod1;
- (void)testBoolMethod2;
- (void)testWeakReferenceSystem;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation MulticastDelegateTest

static MulticastDelegateTest *sharedInstance;

+ (MulticastDelegateTest *)sharedInstance
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		sharedInstance = [[MulticastDelegateTest alloc] init];
	});
	
	return sharedInstance;
}

- (id)init
{
	if ((self = [super init]))
	{
		multicastDelegate = (GCDMulticastDelegate <MyProtocol> *)[[GCDMulticastDelegate alloc] init];
		
		del1 = [[DelegateTester1 alloc] init];
		del2 = [[DelegateTester2 alloc] init];
		del3 = [[DelegateTester3 alloc] init];
		
		queue1 = dispatch_queue_create("(1  )", NULL);
		queue2 = dispatch_queue_create("( 2 )", NULL);
		queue3 = dispatch_queue_create("(  3)", NULL);
		
		[multicastDelegate addDelegate:del1 delegateQueue:queue1];
		[multicastDelegate addDelegate:del2 delegateQueue:queue2];
		[multicastDelegate addDelegate:del3 delegateQueue:queue3];
	}
	return self;
}

- (void)test
{
	[self testVoidMethods];
	[self testBoolMethod1];
	[self testBoolMethod2];
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		[self testWeakReferenceSystem];
	});
}

- (void)testVoidMethods
{
	[multicastDelegate didSomething];
	[multicastDelegate didSomethingElse:YES];
	
	[multicastDelegate foundString:@"I like cheese"];
	[multicastDelegate foundString:@"The lucky number is" andNumber:[NSNumber numberWithInt:15]];
}

- (void)testBoolMethod1
{
	// If ANY of the delegates return YES, then the result is YES.
	// Otherwise the result is NO.
	
	BOOL result = NO;
	SEL selector = @selector(shouldSing);
	
	NSUInteger delegateCount = [multicastDelegate countForSelector:selector];
	if (delegateCount == 0)
	{
		// No delegates implement selector
		NSLog(@"%@ (Any YES -> YES, otherwise NO) = %@", NSStringFromSelector(selector), (result ? @"YES" : @"NO"));
	}
	else
	{
		GCDMulticastDelegateEnumerator *delegateEnum = [multicastDelegate delegateEnumerator];
		
		dispatch_group_t delGroup = dispatch_group_create();
		dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
		
		id del;
		dispatch_queue_t dq;
		
		while ([delegateEnum getNextDelegate:&del delegateQueue:&dq forSelector:selector])
		{
			dispatch_group_async(delGroup, dq, ^{ @autoreleasepool {
				
				if ([del shouldSing])
				{
					dispatch_semaphore_signal(semaphore);
				}
			}});
		}
		
		dispatch_group_wait(delGroup, DISPATCH_TIME_FOREVER);
		
		// If the semaphore has been signaled, then dispatch_semaphore_wait will return zero.
		result = (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW) == 0);

		#if !OS_OBJECT_USE_OBJC
		dispatch_release(delGroup);
		dispatch_release(semaphore);
		#endif

		NSLog(@"%@ (Any YES -> YES, otherwise NO) = %@", NSStringFromSelector(selector), (result ? @"YES" : @"NO"));
	}
}

- (void)testBoolMethod2
{
	// If ANY of the delegates returns NO, then the result is NO.
	// Otherwise the result is YES.
	
	BOOL result = YES;
	SEL selector = @selector(shouldDance);
	
	NSUInteger delegateCount = [multicastDelegate countForSelector:selector];
	if (delegateCount == 0)
	{
		NSLog(@"%@ (Any NO -> NO, otherwise YES) = %@", NSStringFromSelector(selector), (result ? @"YES" : @"NO"));
	}
	else
	{
		GCDMulticastDelegateEnumerator *delegateEnum = [multicastDelegate delegateEnumerator];
		
		dispatch_group_t delGroup = dispatch_group_create();
		dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
		
		id del;
		dispatch_queue_t dq;
		
		while ([delegateEnum getNextDelegate:&del delegateQueue:&dq forSelector:selector])
		{
			dispatch_group_async(delGroup, dq, ^{ @autoreleasepool {
				
				if (![del shouldDance])
				{
					dispatch_semaphore_signal(semaphore);
				}
			}});
		}
		
		dispatch_group_wait(delGroup, DISPATCH_TIME_FOREVER);
		
		// If the semaphore has been signaled, then dispatch_semaphore_wait will return zero.
		result = (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW) != 0);
		
		NSLog(@"%@ (Any NO -> NO, otherwise YES) = %@", NSStringFromSelector(selector), (result ? @"YES" : @"NO"));
	}
}

- (void)testWeakReferenceSystem
{
	// Deallocate del1 without removing from multicastDelegate list
	del1 = nil;
	
	[multicastDelegate didSomething];
}

@end
