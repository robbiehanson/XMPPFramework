#import "DelegateTesters.h"

#define dispatch_current_queue_label() ({                                     \
	_Pragma("clang diagnostic push");                                           \
	_Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"");          \
	const char *label = dispatch_queue_get_label(dispatch_get_current_queue()); \
	_Pragma("clang diagnostic pop");                                            \
	label;                                                                      \
})

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation DelegateTester1

- (void)didSomething
{
	NSLog(@"%s: didSomething", dispatch_current_queue_label());
}

- (void)didSomethingElse:(BOOL)flag
{
	NSLog(@"%s: didSomethingElse:%@", dispatch_current_queue_label(), (flag ? @"YES" : @"NO"));
}

- (void)foundString:(NSString *)str
{
	NSLog(@"%s: foundString:\"%@\"", dispatch_current_queue_label(), str);
	
	[NSThread sleepForTimeInterval:0.2];
}

- (void)foundString:(NSString *)str andNumber:(NSNumber *)num
{
	NSLog(@"%s: foundString:\"%@\" andNumber:%@", dispatch_current_queue_label(), str, num);
}

- (BOOL)shouldSing
{
	BOOL answer = NO;
	
	NSLog(@"%s: shouldSing: returning %@", dispatch_current_queue_label(), (answer ? @"YES" : @"NO"));
	
	return answer;
}

- (BOOL)shouldDance
{
	BOOL answer = YES;
	
	NSLog(@"%s: shouldDance: returning %@", dispatch_current_queue_label(), (answer ? @"YES" : @"NO"));
	
	return answer;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation DelegateTester2

- (void)didSomething
{
	NSLog(@"%s: didSomething", dispatch_current_queue_label());
}

- (void)didSomethingElse:(BOOL)flag
{
	NSLog(@"%s: didSomethingElse:%@", dispatch_current_queue_label(), (flag ? @"YES" : @"NO"));
}

- (void)foundString:(NSString *)str
{
	NSLog(@"%s: foundString:\"%@\"", dispatch_current_queue_label(), str);
}

- (void)foundString:(NSString *)str andNumber:(NSNumber *)num
{
	NSLog(@"%s: foundString:\"%@\" andNumber:%@", dispatch_current_queue_label(), str, num);
}

- (BOOL)shouldSing
{
	BOOL answer = NO;
	
	NSLog(@"%s: shouldSing: returning %@", dispatch_current_queue_label(), (answer ? @"YES" : @"NO"));
	
	return answer;
}

- (BOOL)shouldDance
{
	BOOL answer = YES;
	
	NSLog(@"%s: shouldDance: returning %@", dispatch_current_queue_label(), (answer ? @"YES" : @"NO"));
	
	return answer;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation DelegateTester3

- (void)didSomething
{
	NSLog(@"%s: didSomething", dispatch_current_queue_label());
}

- (void)didSomethingElse:(BOOL)flag
{
	NSLog(@"%s: didSomethingElse:%@", dispatch_current_queue_label(), (flag ? @"YES" : @"NO"));
}

- (void)foundString:(NSString *)str
{
	NSLog(@"%s: foundString:\"%@\"", dispatch_current_queue_label(), str);
}

- (void)foundString:(NSString *)str andNumber:(NSNumber *)num
{
	NSLog(@"%s: foundString:\"%@\" andNumber:%@", dispatch_current_queue_label(), str, num);
}

- (BOOL)shouldSing
{
	BOOL answer = YES;
	
	NSLog(@"%s: shouldSing: returning %@", dispatch_current_queue_label(), (answer ? @"YES" : @"NO"));
	
	return answer;
}

- (BOOL)shouldDance
{
	BOOL answer = NO;
	
	NSLog(@"%s: shouldDance: returning %@", dispatch_current_queue_label(), (answer ? @"YES" : @"NO"));
	
	return answer;
}

@end
