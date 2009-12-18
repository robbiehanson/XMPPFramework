#import "Class2.h"


@implementation Class2

- (void)didSomething
{
	NSLog(@"Class2: didSomething");
}

- (void)didSomethingElse:(BOOL)flag
{
	NSLog(@"Class2: didSomethingElse:%@", (flag ? @"YES" : @"NO"));
}
/*
- (void)foundString:(NSString *)str
{
	NSLog(@"Class2: foundString:\"%@\"", str);
}

- (void)foundString:(NSString *)str andNumber:(NSNumber *)num
{
	NSLog(@"Class2: foundString:\"%@\" andNumber:%@", str, num);
}
*/
- (BOOL)shouldSing
{
	BOOL answer = YES;
	
	NSLog(@"Class2: shouldSing: returning %@", (answer ? @"YES" : @"NO"));
	
	return answer;
}

- (BOOL)shouldDance
{
	BOOL answer = YES;
	
	NSLog(@"Class2: shouldDance: returning %@", (answer ? @"YES" : @"NO"));
	
	return answer;
}

@end
