#import <Foundation/Foundation.h>

#if !(TARGET_IPHONE_SIMULATOR)
@import libxml;
#else
@import libxmlSimu;
#endif

@interface NSString (DDXML)

/**
 * xmlChar - A basic replacement for char, a byte in a UTF-8 encoded string.
**/
- (const xmlChar *)xmlChar;

- (NSString *)stringByTrimming;

@end
