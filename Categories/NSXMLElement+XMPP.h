#import <Foundation/Foundation.h>

@import KissXML;

NS_ASSUME_NONNULL_BEGIN
@interface NSXMLElement (XMPP)

/**
 * Convenience methods for Creating elements.
**/

+ (NSXMLElement *)elementWithName:(NSString *)name numberValue:(NSNumber *)number;
- (instancetype)initWithName:(NSString *)name numberValue:(NSNumber *)number;

+ (NSXMLElement *)elementWithName:(NSString *)name objectValue:(id)objectValue;
- (instancetype)initWithName:(NSString *)name objectValue:(id)objectValue;

/**
 * Creating elements with explicit xmlns values.
 * 
 * Use these instead of [NSXMLElement initWithName:URI:].
 * The category methods below are more readable, and they actually work.
**/

+ (NSXMLElement *)elementWithName:(NSString *)name xmlns:(NSString *)ns;
- (instancetype)initWithName:(NSString *)name xmlns:(NSString *)ns;

/**
 * Extracting multiple elements.
**/

- (NSArray<NSXMLElement*> *)elementsForXmlns:(NSString *)ns;
- (NSArray<NSXMLElement*> *)elementsForXmlnsPrefix:(NSString *)nsPrefix;

/**
 * Extracting a single element.
**/

- (nullable NSXMLElement *)elementForName:(NSString *)name NS_REFINED_FOR_SWIFT;
- (nullable NSXMLElement *)elementForName:(NSString *)name xmlns:(NSString *)xmlns NS_REFINED_FOR_SWIFT;
- (nullable NSXMLElement *)elementForName:(NSString *)name xmlnsPrefix:(NSString *)xmlnsPrefix NS_SWIFT_NAME(element(forName:xmlnsPrefix:));

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

@property (nonatomic, readonly, nullable) NSString *xmlns;
- (void)setXmlns:(NSString *)ns;

/**
 * Convenience methods for printing xml elements with different styles.
**/

@property (nonatomic, readonly, nullable) NSString *prettyXMLString;
@property (nonatomic, readonly, nullable) NSString *compactXMLString;

/**
 * Convenience methods for adding attributes.
**/

- (void)addAttributeWithName:(NSString *)name intValue:(int)intValue;
- (void)addAttributeWithName:(NSString *)name boolValue:(BOOL)boolValue;
- (void)addAttributeWithName:(NSString *)name floatValue:(float)floatValue;
- (void)addAttributeWithName:(NSString *)name doubleValue:(double)doubleValue;
- (void)addAttributeWithName:(NSString *)name integerValue:(NSInteger)integerValue;
- (void)addAttributeWithName:(NSString *)name unsignedIntegerValue:(NSUInteger)unsignedIntegerValue;
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
- (nullable NSString *)attributeStringValueForName:(NSString *)name;
- (nullable NSNumber *)attributeNumberIntValueForName:(NSString *)name;
- (nullable NSNumber *)attributeNumberBoolValueForName:(NSString *)name;
- (nullable NSNumber *)attributeNumberFloatValueForName:(NSString *)name;
- (nullable NSNumber *)attributeNumberDoubleValueForName:(NSString *)name;
- (nullable NSNumber *)attributeNumberInt32ValueForName:(NSString *)name;
- (nullable NSNumber *)attributeNumberUInt32ValueForName:(NSString *)name;
- (nullable NSNumber *)attributeNumberInt64ValueForName:(NSString *)name;
- (nullable NSNumber *)attributeNumberUInt64ValueForName:(NSString *)name;
- (nullable NSNumber *)attributeNumberIntegerValueForName:(NSString *)name;
- (nullable NSNumber *)attributeNumberUnsignedIntegerValueForName:(NSString *)name;

- (int)attributeIntValueForName:(NSString *)name withDefaultValue:(int)defaultValue;
- (BOOL)attributeBoolValueForName:(NSString *)name withDefaultValue:(BOOL)defaultValue;
- (float)attributeFloatValueForName:(NSString *)name withDefaultValue:(float)defaultValue;
- (double)attributeDoubleValueForName:(NSString *)name withDefaultValue:(double)defaultValue;
- (int32_t)attributeInt32ValueForName:(NSString *)name withDefaultValue:(int32_t)defaultValue;
- (uint32_t)attributeUInt32ValueForName:(NSString *)name withDefaultValue:(uint32_t)defaultValue;
- (int64_t)attributeInt64ValueForName:(NSString *)name withDefaultValue:(int64_t)defaultValue;
- (uint64_t)attributeUInt64ValueForName:(NSString *)name withDefaultValue:(uint64_t)defaultValue;
- (NSInteger)attributeIntegerValueForName:(NSString *)name withDefaultValue:(NSInteger)defaultValue;
- (NSUInteger)attributeUnsignedIntegerValueForName:(NSString *)name withDefaultValue:(NSUInteger)defaultValue;
- (NSString *)attributeStringValueForName:(NSString *)name withDefaultValue:(NSString *)defaultValue;
- (NSNumber *)attributeNumberIntValueForName:(NSString *)name withDefaultValue:(int)defaultValue;
- (NSNumber *)attributeNumberBoolValueForName:(NSString *)name withDefaultValue:(BOOL)defaultValue;

@property (nonatomic, readonly) NSMutableDictionary<NSString*,NSString*> *attributesAsDictionary;

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

- (nullable NSString *)namespaceStringValueForPrefix:(NSString *)prefix;
- (NSString *)namespaceStringValueForPrefix:(NSString *)prefix withDefaultValue:(NSString *)defaultValue;

@end

NS_ASSUME_NONNULL_END
