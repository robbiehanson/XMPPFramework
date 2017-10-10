#import "NSNumber+XMPP.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif


@implementation NSNumber (XMPP)

+ (NSNumber *)xmpp_numberWithPtr:(const void *)ptr
{
	return [[NSNumber alloc] xmpp_initWithPtr:ptr];
}

- (instancetype)xmpp_initWithPtr:(const void *)ptr
{
	return [self initWithLong:(long)ptr];
}

+ (BOOL)xmpp_parseString:(NSString *)str intoInt32:(int32_t *)pNum
{
	if (str == nil)
	{
		*pNum = (int32_t)0;
		return NO;
	}
	
	errno = 0;
	
	long result = strtol([str UTF8String], NULL, 10);
	
	if (LONG_BIT != 32)
	{
		if (result > INT32_MAX)
		{
			*pNum = INT32_MAX;
			return NO;
		}
		if (result < INT32_MIN)
		{
			*pNum = INT32_MIN;
			return NO;
		}
	}
	
	// From the manpage:
	// 
	// If no conversion could be performed, 0 is returned and the global variable errno is set to EINVAL.
	// If an overflow or underflow occurs, errno is set to ERANGE and the function return value is clamped.
	// 
	// Clamped means it will be TYPE_MAX or TYPE_MIN.
	// If overflow/underflow occurs, returning a clamped value is more accurate then returning zero.
	
	*pNum = (int32_t)result;
	
	if (errno != 0)
		return NO;
	else
		return YES;
}

+ (BOOL)xmpp_parseString:(NSString *)str intoUInt32:(uint32_t *)pNum
{
	if (str == nil)
	{
		*pNum = (uint32_t)0;
		return NO;
	}
	
	errno = 0;
	
	unsigned long result = strtoul([str UTF8String], NULL, 10);
	
	if (LONG_BIT != 32)
	{
		if (result > UINT32_MAX)
		{
			*pNum = UINT32_MAX;
			return NO;
		}
	}
	
	// From the manpage:
	// 
	// If no conversion could be performed, 0 is returned and the global variable errno is set to EINVAL.
	// If an overflow or underflow occurs, errno is set to ERANGE and the function return value is clamped.
	// 
	// Clamped means it will be TYPE_MAX or TYPE_MIN.
	// If overflow/underflow occurs, returning a clamped value is more accurate then returning zero.
	
	*pNum = (uint32_t)result;
	
	if (errno != 0)
		return NO;
	else
		return YES;
}

+ (BOOL)xmpp_parseString:(NSString *)str intoInt64:(int64_t *)pNum
{
	if (str == nil)
	{
		*pNum = (int64_t)0;
		return NO;
	}
	
	errno = 0;
	
	// On both 32-bit and 64-bit machines, long long = 64 bit
	
	*pNum = strtoll([str UTF8String], NULL, 10);
	
	// From the manpage:
	// 
	// If no conversion could be performed, 0 is returned and the global variable errno is set to EINVAL.
	// If an overflow or underflow occurs, errno is set to ERANGE and the function return value is clamped.
	// 
	// Clamped means it will be TYPE_MAX or TYPE_MIN.
	// If overflow/underflow occurs, returning a clamped value is more accurate then returning zero.
	
	if (errno != 0)
		return NO;
	else
		return YES;
}

+ (BOOL)xmpp_parseString:(NSString *)str intoUInt64:(uint64_t *)pNum
{
	if (str == nil)
	{
		*pNum = (uint64_t)0;
		return NO;
	}
	
	errno = 0;
	
	// On both 32-bit and 64-bit machines, unsigned long long = 64 bit
	
	*pNum = strtoull([str UTF8String], NULL, 10);
	
	// From the manpage:
	// 
	// If no conversion could be performed, 0 is returned and the global variable errno is set to EINVAL.
	// If an overflow or underflow occurs, errno is set to ERANGE and the function return value is clamped.
	// 
	// Clamped means it will be TYPE_MAX or TYPE_MIN.
	// If overflow/underflow occurs, returning a clamped value is more accurate then returning zero.
	
	if (errno != 0)
		return NO;
	else
		return YES;
}

+ (BOOL)xmpp_parseString:(NSString *)str intoNSInteger:(NSInteger *)pNum
{
	if (NSIntegerMax == INT32_MAX)
		return [self xmpp_parseString:str intoInt32:(int32_t *)pNum];
	else
		return [self xmpp_parseString:str intoInt64:(int64_t *)pNum];
}

+ (BOOL)xmpp_parseString:(NSString *)str intoNSUInteger:(NSUInteger *)pNum
{
	if (NSUIntegerMax == UINT32_MAX)
		return [self xmpp_parseString:str intoUInt32:(uint32_t *)pNum];
	else
		return [self xmpp_parseString:str intoUInt64:(uint64_t *)pNum];
}

+ (UInt8)xmpp_extractUInt8FromData:(NSData *)data atOffset:(unsigned int)offset
{
	// 8 bits = 1 byte
	
	if([data length] < offset + 1) return 0;
	
	UInt8 *pResult = (UInt8 *)([data bytes] + offset);
	UInt8 result = *pResult;
	
	return result;
}

+ (UInt16)xmpp_extractUInt16FromData:(NSData *)data atOffset:(unsigned int)offset andConvertFromNetworkOrder:(BOOL)flag
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

+ (UInt32)xmpp_extractUInt32FromData:(NSData *)data atOffset:(unsigned int)offset andConvertFromNetworkOrder:(BOOL)flag
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

#ifndef XMPP_EXCLUDE_DEPRECATED

@implementation NSNumber (XMPPDeprecated)

+ (NSNumber *)numberWithPtr:(const void *)ptr {
    return [self xmpp_numberWithPtr:ptr];
}

- (id)initWithPtr:(const void *)ptr {
    return [self xmpp_initWithPtr:ptr];
}

+ (BOOL)parseString:(NSString *)str intoInt32:(int32_t *)pNum {
    return [self xmpp_parseString:str intoInt32:pNum];
}

+ (BOOL)parseString:(NSString *)str intoUInt32:(uint32_t *)pNum {
    return [self xmpp_parseString:str intoUInt32:pNum];
}

+ (BOOL)parseString:(NSString *)str intoInt64:(int64_t *)pNum {
    return [self xmpp_parseString:str intoInt64:pNum];
}

+ (BOOL)parseString:(NSString *)str intoUInt64:(uint64_t *)pNum {
    return [self xmpp_parseString:str intoUInt64:pNum];
}

+ (BOOL)parseString:(NSString *)str intoNSInteger:(NSInteger *)pNum {
    return [self xmpp_parseString:str intoNSInteger:pNum];
}

+ (BOOL)parseString:(NSString *)str intoNSUInteger:(NSUInteger *)pNum {
    return [self xmpp_parseString:str intoNSUInteger:pNum];
}

+ (UInt8)extractUInt8FromData:(NSData *)data atOffset:(unsigned int)offset {
    return [self xmpp_extractUInt8FromData:data atOffset:offset];
}

+ (UInt16)extractUInt16FromData:(NSData *)data atOffset:(unsigned int)offset andConvertFromNetworkOrder:(BOOL)flag {
    return [self xmpp_extractUInt16FromData:data atOffset:offset andConvertFromNetworkOrder:flag];
}

+ (UInt32)extractUInt32FromData:(NSData *)data atOffset:(unsigned int)offset andConvertFromNetworkOrder:(BOOL)flag {
    return [self xmpp_extractUInt32FromData:data atOffset:offset andConvertFromNetworkOrder:flag];
}

@end

#endif
