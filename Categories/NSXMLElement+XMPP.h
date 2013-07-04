#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
  #import "DDXML.h"
#endif


@interface NSXMLElement (XMPP)

/**
 * Creating elements with explicit xmlns values.
 * 
 * Use these instead of [NSXMLElement initWithName:URI:].
 * The category methods below are more readable, and they actually work.
**/

+ (NSXMLElement *)xmpp_elementWithName:(NSString *)name xmlns:(NSString *)ns;
- (id)xmpp_initWithName:(NSString *)name xmlns:(NSString *)ns __attribute__((objc_method_family(init)));

/**
 * Extracting multiple elements.
**/

- (NSArray *)xmpp_elementsForXmlns:(NSString *)ns;
- (NSArray *)xmpp_elementsForXmlnsPrefix:(NSString *)nsPrefix;

/**
 * Extracting a single element.
**/

- (NSXMLElement *)xmpp_elementForName:(NSString *)name;
- (NSXMLElement *)xmpp_elementForName:(NSString *)name xmlns:(NSString *)xmlns;
- (NSXMLElement *)xmpp_elementForName:(NSString *)name xmlnsPrefix:(NSString *)xmlnsPrefix;

/**
 * Working with the common xmpp xmlns value.
 * 
 * Use these instead of getting/setting the URI.
 * The category methods below are more readable, and they actually work.
**/

- (NSString *)xmpp_xmlns;
- (void)xmpp_setXmlns:(NSString *)ns;

/**
 * Convenience methods for printing xml elements with different styles.
**/

- (NSString *)xmpp_prettyXMLString;
- (NSString *)xmpp_compactXMLString;

/**
 * Convenience methods for adding attributes.
**/

- (void)xmpp_addAttributeWithName:(NSString *)name stringValue:(NSString *)string;

/**
 * Convenience methods for extracting attribute values in different formats.
 * 
 * E.g. <beer name="guinness" price="4.50"/> // float price = [beer attributeFloatValueForName:@"price"];
**/

- (int)xmpp_attributeIntValueForName:(NSString *)name;
- (BOOL)xmpp_attributeBoolValueForName:(NSString *)name;
- (float)xmpp_attributeFloatValueForName:(NSString *)name;
- (double)xmpp_attributeDoubleValueForName:(NSString *)name;
- (int32_t)xmpp_attributeInt32ValueForName:(NSString *)name;
- (uint32_t)xmpp_attributeUInt32ValueForName:(NSString *)name;
- (int64_t)xmpp_attributeInt64ValueForName:(NSString *)name;
- (uint64_t)xmpp_attributeUInt64ValueForName:(NSString *)name;
- (NSInteger)xmpp_attributeIntegerValueForName:(NSString *)name;
- (NSUInteger)xmpp_attributeUnsignedIntegerValueForName:(NSString *)name;
- (NSString *)xmpp_attributeStringValueForName:(NSString *)name;
- (NSNumber *)xmpp_attributeNumberIntValueForName:(NSString *)name;
- (NSNumber *)xmpp_attributeNumberBoolValueForName:(NSString *)name;
- (NSNumber *)xmpp_attributeNumberFloatValueForName:(NSString *)name;
- (NSNumber *)xmpp_attributeNumberDoubleValueForName:(NSString *)name;
- (NSNumber *)xmpp_attributeNumberInt32ValueForName:(NSString *)name;
- (NSNumber *)xmpp_attributeNumberUInt32ValueForName:(NSString *)name;
- (NSNumber *)xmpp_attributeNumberInt64ValueForName:(NSString *)name;
- (NSNumber *)xmpp_attributeNumberUInt64ValueForName:(NSString *)name;
- (NSNumber *)xmpp_attributeNumberIntegerValueForName:(NSString *)name;
- (NSNumber *)xmpp_attributeNumberUnsignedIntegerValueForName:(NSString *)name;

- (int)xmpp_attributeIntValueForName:(NSString *)name withDefaultValue:(int)defaultValue;
- (BOOL)xmpp_attributeBoolValueForName:(NSString *)name withDefaultValue:(BOOL)defaultValue;
- (float)xmpp_attributeFloatValueForName:(NSString *)name withDefaultValue:(float)defaultValue;
- (double)xmpp_attributeDoubleValueForName:(NSString *)name withDefaultValue:(double)defaultValue;
- (NSString *)xmpp_attributeStringValueForName:(NSString *)name withDefaultValue:(NSString *)defaultValue;
- (NSNumber *)xmpp_attributeNumberIntValueForName:(NSString *)name withDefaultValue:(int)defaultValue;
- (NSNumber *)xmpp_attributeNumberBoolValueForName:(NSString *)name withDefaultValue:(BOOL)defaultValue;

- (NSMutableDictionary *)xmpp_attributesAsDictionary;

/**
 * Convenience methods for extracting element values in different formats.
 * 
 * E.g. <price>9.99</price> // float price = [priceElement stringValueAsFloat];
**/

- (int)xmpp_stringValueAsInt;
- (BOOL)xmpp_stringValueAsBool;
- (float)xmpp_stringValueAsFloat;
- (double)xmpp_stringValueAsDouble;
- (int32_t)xmpp_stringValueAsInt32;
- (uint32_t)xmpp_stringValueAsUInt32;
- (int64_t)xmpp_stringValueAsInt64;
- (uint64_t)xmpp_stringValueAsUInt64;
- (NSInteger)xmpp_stringValueAsNSInteger;
- (NSUInteger)xmpp_stringValueAsNSUInteger;

/**
 * Working with namespaces.
**/

- (void)xmpp_addNamespaceWithPrefix:(NSString *)prefix stringValue:(NSString *)string;

- (NSString *)xmpp_namespaceStringValueForPrefix:(NSString *)prefix;
- (NSString *)xmpp_namespaceStringValueForPrefix:(NSString *)prefix withDefaultValue:(NSString *)defaultValue;

@end

#ifndef XMPP_EXCLUDE_DEPRECATED

#define XMPP_DEPRECATED($message) __attribute__((deprecated($message)))

@interface NSXMLElement (XMPPDeprecated)
+ (NSXMLElement *)elementWithName:(NSString *)name xmlns:(NSString *)ns XMPP_DEPRECATED("Use +xmpp_elementWithName:xmlns:");
- (id)initWithName:(NSString *)name xmlns:(NSString *)ns XMPP_DEPRECATED("Use -xmpp_initWithName:xmlns:");
- (NSArray *)elementsForXmlns:(NSString *)ns XMPP_DEPRECATED("Use -xmpp_elementsForXmlns:");
- (NSArray *)elementsForXmlnsPrefix:(NSString *)nsPrefix XMPP_DEPRECATED("Use -xmpp_elementsForXmlnsPrefix:");
- (NSXMLElement *)elementForName:(NSString *)name XMPP_DEPRECATED("Use -xmpp_elementForName:");
- (NSXMLElement *)elementForName:(NSString *)name xmlns:(NSString *)xmlns XMPP_DEPRECATED("Use -xmpp_elementForName:xmlns:");
- (NSXMLElement *)elementForName:(NSString *)name xmlnsPrefix:(NSString *)xmlnsPrefix XMPP_DEPRECATED("Use -xmpp_elementForName:xmlnsPrefix:");
- (NSString *)xmlns XMPP_DEPRECATED("Use -xmpp_xmlns");
- (void)setXmlns:(NSString *)ns XMPP_DEPRECATED("Use -xmpp_setXmlns:");
- (NSString *)prettyXMLString XMPP_DEPRECATED("Use -xmpp_prettyXMLString");
- (NSString *)compactXMLString XMPP_DEPRECATED("Use -xmpp_compactXMLString");
- (void)addAttributeWithName:(NSString *)name stringValue:(NSString *)string XMPP_DEPRECATED("Use -xmpp_addAttributeWithName:stringValue:");
- (int)attributeIntValueForName:(NSString *)name XMPP_DEPRECATED("Use -xmpp_attributeIntValueForName:");
- (BOOL)attributeBoolValueForName:(NSString *)name XMPP_DEPRECATED("Use -xmpp_attributeBoolValueForName:");
- (float)attributeFloatValueForName:(NSString *)name XMPP_DEPRECATED("Use -xmpp_attributeFloatValueForName:");
- (double)attributeDoubleValueForName:(NSString *)name XMPP_DEPRECATED("Use -xmpp_attributeDoubleValueForName:");
- (int32_t)attributeInt32ValueForName:(NSString *)name XMPP_DEPRECATED("Use -xmpp_attributeInt32ValueForName:");
- (uint32_t)attributeUInt32ValueForName:(NSString *)name XMPP_DEPRECATED("Use -xmpp_attributeUInt32ValueForName:");
- (int64_t)attributeInt64ValueForName:(NSString *)name XMPP_DEPRECATED("Use -xmpp_attributeInt64ValueForName:");
- (uint64_t)attributeUInt64ValueForName:(NSString *)name XMPP_DEPRECATED("Use -xmpp_attributeUInt64ValueForName:");
- (NSInteger)attributeIntegerValueForName:(NSString *)name XMPP_DEPRECATED("Use -xmpp_attributeIntegerValueForName:");
- (NSUInteger)attributeUnsignedIntegerValueForName:(NSString *)name XMPP_DEPRECATED("Use -xmpp_attributeUnsignedIntegerValueForName:");
- (NSString *)attributeStringValueForName:(NSString *)name XMPP_DEPRECATED("Use -xmpp_attributeStringValueForName:");
- (NSNumber *)attributeNumberIntValueForName:(NSString *)name XMPP_DEPRECATED("Use -xmpp_attributeNumberIntValueForName:");
- (NSNumber *)attributeNumberBoolValueForName:(NSString *)name XMPP_DEPRECATED("Use -xmpp_attributeNumberBoolValueForName:");
- (NSNumber *)attributeNumberFloatValueForName:(NSString *)name XMPP_DEPRECATED("Use -xmpp_attributeNumberFloatValueForName:");
- (NSNumber *)attributeNumberDoubleValueForName:(NSString *)name XMPP_DEPRECATED("Use -xmpp_attributeNumberDoubleValueForName:");
- (NSNumber *)attributeNumberInt32ValueForName:(NSString *)name XMPP_DEPRECATED("Use -xmpp_attributeNumberInt32ValueForName:");
- (NSNumber *)attributeNumberUInt32ValueForName:(NSString *)name XMPP_DEPRECATED("Use -xmpp_attributeNumberUInt32ValueForName:");
- (NSNumber *)attributeNumberInt64ValueForName:(NSString *)name XMPP_DEPRECATED("Use -xmpp_attributeNumberInt64ValueForName:");
- (NSNumber *)attributeNumberUInt64ValueForName:(NSString *)name XMPP_DEPRECATED("Use -xmpp_attributeNumberUInt64ValueForName:");
- (NSNumber *)attributeNumberIntegerValueForName:(NSString *)name XMPP_DEPRECATED("Use -xmpp_attributeNumberIntegerValueForName:");
- (NSNumber *)attributeNumberUnsignedIntegerValueForName:(NSString *)name XMPP_DEPRECATED("Use -xmpp_attributeNumberUnsignedIntegerValueForName:");
- (int)attributeIntValueForName:(NSString *)name withDefaultValue:(int)defaultValue XMPP_DEPRECATED("Use -xmpp_attributeIntValueForName:withDefaultValue:");
- (BOOL)attributeBoolValueForName:(NSString *)name withDefaultValue:(BOOL)defaultValue XMPP_DEPRECATED("Use -xmpp_attributeBoolValueForName:attributeBoolValueForName:withDefaultValue:");
- (float)attributeFloatValueForName:(NSString *)name withDefaultValue:(float)defaultValue XMPP_DEPRECATED("Use -xmpp_attributeFloatValueForName:withDefaultValue:");
- (double)attributeDoubleValueForName:(NSString *)name withDefaultValue:(double)defaultValue XMPP_DEPRECATED("Use -xmpp_attributeDoubleValueForName:withDefaultValue:");
- (NSString *)attributeStringValueForName:(NSString *)name withDefaultValue:(NSString *)defaultValue XMPP_DEPRECATED("Use -xmpp_attributeStringValueForName:withDefaultValue:");
- (NSNumber *)attributeNumberIntValueForName:(NSString *)name withDefaultValue:(int)defaultValue XMPP_DEPRECATED("Use -xmpp_attributeNumberIntValueForName:withDefaultValue:");
- (NSNumber *)attributeNumberBoolValueForName:(NSString *)name withDefaultValue:(BOOL)defaultValue XMPP_DEPRECATED("Use -xmpp_attributeNumberBoolValueForName:withDefaultValue:");
- (NSMutableDictionary *)attributesAsDictionary XMPP_DEPRECATED("Use -xmpp_attributesAsDictionary");
- (int)stringValueAsInt XMPP_DEPRECATED("Use -xmpp_stringValueAsInt");
- (BOOL)stringValueAsBool XMPP_DEPRECATED("Use -xmpp_stringValueAsBool");
- (float)stringValueAsFloat XMPP_DEPRECATED("Use -xmpp_stringValueAsFloat");
- (double)stringValueAsDouble XMPP_DEPRECATED("Use -xmpp_stringValueAsDouble");
- (int32_t)stringValueAsInt32 XMPP_DEPRECATED("Use -xmpp_stringValueAsInt32");
- (uint32_t)stringValueAsUInt32 XMPP_DEPRECATED("Use -xmpp_stringValueAsUInt32");
- (int64_t)stringValueAsInt64 XMPP_DEPRECATED("Use -xmpp_stringValueAsInt64");
- (uint64_t)stringValueAsUInt64 XMPP_DEPRECATED("Use -xmpp_stringValueAsUInt64");
- (NSInteger)stringValueAsNSInteger XMPP_DEPRECATED("Use -xmpp_stringValueAsNSInteger");
- (NSUInteger)stringValueAsNSUInteger XMPP_DEPRECATED("Use -xmpp_stringValueAsNSUInteger");
- (void)addNamespaceWithPrefix:(NSString *)prefix stringValue:(NSString *)string XMPP_DEPRECATED("Use -xmpp_addNamespaceWithPrefix:stringValue:");
- (NSString *)namespaceStringValueForPrefix:(NSString *)prefix XMPP_DEPRECATED("Use -xmpp_namespaceStringValueForPrefix:");
- (NSString *)namespaceStringValueForPrefix:(NSString *)prefix withDefaultValue:(NSString *)defaultValue XMPP_DEPRECATED("Use -xmpp_namespaceStringValueForPrefix:withDefaultValue:");
@end

#undef XMPP_DEPRECATED

#endif