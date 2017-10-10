#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface NSNumber (XMPP)

+ (NSNumber *)xmpp_numberWithPtr:(const void *)ptr;
- (instancetype)xmpp_initWithPtr:(const void *)ptr __attribute__((objc_method_family(init)));

+ (BOOL)xmpp_parseString:(NSString *)str intoInt32:(int32_t *)pNum;
+ (BOOL)xmpp_parseString:(NSString *)str intoUInt32:(uint32_t *)pNum;

+ (BOOL)xmpp_parseString:(NSString *)str intoInt64:(int64_t *)pNum;
+ (BOOL)xmpp_parseString:(NSString *)str intoUInt64:(uint64_t *)pNum;

+ (BOOL)xmpp_parseString:(NSString *)str intoNSInteger:(NSInteger *)pNum;
+ (BOOL)xmpp_parseString:(NSString *)str intoNSUInteger:(NSUInteger *)pNum;

+ (UInt8)xmpp_extractUInt8FromData:(NSData *)data atOffset:(unsigned int)offset;

+ (UInt16)xmpp_extractUInt16FromData:(NSData *)data atOffset:(unsigned int)offset andConvertFromNetworkOrder:(BOOL)flag;

+ (UInt32)xmpp_extractUInt32FromData:(NSData *)data atOffset:(unsigned int)offset andConvertFromNetworkOrder:(BOOL)flag;

@end

#ifndef XMPP_EXCLUDE_DEPRECATED

#define XMPP_DEPRECATED($message) __attribute__((deprecated($message)))

@interface NSNumber (XMPPDeprecated)
+ (NSNumber *)numberWithPtr:(const void *)ptr XMPP_DEPRECATED("Use +xmpp_numberWithPtr:");
- (id)initWithPtr:(const void *)ptr XMPP_DEPRECATED("Use -xmpp_initWithPtr:");
+ (BOOL)parseString:(NSString *)str intoInt32:(int32_t *)pNum XMPP_DEPRECATED("Use +xmpp_parseString:intoInt32:");
+ (BOOL)parseString:(NSString *)str intoUInt32:(uint32_t *)pNum XMPP_DEPRECATED("Use +xmpp_parseString:intoUInt32:");
+ (BOOL)parseString:(NSString *)str intoInt64:(int64_t *)pNum XMPP_DEPRECATED("Use +xmpp_parseString:intoInt64:");
+ (BOOL)parseString:(NSString *)str intoUInt64:(uint64_t *)pNum XMPP_DEPRECATED("Use +xmpp_parseString:intoUInt64:");
+ (BOOL)parseString:(NSString *)str intoNSInteger:(NSInteger *)pNum XMPP_DEPRECATED("Use +xmpp_parseString:intoNSInteger:");
+ (BOOL)parseString:(NSString *)str intoNSUInteger:(NSUInteger *)pNum XMPP_DEPRECATED("Use +xmpp_parseString:intoNSUInteger:");
+ (UInt8)extractUInt8FromData:(NSData *)data atOffset:(unsigned int)offset XMPP_DEPRECATED("Use +xmpp_extractUInt8FromData:atOffset:");
+ (UInt16)extractUInt16FromData:(NSData *)data atOffset:(unsigned int)offset andConvertFromNetworkOrder:(BOOL)flag XMPP_DEPRECATED("Use +xmpp_extractUInt16FromData:atOffset:andConvertFromNetworkOrder:");
+ (UInt32)extractUInt32FromData:(NSData *)data atOffset:(unsigned int)offset andConvertFromNetworkOrder:(BOOL)flag XMPP_DEPRECATED("Use +xmpp_extractUInt32FromData:atOffset:andConvertFromNetworkOrder:");
@end

#undef XMPP_DEPRECATED

#endif
NS_ASSUME_NONNULL_END
