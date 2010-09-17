#import "Class1.h"


@implementation Class1

- (void)didSomething
{
	NSLog(@"Class1: didSomething");
}

- (void)didSomethingElse:(BOOL)flag
{
	NSLog(@"Class1: didSomethingElse:%@", (flag ? @"YES" : @"NO"));
}

- (void)foundString:(NSString *)str
{
	NSLog(@"Class1: foundString:\"%@\"", str);
}

- (void)foundString:(NSString *)str andNumber:(NSNumber *)num
{
	NSLog(@"Class1: foundString:\"%@\" andNumber:%@", str, num);
}

- (BOOL)shouldSing
{
	BOOL answer = NO;
	
	NSLog(@"Class1: shouldSing: returning %@", (answer ? @"YES" : @"NO"));
	
	return answer;
}

- (BOOL)shouldDance
{
	BOOL answer = YES;
	
	NSLog(@"Class1: shouldDance: returning %@", (answer ? @"YES" : @"NO"));
	
	return answer;
}

@end
