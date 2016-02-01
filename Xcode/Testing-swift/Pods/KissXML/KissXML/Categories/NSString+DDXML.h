#import <Foundation/Foundation.h>

#if DDXML_LIBXML_MODULE_ENABLED
#if TARGET_OS_IOS && TARGET_OS_EMBEDDED
@import libxml;
#elif TARGET_IPHONE_SIMULATOR
@import libxmlSimu;
#elif TARGET_OS_MAC
@import libxmlMac;
#endif
#else
#import <libxml/tree.h>
#endif

@interface NSString (DDXML)

/**
 * xmlChar - A basic replacement for char, a byte in a UTF-8 encoded string.
**/
- (const xmlChar *)xmlChar;

- (NSString *)stringByTrimming;

@end
