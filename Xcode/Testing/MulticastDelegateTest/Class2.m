#import "Class2.h"

#define dispatch_current_queue_label() dispatch_queue_get_label(dispatch_get_current_queue())

@implementation Class2

- (void)didSomething
{
	NSLog(@"Class2(%s): didSomething", dispatch_current_queue_label());
}

- (void)didSomethingElse:(BOOL)flag
{
	NSLog(@"Class2(%s): didSomethingElse:%@", dispatch_current_queue_label(), (flag ? @"YES" : @"NO"));
}

- (void)foundString:(NSString *)str
{
	NSLog(@"Class2(%s): foundString:\"%@\"", dispatch_current_queue_label(), str);
}

- (void)foundString:(NSString *)str andNumber:(NSNumber *)num
{
	NSLog(@"Class2(%s): foundString:\"%@\" andNumber:%@", dispatch_current_queue_label(), str, num);
}

- (BOOL)shouldSing
{
	BOOL answer = YES;
	
	NSLog(@"Class2(%s): shouldSing: returning %@", dispatch_current_queue_label(), (answer ? @"YES" : @"NO"));
	
	return answer;
}

- (BOOL)shouldDance
{
	BOOL answer = YES;
	
	NSLog(@"Class2(%s): shouldDance: returning %@", dispatch_current_queue_label(), (answer ? @"YES" : @"NO"));
	
	return answer;
}

@end
