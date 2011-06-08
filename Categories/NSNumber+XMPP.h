#import <Foundation/Foundation.h>


@interface NSNumber (XMPP)

+ (NSNumber *)numberWithPtr:(const void *)ptr;
- (id)initWithPtr:(const void *)ptr;

+ (BOOL)parseString:(NSString *)str intoSInt64:(SInt64 *)pNum;
+ (BOOL)parseString:(NSString *)str intoUInt64:(UInt64 *)pNum;

+ (BOOL)parseString:(NSString *)str intoNSInteger:(NSInteger *)pNum;
+ (BOOL)parseString:(NSString *)str intoNSUInteger:(NSUInteger *)pNum;

+ (UInt8)extractUInt8FromData:(NSData *)data atOffset:(unsigned int)offset;

+ (UInt16)extractUInt16FromData:(NSData *)data atOffset:(unsigned int)offset andConvertFromNetworkOrder:(BOOL)flag;

+ (UInt32)extractUInt32FromData:(NSData *)data atOffset:(unsigned int)offset andConvertFromNetworkOrder:(BOOL)flag;

@end
