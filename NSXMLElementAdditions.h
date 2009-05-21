#import <Foundation/Foundation.h>
#import "DDXML.h"

@interface NSXMLElement (XMPPStreamAdditions)

+ (NSXMLElement *)elementWithName:(NSString *)name xmlns:(NSString *)ns;

- (NSXMLElement *)elementForName:(NSString *)name;
- (NSXMLElement *)elementForName:(NSString *)name xmlns:(NSString *)xmlns;

- (NSString *)xmlns;
- (void)setXmlns:(NSString *)ns;

- (void)addAttributeWithName:(NSString *)name stringValue:(NSString *)string;
- (NSMutableDictionary *)attributesAsDictionary;

@end
