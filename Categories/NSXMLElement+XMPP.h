#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
  #import "DDXML.h"
#endif


@interface NSXMLElement (XMPP)

/**
 * Convenience methods for Creating elements.
**/

+ (NSXMLElement *)elementWithName:(NSString *)name numberValue:(NSNumber *)number;
- (id)initWithName:(NSString *)name numberValue:(NSNumber *)number;

+ (NSXMLElement *)elementWithName:(NSString *)name objectValue:(id)objectValue;
- (id)initWithName:(NSString *)name objectValue:(id)objectValue;

/**
 * Creating elements with explicit xmlns values.
 * 
 * Use these instead of [NSXMLElement initWithName:URI:].
 * The category methods below are more readable, and they actually work.
**/

+ (NSXMLElement *)elementWithName:(NSString *)name xmlns:(NSString *)ns;
- (id)initWithName:(NSString *)name xmlns:(NSString *)ns;

/**
 * Extracting multiple elements.
**/

- (NSArray *)elementsForXmlns:(NSString *)ns;
- (NSArray *)elementsForXmlnsPrefix:(NSString *)nsPrefix;

/**
 * Extracting a single element.
**/

- (NSXMLElement *)elementForName:(NSString *)name;
- (NSXMLElement *)elementForName:(NSString *)name xmlns:(NSString *)xmlns;
- (NSXMLElement *)elementForName:(NSString *)name xmlnsPrefix:(NSString *)xmlnsPrefix;

/**
 * Convenience methods for removing child elements.
 *
 * If the element doesn't exist, these methods do nothing.
**/

- (void)removeElementForName:(NSString *)name;
- (void)removeElementsForName:(NSString *)name;
- (void)removeElementForName:(NSString *)name xmlns:(NSString *)xmlns;
- (void)removeElementForName:(NSString *)name xmlnsPrefix:(NSString *)xmlnsPrefix;

/**
 * Working with the common xmpp xmlns value.
 * 
 * Use these instead of getting/setting the URI.
 * The category methods below are more readable, and they actually work.
**/

- (NSString *)xmlns;
- (void)setXmlns:(NSString *)ns;

/**
 * Convenience methods for printing xml elements with different styles.
**/

- (NSString *)prettyXMLString;
- (NSString *)compactXMLString;

/**
 * Convenience methods for adding attributes.
**/

- (void)addAttributeWithName:(NSString *)name intValue:(int)intValue;
- (void)addAttributeWithName:(NSString *)name boolValue:(BOOL)boolValue;
- (void)addAttributeWithName:(NSString *)name floatValue:(float)floatValue;
- (void)addAttributeWithName:(NSString *)name doubleValue:(double)doubleValue;
- (void)addAttributeWithName:(NSString *)name integerValue:(NSInteger)integerValue;
- (void)addAttributeWithName:(NSString *)name unsignedIntegerValue:(NSInteger)unsignedIntegerValue;
- (void)addAttributeWithName:(NSString *)name stringValue:(NSString *)string;
- (void)addAttributeWithName:(NSString *)name numberValue:(NSNumber *)number;
- (void)addAttributeWithName:(NSString *)name objectValue:(id)objectValue;

/**
 * Convenience methods for extracting attribute values in different formats.
 * 
 * E.g. <beer name="guinness" price="4.50"/> // float price = [beer attributeFloatValueForName:@"price"];
**/

- (int)attributeIntValueForName:(NSString *)name;
- (BOOL)attributeBoolValueForName:(NSString *)name;
- (float)attributeFloatValueForName:(NSString *)name;
- (double)attributeDoubleValueForName:(NSString *)name;
- (int32_t)attributeInt32ValueForName:(NSString *)name;
- (uint32_t)attributeUInt32ValueForName:(NSString *)name;
- (int64_t)attributeInt64ValueForName:(NSString *)name;
- (uint64_t)attributeUInt64ValueForName:(NSString *)name;
- (NSInteger)attributeIntegerValueForName:(NSString *)name;
- (NSUInteger)attributeUnsignedIntegerValueForName:(NSString *)name;
- (NSString *)attributeStringValueForName:(NSString *)name;
- (NSNumber *)attributeNumberIntValueForName:(NSString *)name;
- (NSNumber *)attributeNumberBoolValueForName:(NSString *)name;
- (NSNumber *)attributeNumberFloatValueForName:(NSString *)name;
- (NSNumber *)attributeNumberDoubleValueForName:(NSString *)name;
- (NSNumber *)attributeNumberInt32ValueForName:(NSString *)name;
- (NSNumber *)attributeNumberUInt32ValueForName:(NSString *)name;
- (NSNumber *)attributeNumberInt64ValueForName:(NSString *)name;
- (NSNumber *)attributeNumberUInt64ValueForName:(NSString *)name;
- (NSNumber *)attributeNumberIntegerValueForName:(NSString *)name;
- (NSNumber *)attributeNumberUnsignedIntegerValueForName:(NSString *)name;

- (int)attributeIntValueForName:(NSString *)name withDefaultValue:(int)defaultValue;
- (BOOL)attributeBoolValueForName:(NSString *)name withDefaultValue:(BOOL)defaultValue;
- (float)attributeFloatValueForName:(NSString *)name withDefaultValue:(float)defaultValue;
- (double)attributeDoubleValueForName:(NSString *)name withDefaultValue:(double)defaultValue;
- (NSString *)attributeStringValueForName:(NSString *)name withDefaultValue:(NSString *)defaultValue;
- (NSNumber *)attributeNumberIntValueForName:(NSString *)name withDefaultValue:(int)defaultValue;
- (NSNumber *)attributeNumberBoolValueForName:(NSString *)name withDefaultValue:(BOOL)defaultValue;

- (NSMutableDictionary *)attributesAsDictionary;

/**
 * Convenience methods for extracting element values in different formats.
 * 
 * E.g. <price>9.99</price> // float price = [priceElement stringValueAsFloat];
**/

- (int)stringValueAsInt;
- (BOOL)stringValueAsBool;
- (float)stringValueAsFloat;
- (double)stringValueAsDouble;
- (int32_t)stringValueAsInt32;
- (uint32_t)stringValueAsUInt32;
- (int64_t)stringValueAsInt64;
- (uint64_t)stringValueAsUInt64;
- (NSInteger)stringValueAsNSInteger;
- (NSUInteger)stringValueAsNSUInteger;

/**
 * Working with namespaces.
**/

- (void)addNamespaceWithPrefix:(NSString *)prefix stringValue:(NSString *)string;

- (NSString *)namespaceStringValueForPrefix:(NSString *)prefix;
- (NSString *)namespaceStringValueForPrefix:(NSString *)prefix withDefaultValue:(NSString *)defaultValue;

@end
