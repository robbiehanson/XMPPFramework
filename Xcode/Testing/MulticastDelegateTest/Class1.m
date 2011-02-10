#import "Class1.h"

#define dispatch_current_queue_label() dispatch_queue_get_label(dispatch_get_current_queue())

@implementation Class1

- (void)didSomething
{
	NSLog(@"Class1(%s): didSomething", dispatch_current_queue_label());
}

- (void)didSomethingElse:(BOOL)flag
{
	NSLog(@"Class1(%s): didSomethingElse:%@", dispatch_current_queue_label(), (flag ? @"YES" : @"NO"));
}

- (void)foundString:(NSString *)str
{
	NSLog(@"Class1(%s): foundString:\"%@\"", dispatch_current_queue_label(), str);
	
	[NSThread sleepForTimeInterval:0.2];
}

- (void)foundString:(NSString *)str andNumber:(NSNumber *)num
{
	NSLog(@"Class1(%s): foundString:\"%@\" andNumber:%@", dispatch_current_queue_label(), str, num);
}

- (BOOL)shouldSing
{
	BOOL answer = NO;
	
	NSLog(@"Class1(%s): shouldSing: returning %@", dispatch_current_queue_label(), (answer ? @"YES" : @"NO"));
	
	return answer;
}

- (BOOL)shouldDance
{
	BOOL answer = YES;
	
	NSLog(@"Class1(%s): shouldDance: returning %@", dispatch_current_queue_label(), (answer ? @"YES" : @"NO"));
	
	return answer;
}

@end
