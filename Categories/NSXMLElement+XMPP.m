#import "NSXMLElement+XMPP.h"
#import "NSNumber+XMPP.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

@implementation NSXMLElement (XMPP)

/**
 * Quick method to create an element
**/
+ (NSXMLElement *)xmpp_elementWithName:(NSString *)name xmlns:(NSString *)ns
{
	NSXMLElement *element = [NSXMLElement elementWithName:name];
	[element xmpp_setXmlns:ns];
	return element;
}

- (id)xmpp_initWithName:(NSString *)name xmlns:(NSString *)ns
{
	if ((self = [self initWithName:name]))
	{
		[self xmpp_setXmlns:ns];
	}
	return self;
}

- (NSArray *)xmpp_elementsForXmlns:(NSString *)ns
{
	NSMutableArray *elements = [NSMutableArray array];
	
	for (NSXMLNode *node in [self children])
	{
		if ([node isKindOfClass:[NSXMLElement class]])
		{
			NSXMLElement *element = (NSXMLElement *)node;
			
			if ([[element xmpp_xmlns] isEqual:ns])
			{
				[elements addObject:element];
			}
		}
	}
	
	return elements;
}

- (NSArray *)xmpp_elementsForXmlnsPrefix:(NSString *)nsPrefix
{
    NSMutableArray *elements = [NSMutableArray array];
	
	for (NSXMLNode *node in [self children])
	{
		if ([node isKindOfClass:[NSXMLElement class]])
		{
			NSXMLElement *element = (NSXMLElement *)node;
			
			if ([[element xmpp_xmlns] hasPrefix:nsPrefix])
			{
				[elements addObject:element];
			}
		}
	}
	
	return elements;
}

/**
 * This method returns the first child element for the given name (as an NSXMLElement).
 * If no child elements exist for the given name, nil is returned.
**/
- (NSXMLElement *)xmpp_elementForName:(NSString *)name
{
	NSArray *elements = [self elementsForName:name];
	if ([elements count] > 0)
	{
		return [elements objectAtIndex:0];
	}
	else
	{
		// There is a bug in the NSXMLElement elementsForName: method.
		// Consider the following XML fragment:
		// 
		// <query xmlns="jabber:iq:private">
		//   <x xmlns="some:other:namespace"></x>
		// </query>
		// 
		// Calling [query elementsForName:@"x"] results in an empty array!
		// 
		// However, it will work properly if you use the following:
		// [query elementsForLocalName:@"x" URI:@"some:other:namespace"]
		// 
		// The trouble with this is that we may not always know the xmlns in advance,
		// so in this particular case there is no way to access the element without looping through the children.
		// 
		// This bug was submitted to apple on June 1st, 2007 and was classified as "serious".
		// 
		// --!!-- This bug does NOT exist in DDXML --!!--
		
		return nil;
	}
}

/**
 * This method returns the first child element for the given name and given xmlns (as an NSXMLElement).
 * If no child elements exist for the given name and given xmlns, nil is returned.
**/
- (NSXMLElement *)xmpp_elementForName:(NSString *)name xmlns:(NSString *)xmlns
{
	NSArray *elements = [self elementsForLocalName:name URI:xmlns];
	if ([elements count] > 0)
	{
		return [elements objectAtIndex:0];
	}
	else
	{
		return nil;
	}
}

- (NSXMLElement *)xmpp_elementForName:(NSString *)name xmlnsPrefix:(NSString *)xmlnsPrefix{
    
    NSXMLElement *result = nil;
	
	for (NSXMLNode *node in [self children])
	{
		if ([node isKindOfClass:[NSXMLElement class]])
		{
			NSXMLElement *element = (NSXMLElement *)node;
			
			if ([[element name] isEqualToString:name] && [[element xmpp_xmlns] hasPrefix:xmlnsPrefix])
			{
				result = element;
                break;
			}
		}
	}
	
	return result;
}

/**
 * Returns the common xmlns "attribute", which is only accessible via the namespace methods.
 * The xmlns value is often used in jabber elements.
**/
- (NSString *)xmpp_xmlns
{
	return [[self namespaceForPrefix:@""] stringValue];
}

- (void)xmpp_setXmlns:(NSString *)ns
{
	// If we use setURI: then the xmlns won't be displayed in the XMLString.
	// Adding the namespace this way works properly.
	
	[self addNamespace:[NSXMLNode namespaceWithName:@"" stringValue:ns]];
}

/**
 * Shortcut to get a pretty (formatted) string representation of the element.
**/
- (NSString *)xmpp_prettyXMLString
{
	return [self XMLStringWithOptions:(NSXMLNodePrettyPrint | NSXMLNodeCompactEmptyElement)];
}

/**
 * Shortcut to get a compact string representation of the element.
**/
- (NSString *)xmpp_compactXMLString
{
    return [self XMLStringWithOptions:NSXMLNodeCompactEmptyElement];
}

/**
 *	Shortcut to avoid having to use NSXMLNode everytime
**/
- (void)xmpp_addAttributeWithName:(NSString *)name stringValue:(NSString *)string
{
	[self addAttribute:[NSXMLNode attributeWithName:name stringValue:string]];
}

/**
 * The following methods return the corresponding value of the attribute with the given name.
**/

- (int)xmpp_attributeIntValueForName:(NSString *)name
{
	return [[self xmpp_attributeStringValueForName:name] intValue];
}
- (BOOL)xmpp_attributeBoolValueForName:(NSString *)name
{
	return [[self xmpp_attributeStringValueForName:name] boolValue];
}
- (float)xmpp_attributeFloatValueForName:(NSString *)name
{
	return [[self xmpp_attributeStringValueForName:name] floatValue];
}
- (double)xmpp_attributeDoubleValueForName:(NSString *)name
{
	return [[self xmpp_attributeStringValueForName:name] doubleValue];
}
- (int32_t)xmpp_attributeInt32ValueForName:(NSString *)name
{
	int32_t result = 0;
	[NSNumber xmpp_parseString:[self xmpp_attributeStringValueForName:name] intoInt32:&result];
	return result;
}
- (uint32_t)xmpp_attributeUInt32ValueForName:(NSString *)name
{
	uint32_t result = 0;
	[NSNumber xmpp_parseString:[self xmpp_attributeStringValueForName:name] intoUInt32:&result];
	return result;
}
- (int64_t)xmpp_attributeInt64ValueForName:(NSString *)name
{
	int64_t result;
	[NSNumber xmpp_parseString:[self xmpp_attributeStringValueForName:name] intoInt64:&result];
	return result;
}
- (uint64_t)xmpp_attributeUInt64ValueForName:(NSString *)name
{
	uint64_t result;
	[NSNumber xmpp_parseString:[self xmpp_attributeStringValueForName:name] intoUInt64:&result];
	return result;
}
- (NSInteger)xmpp_attributeIntegerValueForName:(NSString *)name
{
	NSInteger result;
	[NSNumber xmpp_parseString:[self xmpp_attributeStringValueForName:name] intoNSInteger:&result];
	return result;
}
- (NSUInteger)xmpp_attributeUnsignedIntegerValueForName:(NSString *)name
{
	NSUInteger result = 0;
	[NSNumber xmpp_parseString:[self xmpp_attributeStringValueForName:name] intoNSUInteger:&result];
	return result;
}
- (NSString *)xmpp_attributeStringValueForName:(NSString *)name
{
	return [[self attributeForName:name] stringValue];
}
- (NSNumber *)xmpp_attributeNumberIntValueForName:(NSString *)name
{
	return [NSNumber numberWithInt:[self xmpp_attributeIntValueForName:name]];
}
- (NSNumber *)xmpp_attributeNumberBoolValueForName:(NSString *)name
{
	return [NSNumber numberWithBool:[self xmpp_attributeBoolValueForName:name]];
}
- (NSNumber *)xmpp_attributeNumberFloatValueForName:(NSString *)name
{
	return [NSNumber numberWithFloat:[self xmpp_attributeFloatValueForName:name]];
}
- (NSNumber *)xmpp_attributeNumberDoubleValueForName:(NSString *)name
{
	return [NSNumber numberWithDouble:[self xmpp_attributeDoubleValueForName:name]];
}
- (NSNumber *)xmpp_attributeNumberInt32ValueForName:(NSString *)name
{
	return [NSNumber numberWithInt:[self xmpp_attributeInt32ValueForName:name]];
}
- (NSNumber *)xmpp_attributeNumberUInt32ValueForName:(NSString *)name
{
	return [NSNumber numberWithUnsignedInt:[self xmpp_attributeUInt32ValueForName:name]];
}
- (NSNumber *)xmpp_attributeNumberInt64ValueForName:(NSString *)name
{
	return [NSNumber numberWithLongLong:[self xmpp_attributeInt64ValueForName:name]];
}
- (NSNumber *)xmpp_attributeNumberUInt64ValueForName:(NSString *)name
{
	return [NSNumber numberWithUnsignedLongLong:[self xmpp_attributeUInt64ValueForName:name]];
}
- (NSNumber *)xmpp_attributeNumberIntegerValueForName:(NSString *)name
{
	return [NSNumber numberWithInteger:[self xmpp_attributeIntegerValueForName:name]];
}
- (NSNumber *)xmpp_attributeNumberUnsignedIntegerValueForName:(NSString *)name
{
	return [NSNumber numberWithUnsignedInteger:[self xmpp_attributeUnsignedIntegerValueForName:name]];
}

/**
 * The following methods return the corresponding value of the attribute with the given name.
 * If the attribute does not exist, the given defaultValue is returned.
**/

- (int)xmpp_attributeIntValueForName:(NSString *)name withDefaultValue:(int)defaultValue
{
	NSXMLNode *attr = [self attributeForName:name];
	return (attr) ? [[attr stringValue] intValue] : defaultValue;
}
- (BOOL)xmpp_attributeBoolValueForName:(NSString *)name withDefaultValue:(BOOL)defaultValue
{
	NSXMLNode *attr = [self attributeForName:name];
	return (attr) ? [[attr stringValue] boolValue] : defaultValue;
}
- (float)xmpp_attributeFloatValueForName:(NSString *)name withDefaultValue:(float)defaultValue
{
	NSXMLNode *attr = [self attributeForName:name];
	return (attr) ? [[attr stringValue] floatValue] : defaultValue;
}
- (double)xmpp_attributeDoubleValueForName:(NSString *)name withDefaultValue:(double)defaultValue
{
	NSXMLNode *attr = [self attributeForName:name];
	return (attr) ? [[attr stringValue] doubleValue] : defaultValue;
}
- (NSString *)xmpp_attributeStringValueForName:(NSString *)name withDefaultValue:(NSString *)defaultValue
{
    NSXMLNode *attr = [self attributeForName:name];
    return (attr) ? [attr stringValue] : defaultValue;
}
- (NSNumber *)xmpp_attributeNumberIntValueForName:(NSString *)name withDefaultValue:(int)defaultValue
{
	return [NSNumber numberWithInt:[self xmpp_attributeIntValueForName:name withDefaultValue:defaultValue]];
}
- (NSNumber *)xmpp_attributeNumberBoolValueForName:(NSString *)name withDefaultValue:(BOOL)defaultValue
{
	return [NSNumber numberWithBool:[self xmpp_attributeBoolValueForName:name withDefaultValue:defaultValue]];
}

/**
 * Returns all the attributes in a dictionary.
**/
- (NSMutableDictionary *)xmpp_attributesAsDictionary
{
	NSArray *attributes = [self attributes];
	NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:[attributes count]];
	
	NSUInteger i;
	for(i = 0; i < [attributes count]; i++)
	{
		NSXMLNode *node = [attributes objectAtIndex:i];
		
		[result setObject:[node stringValue] forKey:[node name]];
	}
	return result;
}

/**
 * The following methods return the corresponding value of the node.
**/

- (int)xmpp_stringValueAsInt
{
	return [[self stringValue] intValue];
}
- (BOOL)xmpp_stringValueAsBool
{
	return [[self stringValue] boolValue];
}
- (float)xmpp_stringValueAsFloat
{
	return [[self stringValue] floatValue];
}
- (double)xmpp_stringValueAsDouble
{
	return [[self stringValue] doubleValue];
}
- (int32_t)xmpp_stringValueAsInt32
{
	int32_t result;
	if ([NSNumber xmpp_parseString:[self stringValue] intoInt32:&result])
		return result;
	else
		return 0;
}
- (uint32_t)xmpp_stringValueAsUInt32
{
	uint32_t result;
	if ([NSNumber xmpp_parseString:[self stringValue] intoUInt32:&result])
		return result;
	else
		return 0;
}
- (int64_t)xmpp_stringValueAsInt64
{
	int64_t result = 0;
	if ([NSNumber xmpp_parseString:[self stringValue] intoInt64:&result])
		return result;
	else
		return 0;
}
- (uint64_t)xmpp_stringValueAsUInt64
{
	uint64_t result = 0;
	if ([NSNumber xmpp_parseString:[self stringValue] intoUInt64:&result])
		return result;
	else
		return 0;
}
- (NSInteger)xmpp_stringValueAsNSInteger
{
	NSInteger result = 0;
	if ([NSNumber xmpp_parseString:[self stringValue] intoNSInteger:&result])
		return result;
	else
		return 0;
}
- (NSUInteger)xmpp_stringValueAsNSUInteger
{
	NSUInteger result = 0;
	if ([NSNumber xmpp_parseString:[self stringValue] intoNSUInteger:&result])
		return result;
	else
		return 0;
}

/**
 *	Shortcut to avoid having to use NSXMLNode everytime
**/
- (void)xmpp_addNamespaceWithPrefix:(NSString *)prefix stringValue:(NSString *)string
{
	[self addNamespace:[NSXMLNode namespaceWithName:prefix stringValue:string]];
}

/**
 * Just to make your code look a little bit cleaner.
**/

- (NSString *)xmpp_namespaceStringValueForPrefix:(NSString *)prefix
{
	return [[self namespaceForPrefix:prefix] stringValue];
}

- (NSString *)xmpp_namespaceStringValueForPrefix:(NSString *)prefix withDefaultValue:(NSString *)defaultValue
{
	NSXMLNode *namespace = [self namespaceForPrefix:prefix];
	return (namespace) ? [namespace stringValue] : defaultValue;
}

@end

#ifndef XMPP_EXCLUDE_DEPRECATED

@implementation NSXMLElement (XMPPDeprecated)

+ (NSXMLElement *)elementWithName:(NSString *)name xmlns:(NSString *)ns {
    return [self xmpp_elementWithName:name xmlns:ns];
}

- (id)initWithName:(NSString *)name xmlns:(NSString *)ns {
    return [self xmpp_initWithName:name xmlns:ns];
}

- (NSArray *)elementsForXmlns:(NSString *)ns {
    return [self xmpp_elementsForXmlns:ns];
}

- (NSArray *)elementsForXmlnsPrefix:(NSString *)nsPrefix {
    return [self xmpp_elementsForXmlnsPrefix:nsPrefix];
}

- (NSXMLElement *)elementForName:(NSString *)name {
    return [self xmpp_elementForName:name];
}

- (NSXMLElement *)elementForName:(NSString *)name xmlns:(NSString *)xmlns {
    return [self xmpp_elementForName:name xmlns:xmlns];
}

- (NSXMLElement *)elementForName:(NSString *)name xmlnsPrefix:(NSString *)xmlnsPrefix {
    return [self xmpp_elementForName:name xmlnsPrefix:xmlnsPrefix];
}

- (NSString *)xmlns {
    return [self xmpp_xmlns];
}

- (void)setXmlns:(NSString *)ns {
    return [self xmpp_setXmlns:ns];
}

- (NSString *)prettyXMLString {
    return [self xmpp_prettyXMLString];
}

- (NSString *)compactXMLString {
    return [self xmpp_compactXMLString];
}

- (void)addAttributeWithName:(NSString *)name stringValue:(NSString *)string {
    return [self xmpp_addAttributeWithName:name stringValue:string];
}

- (int)attributeIntValueForName:(NSString *)name {
    return [self xmpp_attributeIntValueForName:name];
}

- (BOOL)attributeBoolValueForName:(NSString *)name {
    return [self xmpp_attributeBoolValueForName:name];
}

- (float)attributeFloatValueForName:(NSString *)name {
    return [self xmpp_attributeFloatValueForName:name];
}

- (double)attributeDoubleValueForName:(NSString *)name {
    return [self xmpp_attributeDoubleValueForName:name];
}

- (int32_t)attributeInt32ValueForName:(NSString *)name {
    return [self xmpp_attributeInt32ValueForName:name];
}

- (uint32_t)attributeUInt32ValueForName:(NSString *)name {
    return [self xmpp_attributeUInt32ValueForName:name];
}

- (int64_t)attributeInt64ValueForName:(NSString *)name {
    return [self xmpp_attributeInt64ValueForName:name];
}

- (uint64_t)attributeUInt64ValueForName:(NSString *)name {
    return [self xmpp_attributeUInt64ValueForName:name];
}

- (NSInteger)attributeIntegerValueForName:(NSString *)name {
    return [self xmpp_attributeIntegerValueForName:name];
}

- (NSUInteger)attributeUnsignedIntegerValueForName:(NSString *)name {
    return [self xmpp_attributeUnsignedIntegerValueForName:name];
}

- (NSString *)attributeStringValueForName:(NSString *)name {
    return [self xmpp_attributeStringValueForName:name];
}

- (NSNumber *)attributeNumberIntValueForName:(NSString *)name {
    return [self xmpp_attributeNumberIntValueForName:name];
}

- (NSNumber *)attributeNumberBoolValueForName:(NSString *)name {
    return [self xmpp_attributeNumberBoolValueForName:name];
}

- (NSNumber *)attributeNumberFloatValueForName:(NSString *)name {
    return [self xmpp_attributeNumberFloatValueForName:name];
}

- (NSNumber *)attributeNumberDoubleValueForName:(NSString *)name {
    return [self xmpp_attributeNumberDoubleValueForName:name];
}

- (NSNumber *)attributeNumberInt32ValueForName:(NSString *)name {
    return [self xmpp_attributeNumberInt32ValueForName:name];
}

- (NSNumber *)attributeNumberUInt32ValueForName:(NSString *)name {
    return [self xmpp_attributeNumberUInt32ValueForName:name];
}

- (NSNumber *)attributeNumberInt64ValueForName:(NSString *)name {
    return [self xmpp_attributeNumberInt64ValueForName:name];
}

- (NSNumber *)attributeNumberUInt64ValueForName:(NSString *)name {
    return [self xmpp_attributeNumberUInt64ValueForName:name];
}

- (NSNumber *)attributeNumberIntegerValueForName:(NSString *)name {
    return [self xmpp_attributeNumberIntegerValueForName:name];
}

- (NSNumber *)attributeNumberUnsignedIntegerValueForName:(NSString *)name {
    return [self xmpp_attributeNumberUnsignedIntegerValueForName:name];
}

- (int)attributeIntValueForName:(NSString *)name withDefaultValue:(int)defaultValue {
    return [self xmpp_attributeIntValueForName:name withDefaultValue:defaultValue];
}

- (BOOL)attributeBoolValueForName:(NSString *)name withDefaultValue:(BOOL)defaultValue {
    return [self xmpp_attributeBoolValueForName:name withDefaultValue:defaultValue];
}

- (float)attributeFloatValueForName:(NSString *)name withDefaultValue:(float)defaultValue {
    return [self xmpp_attributeFloatValueForName:name withDefaultValue:defaultValue];
}

- (double)attributeDoubleValueForName:(NSString *)name withDefaultValue:(double)defaultValue {
    return [self xmpp_attributeDoubleValueForName:name withDefaultValue:defaultValue];
}

- (NSString *)attributeStringValueForName:(NSString *)name withDefaultValue:(NSString *)defaultValue {
    return [self xmpp_attributeStringValueForName:name withDefaultValue:defaultValue];
}

- (NSNumber *)attributeNumberIntValueForName:(NSString *)name withDefaultValue:(int)defaultValue {
    return [self xmpp_attributeNumberIntValueForName:name withDefaultValue:defaultValue];
}

- (NSNumber *)attributeNumberBoolValueForName:(NSString *)name withDefaultValue:(BOOL)defaultValue {
    return [self xmpp_attributeNumberBoolValueForName:name withDefaultValue:defaultValue];
}

- (NSMutableDictionary *)attributesAsDictionary {
    return [self xmpp_attributesAsDictionary];
}

- (int)stringValueAsInt {
    return [self xmpp_stringValueAsInt];
}

- (BOOL)stringValueAsBool {
    return [self xmpp_stringValueAsBool];
}

- (float)stringValueAsFloat {
    return [self xmpp_stringValueAsFloat];
}

- (double)stringValueAsDouble {
    return [self xmpp_stringValueAsDouble];
}

- (int32_t)stringValueAsInt32 {
    return [self xmpp_stringValueAsInt32];
}

- (uint32_t)stringValueAsUInt32 {
    return [self xmpp_stringValueAsUInt32];
}

- (int64_t)stringValueAsInt64 {
    return [self xmpp_stringValueAsInt64];
}

- (uint64_t)stringValueAsUInt64 {
    return [self xmpp_stringValueAsUInt64];
}

- (NSInteger)stringValueAsNSInteger {
    return [self xmpp_stringValueAsNSInteger];
}

- (NSUInteger)stringValueAsNSUInteger {
    return [self xmpp_stringValueAsNSUInteger];
}

- (void)addNamespaceWithPrefix:(NSString *)prefix stringValue:(NSString *)string {
    return [self xmpp_addNamespaceWithPrefix:prefix stringValue:string];
}

- (NSString *)namespaceStringValueForPrefix:(NSString *)prefix {
    return [self xmpp_namespaceStringValueForPrefix:prefix];
}

- (NSString *)namespaceStringValueForPrefix:(NSString *)prefix withDefaultValue:(NSString *)defaultValue {
    return [self xmpp_namespaceStringValueForPrefix:prefix withDefaultValue:defaultValue];
}

@end

#endif
