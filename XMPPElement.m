#import "XMPPElement.h"
#import "XMPPJID.h"


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
		return [NSDistantObject proxyWithLocal:self connection:[encoder connection]];
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
	NSString *xmlString = [self XMLString];
	
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

- (XMPPJID *)to
{
	NSString *str = [[self attributeForName:@"to"] stringValue];
	return [XMPPJID jidWithString:str];
}

- (XMPPJID *)from
{
	NSString *str = [[self attributeForName:@"from"] stringValue];
	return [XMPPJID jidWithString:str];
}

@end
