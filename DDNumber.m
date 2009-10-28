#import "DDNumber.h"


@implementation NSNumber (DDNumber)

+ (BOOL)parseString:(NSString *)str intoSInt64:(SInt64 *)pNum
{
	if(str == nil)
	{
		*pNum = 0;
		return NO;
	}
	
	errno = 0;
	
	// On both 32-bit and 64-bit machines, long long = 64 bit
	
	*pNum = strtoll([str UTF8String], NULL, 10);
	
	if(errno != 0)
		return NO;
	else
		return YES;
}

+ (BOOL)parseString:(NSString *)str intoUInt64:(UInt64 *)pNum
{
	if(str == nil)
	{
		*pNum = 0;
		return NO;
	}
	
	errno = 0;
	
	// On both 32-bit and 64-bit machines, unsigned long long = 64 bit
	
	*pNum = strtoull([str UTF8String], NULL, 10);
	
	if(errno != 0)
		return NO;
	else
		return YES;
}

+ (BOOL)parseString:(NSString *)str intoNSInteger:(NSInteger *)pNum
{
	if(str == nil)
	{
		*pNum = 0;
		return NO;
	}
	
	errno = 0;
	
	// On LP64, NSInteger = long = 64 bit
	// Otherwise, NSInteger = int = long = 32 bit
	
	*pNum = strtol([str UTF8String], NULL, 10);
	
	if(errno != 0)
		return NO;
	else
		return YES;
}

+ (BOOL)parseString:(NSString *)str intoNSUInteger:(NSUInteger *)pNum
{
	if(str == nil)
	{
		*pNum = 0;
		return NO;
	}
	
	errno = 0;
	
	// On LP64, NSUInteger = unsigned long = 64 bit
	// Otherwise, NSUInteger = unsigned int = unsigned long = 32 bit
	
	*pNum = strtoul([str UTF8String], NULL, 10);
	
	if(errno != 0)
		return NO;
	else
		return YES;
}

+ (UInt8)extractUInt8FromData:(NSData *)data atOffset:(unsigned int)offset
{
	// 8 bits = 1 byte
	
	if([data length] < offset + 1) return 0;
	
	UInt8 *pResult = (UInt8 *)([data bytes] + offset);
	UInt8 result = *pResult;
	
	return result;
}

+ (UInt16)extractUInt16FromData:(NSData *)data atOffset:(unsigned int)offset andConvertFromNetworkOrder:(BOOL)flag
{
	// 16 bits = 2 bytes
	
	if([data length] < offset + 2) return 0;
	
	UInt16 *pResult = (UInt16 *)([data bytes] + offset);
	UInt16 result = *pResult;
	
	if(flag)
		return ntohs(result);
	else
		return result;
}

+ (UInt32)extractUInt32FromData:(NSData *)data atOffset:(unsigned int)offset andConvertFromNetworkOrder:(BOOL)flag
{
	// 32 bits = 4 bytes
	
	if([data length] < offset + 4) return 0;
	
	UInt32 *pResult = (UInt32 *)([data bytes] + offset);
	UInt32 result = *pResult;
	
	if(flag)
		return ntohl(result);
	else
		return result;
}

@end
