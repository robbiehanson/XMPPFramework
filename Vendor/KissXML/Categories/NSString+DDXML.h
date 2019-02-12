#import <Foundation/Foundation.h>
#import <libxml/tree.h>


// We redefine xmlChar to avoid a non-modular include
typedef unsigned char xmlChar;


NS_ASSUME_NONNULL_BEGIN
@interface NSString (DDXML)    @interface NSString (DDXML)


/**    /**
 * xmlChar - A basic replacement for char, a byte in a UTF-8 encoded string.     * xmlChar - A basic replacement for char, a byte in a UTF-8 encoded string.
 **/    **/
- (const xmlChar *)xmlChar;    - (const xmlChar *)xmlChar;
- (NSString *)stringByTrimming;    - (NSString *)stringByTrimming;


@end    @end
NS_ASSUME_NONNULL_END 
