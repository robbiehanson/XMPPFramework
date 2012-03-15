#import "NSXMLElement+XMPP.h"
#import "NSNumber+XMPP.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

@implementation NSXMLElement (XMPP)

/**
 * Quick method to create an element
**/
+ (NSXMLElement *)elementWithName:(NSString *)name xmlns:(NSString *)ns
{
	NSXMLElement *element = [NSXMLElement elementWithName:name];
	[element setXmlns:ns];
	return element;
}

- (id)initWithName:(NSString *)name xmlns:(NSString *)ns
{
	if ((self = [self initWithName:name]))
	{
		[self setXmlns:ns];
	}
	return self;
}

- (NSArray *)elementsForXmlns:(NSString *)ns
{
	NSMutableArray *elements = [NSMutableArray array];
	
	for (NSXMLNode *node in [self children])
	{
		if ([node isKindOfClass:[NSXMLElement class]])
		{
			NSXMLElement *element = (NSXMLElement *)node;
			
			if ([[element xmlns] isEqual:ns])
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
- (NSXMLElement *)elementForName:(NSString *)name
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
- (NSXMLElement *)elementForName:(NSString *)name xmlns:(NSString *)xmlns
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

/**
 * Returns the common xmlns "attribute", which is only accessible via the namespace methods.
 * The xmlns value is often used in jabber elements.
**/
- (NSString *)xmlns
{
	return [[self namespaceForPrefix:@""] stringValue];
}

- (void)setXmlns:(NSString *)ns
{
	// If we use setURI: then the xmlns won't be displayed in the XMLString.
	// Adding the namespace this way works properly.
	
	[self addNamespace:[NSXMLNode namespaceWithName:@"" stringValue:ns]];
}

/**
 * Shortcut to get a pretty (formatted) string representation of the element.
**/
- (NSString *)prettyXMLString
{
	return [self XMLStringWithOptions:(NSXMLNodePrettyPrint | NSXMLNodeCompactEmptyElement)];
}

/**
 * Shortcut to get a compact string representation of the element.
**/
- (NSString *)compactXMLString
{
    return [self XMLStringWithOptions:NSXMLNodeCompactEmptyElement];
}

/**
 *	Shortcut to avoid having to use NSXMLNode everytime
**/
- (void)addAttributeWithName:(NSString *)name stringValue:(NSString *)string
{
	[self addAttribute:[NSXMLNode attributeWithName:name stringValue:string]];
}

/**
 * The following methods return the corresponding value of the attribute with the given name.
**/

- (int)attributeIntValueForName:(NSString *)name
{
	return [[self attributeStringValueForName:name] intValue];
}
- (BOOL)attributeBoolValueForName:(NSString *)name
{
	return [[self attributeStringValueForName:name] boolValue];
}
- (float)attributeFloatValueForName:(NSString *)name
{
	return [[self attributeStringValueForName:name] floatValue];
}
- (double)attributeDoubleValueForName:(NSString *)name
{
	return [[self attributeStringValueForName:name] doubleValue];
}
- (int32_t)attributeInt32ValueForName:(NSString *)name
{
	int32_t result = 0;
	[NSNumber parseString:[self attributeStringValueForName:name] intoInt32:&result];
	return result;
}
- (uint32_t)attributeUInt32ValueForName:(NSString *)name
{
	uint32_t result = 0;
	[NSNumber parseString:[self attributeStringValueForName:name] intoUInt32:&result];
	return result;
}
- (int64_t)attributeInt64ValueForName:(NSString *)name
{
	int64_t result;
	[NSNumber parseString:[self attributeStringValueForName:name] intoInt64:&result];
	return result;
}
- (uint64_t)attributeUInt64ValueForName:(NSString *)name
{
	uint64_t result;
	[NSNumber parseString:[self attributeStringValueForName:name] intoUInt64:&result];
	return result;
}
- (NSInteger)attributeIntegerValueForName:(NSString *)name
{
	NSInteger result;
	[NSNumber parseString:[self attributeStringValueForName:name] intoNSInteger:&result];
	return result;
}
- (NSUInteger)attributeUnsignedIntegerValueForName:(NSString *)name
{
	NSUInteger result = 0;
	[NSNumber parseString:[self attributeStringValueForName:name] intoNSUInteger:&result];
	return result;
}
- (NSString *)attributeStringValueForName:(NSString *)name
{
	return [[self attributeForName:name] stringValue];
}
- (NSNumber *)attributeNumberIntValueForName:(NSString *)name
{
	return [NSNumber numberWithInt:[self attributeIntValueForName:name]];
}
- (NSNumber *)attributeNumberBoolValueForName:(NSString *)name
{
	return [NSNumber numberWithBool:[self attributeBoolValueForName:name]];
}
- (NSNumber *)attributeNumberFloatValueForName:(NSString *)name
{
	return [NSNumber numberWithFloat:[self attributeFloatValueForName:name]];
}
- (NSNumber *)attributeNumberDoubleValueForName:(NSString *)name
{
	return [NSNumber numberWithDouble:[self attributeDoubleValueForName:name]];
}
- (NSNumber *)attributeNumberInt32ValueForName:(NSString *)name
{
	return [NSNumber numberWithInt:[self attributeInt32ValueForName:name]];
}
- (NSNumber *)attributeNumberUInt32ValueForName:(NSString *)name
{
	return [NSNumber numberWithUnsignedInt:[self attributeUInt32ValueForName:name]];
}
- (NSNumber *)attributeNumberInt64ValueForName:(NSString *)name
{
	return [NSNumber numberWithLongLong:[self attributeInt64ValueForName:name]];
}
- (NSNumber *)attributeNumberUInt64ValueForName:(NSString *)name
{
	return [NSNumber numberWithUnsignedLongLong:[self attributeUInt64ValueForName:name]];
}
- (NSNumber *)attributeNumberIntegerValueForName:(NSString *)name
{
	return [NSNumber numberWithInteger:[self attributeIntegerValueForName:name]];
}
- (NSNumber *)attributeNumberUnsignedIntegerValueForName:(NSString *)name
{
	return [NSNumber numberWithUnsignedInteger:[self attributeUnsignedIntegerValueForName:name]];
}

/**
 * The following methods return the corresponding value of the attribute with the given name.
 * If the attribute does not exist, the given defaultValue is returned.
**/

- (int)attributeIntValueForName:(NSString *)name withDefaultValue:(int)defaultValue
{
	NSXMLNode *attr = [self attributeForName:name];
	return (attr) ? [[attr stringValue] intValue] : defaultValue;
}
- (BOOL)attributeBoolValueForName:(NSString *)name withDefaultValue:(BOOL)defaultValue
{
	NSXMLNode *attr = [self attributeForName:name];
	return (attr) ? [[attr stringValue] boolValue] : defaultValue;
}
- (float)attributeFloatValueForName:(NSString *)name withDefaultValue:(float)defaultValue
{
	NSXMLNode *attr = [self attributeForName:name];
	return (attr) ? [[attr stringValue] floatValue] : defaultValue;
}
- (double)attributeDoubleValueForName:(NSString *)name withDefaultValue:(double)defaultValue
{
	NSXMLNode *attr = [self attributeForName:name];
	return (attr) ? [[attr stringValue] doubleValue] : defaultValue;
}
- (NSString *)attributeStringValueForName:(NSString *)name withDefaultValue:(NSString *)defaultValue
{
    NSXMLNode *attr = [self attributeForName:name];
    return (attr) ? [attr stringValue] : defaultValue;
}
- (NSNumber *)attributeNumberIntValueForName:(NSString *)name withDefaultValue:(int)defaultValue
{
	return [NSNumber numberWithInt:[self attributeIntValueForName:name withDefaultValue:defaultValue]];
}
- (NSNumber *)attributeNumberBoolValueForName:(NSString *)name withDefaultValue:(BOOL)defaultValue
{
	return [NSNumber numberWithBool:[self attributeBoolValueForName:name withDefaultValue:defaultValue]];
}

/**
 * Returns all the attributes in a dictionary.
**/
- (NSMutableDictionary *)attributesAsDictionary
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

- (int)stringValueAsInt
{
	return [[self stringValue] intValue];
}
- (BOOL)stringValueAsBool
{
	return [[self stringValue] boolValue];
}
- (float)stringValueAsFloat
{
	return [[self stringValue] floatValue];
}
- (double)stringValueAsDouble
{
	return [[self stringValue] doubleValue];
}
- (int32_t)stringValueAsInt32
{
	int32_t result;
	if ([NSNumber parseString:[self stringValue] intoInt32:&result])
		return result;
	else
		return 0;
}
- (uint32_t)stringValueAsUInt32
{
	uint32_t result;
	if ([NSNumber parseString:[self stringValue] intoUInt32:&result])
		return result;
	else
		return 0;
}
- (int64_t)stringValueAsInt64
{
	int64_t result = 0;
	if ([NSNumber parseString:[self stringValue] intoInt64:&result])
		return result;
	else
		return 0;
}
- (uint64_t)stringValueAsUInt64
{
	uint64_t result = 0;
	if ([NSNumber parseString:[self stringValue] intoUInt64:&result])
		return result;
	else
		return 0;
}
- (NSInteger)stringValueAsNSInteger
{
	NSInteger result = 0;
	if ([NSNumber parseString:[self stringValue] intoNSInteger:&result])
		return result;
	else
		return 0;
}
- (NSUInteger)stringValueAsNSUInteger
{
	NSUInteger result = 0;
	if ([NSNumber parseString:[self stringValue] intoNSUInteger:&result])
		return result;
	else
		return 0;
}

/**
 *	Shortcut to avoid having to use NSXMLNode everytime
**/
- (void)addNamespaceWithPrefix:(NSString *)prefix stringValue:(NSString *)string
{
	[self addNamespace:[NSXMLNode namespaceWithName:prefix stringValue:string]];
}

/**
 * Just to make your code look a little bit cleaner.
**/

- (NSString *)namespaceStringValueForPrefix:(NSString *)prefix
{
	return [[self namespaceForPrefix:prefix] stringValue];
}

- (NSString *)namespaceStringValueForPrefix:(NSString *)prefix withDefaultValue:(NSString *)defaultValue
{
	NSXMLNode *namespace = [self namespaceForPrefix:prefix];
	return (namespace) ? [namespace stringValue] : defaultValue;
}

@end
