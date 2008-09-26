#import "NSStringAdditions.h"


@implementation NSString (NSStringAdditions)

- (const xmlChar *)xmlChar
{
	return (const xmlChar *)[self UTF8String];
}

@end
