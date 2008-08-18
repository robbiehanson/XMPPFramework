#import <Foundation/Foundation.h>

@interface NSXMLElement (XMPPStreamAdditions)

- (NSXMLElement *)elementForName:(NSString *)name;
- (NSXMLElement *)elementForName:(NSString *)name xmlns:(NSString *)xmlns;
- (NSString *)xmlns;
- (NSDictionary *)attributesAsDictionary;

@end
