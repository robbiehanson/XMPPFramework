#import <Foundation/Foundation.h>
#import "DDXML.h"

@interface NSXMLElement (XMPPStreamAdditions)

+ (NSXMLElement *)elementWithName:(NSString *)name attribute:(NSString *)attribute stringValue:(NSString *)string;

- (NSXMLElement *)elementForName:(NSString *)name;
- (NSXMLElement *)elementForName:(NSString *)name xmlns:(NSString *)xmlns;
- (NSString *)xmlns;
- (void)addAttributeWithName:(NSString *)name stringValue:(NSString *)string;
- (NSDictionary *)attributesAsDictionary;

@end
