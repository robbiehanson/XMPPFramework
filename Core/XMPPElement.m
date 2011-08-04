#import "XMPPElement.h"
#import "XMPPJID.h"
#import "NSXMLElement+XMPP.h"


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
	
	return [super initWithXMLString:xmlString error:nil];
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

@end
