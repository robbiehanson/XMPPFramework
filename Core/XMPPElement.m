#import "XMPPElement.h"
#import "XMPPJID.h"
#import "NSXMLElement+XMPP.h"

#import <objc/runtime.h>

// When printing XMPPElements, format the XML with indenting
// Simplified output is more readable, and uses *'s instead of opening tags, and omits closing tags
#define XMPPElementPrettyPrintEnabled 1
#define XMPPElementPrettyPrintUsesSimplifiedOutput YES

@implementation XMPPElement

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Encoding, Decoding
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#if ! TARGET_OS_IPHONE
- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder
{
	if([encoder isBycopy])
		return self;
	else
		return [super replacementObjectForPortCoder:encoder];
	//	return [NSDistantObject proxyWithLocal:self connection:[encoder connection]];
}
#endif

- (id)initWithCoder:(NSCoder *)coder
{
	NSString *xmlString;
	if([coder allowsKeyedCoding])
	{
		xmlString = [coder decodeObjectForKey:@"xmlString"];
	}
	else
	{
		xmlString = [coder decodeObject];
	}
	
	// The method [super initWithXMLString:error:] may return a different self.
	// In other words, it may [self release], and alloc/init/return a new self.
	// 
	// So to maintain the proper class (XMPPIQ, XMPPMessage, XMPPPresence, etc)
	// we need to get a reference to the class before invoking super.
	
	Class selfClass = [self class];
	
	if ((self = [super initWithXMLString:xmlString error:nil]))
	{
		object_setClass(self, selfClass);
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	NSString *xmlString = [self compactXMLString];
	
	if([coder allowsKeyedCoding])
	{
		[coder encodeObject:xmlString forKey:@"xmlString"];
	}
	else
	{
		[coder encodeObject:xmlString];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Copying
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)copyWithZone:(NSZone *)zone
{
	NSXMLElement *elementCopy = [super copyWithZone:zone];
	object_setClass(elementCopy, [self class]);
	
	return elementCopy;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Common Jabber Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)elementID
{
	return [[self attributeForName:@"id"] stringValue];
}

- (NSString *)toStr
{
	return [[self attributeForName:@"to"] stringValue];
}

- (NSString *)fromStr
{
	return [[self attributeForName:@"from"] stringValue];
}

- (XMPPJID *)to
{
	return [XMPPJID jidWithString:[self toStr]];
}

- (XMPPJID *)from
{
	return [XMPPJID jidWithString:[self fromStr]];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Debugging
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)description
{
#if XMPPElementPrettyPrintEnabled
    return [self.class _descriptionForNode:self indent:@"" simplified:XMPPElementPrettyPrintUsesSimplifiedOutput];
#else
    return [super description];
#endif
}

+ (NSString *)_descriptionForNode:(NSXMLNode *) node indent:(NSString *) indent simplified:(BOOL) simplified {
	NSMutableString *result = [NSMutableString string];
    NSString *childIndent = [indent stringByAppendingString:@"    "];
    
    if (simplified) {
        
        if ([node isKindOfClass:[NSXMLElement class]]) {
            [result appendFormat:@"%@* %@", indent, node.name];
            for (NSXMLNode *attribute in [(NSXMLElement *) node attributes])
            {
                [result appendFormat:@" %@='%@'", attribute.name, attribute.stringValue];
            }
            for (NSXMLElement *child in node.children)
            {
                [result appendFormat:@"\n%@", [self _descriptionForNode:child
                                                                 indent:childIndent
                                                             simplified:simplified]];
            }
        }
        else if (node.stringValue.length)
        {
            [result appendFormat:@"%@%@", indent, node.stringValue];
        }
        
    } else {
        
        if ([node isKindOfClass:[NSXMLElement class]]) {
            [result appendFormat:@"%@<%@", indent, node.name];
            for (NSXMLNode *attribute in [(NSXMLElement *) node attributes])
            {
                [result appendFormat:@" %@=\"%@\"", attribute.name, attribute.stringValue];
            }
            
            if (node.childCount) {
                [result appendString:@">"];
                NSString *childIndent = [indent stringByAppendingString:@"    "];
                for (NSXMLElement *child in node.children)
                {
                    [result appendFormat:@"\n%@", [self _descriptionForNode:child
                                                                     indent:childIndent
                                                                 simplified:simplified]];
                }
                [result appendFormat:@"\n%@</%@>", indent, node.name];
            }
        }
        else if (node.stringValue.length)
        {
            [result appendFormat:@"%@%@", indent, node.stringValue];
        }
        else
        {
            [result appendString:@"/>"];
        }
        
    }
    
	return result;
}

@end
