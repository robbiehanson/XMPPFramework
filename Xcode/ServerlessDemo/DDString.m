#import "DDString.h"


@implementation NSString (DDString)

+ (id)stringWithUTF8Data:(NSData *)data
{
	return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

@end
