#import <Foundation/Foundation.h>
#import "DDXML.h"

@interface NSXMLElement (XMPPStreamAdditions)

+ (NSXMLElement *)elementWithName:(NSString *)name xmlns:(NSString *)ns;

- (NSXMLElement *)elementForName:(NSString *)name;
- (NSXMLElement *)elementForName:(NSString *)name xmlns:(NSString *)xmlns;

- (NSString *)xmlns;
- (void)setXmlns:(NSString *)ns;

- (void)addAttributeWithName:(NSString *)name stringValue:(NSString *)string;

- (int)attributeIntValueForName:(NSString *)name;
- (BOOL)attributeBoolValueForName:(NSString *)name;
- (float)attributeFloatValueForName:(NSString *)name;
- (double)attributeDoubleValueForName:(NSString *)name;
- (NSString *)attributeStringValueForName:(NSString *)name;

- (int)attributeIntValueForName:(NSString *)name withDefaultValue:(int)defaultValue;
- (BOOL)attributeBoolValueForName:(NSString *)name withDefaultValue:(BOOL)defaultValue;
- (float)attributeFloatValueForName:(NSString *)name withDefaultValue:(float)defaultValue;
- (double)attributeDoubleValueForName:(NSString *)name withDefaultValue:(double)defaultValue;
- (NSString *)attributeStringValueForName:(NSString *)name withDefaultValue:(NSString *)defaultValue;

- (NSMutableDictionary *)attributesAsDictionary;

@end
