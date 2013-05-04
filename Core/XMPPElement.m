#import "XMPPElement.h"
#import "XMPPJID.h"
#import "NSXMLElement+XMPP.h"

#import <objc/runtime.h>


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
#pragma mark To and From Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)isTo:(XMPPJID *)to
{
	return [self.to isEqualToJID:to];
}

- (BOOL)isTo:(XMPPJID *)to options:(XMPPJIDCompareOptions)mask
{
	return [self.to isEqualToJID:to options:mask];
}

- (BOOL)isFrom:(XMPPJID *)from
{
	return [self.from isEqualToJID:from];
}

- (BOOL)isFrom:(XMPPJID *)from options:(XMPPJIDCompareOptions)mask
{
	return [self.from isEqualToJID:from options:mask];
}

- (BOOL)isToOrFrom:(XMPPJID *)toOrFrom
{
	if([self isTo:toOrFrom] || [self isFrom:toOrFrom])
	{
		return YES;
	}
	else
	{
		return NO;
	}
}

- (BOOL)isToOrFrom:(XMPPJID *)toOrFrom options:(XMPPJIDCompareOptions)mask
{
	if([self isTo:toOrFrom options:mask] || [self isFrom:toOrFrom options:mask])
	{
		return YES;
	}
	else
	{
		return NO;
	}
}

- (BOOL)isTo:(XMPPJID *)to from:(XMPPJID *)from
{
	if([self isTo:to] && [self isFrom:from])
	{
		return YES;
	}
	else
	{
		return NO;
	}
}

- (BOOL)isTo:(XMPPJID *)to from:(XMPPJID *)from options:(XMPPJIDCompareOptions)mask
{
	if([self isTo:to options:mask] && [self isFrom:from options:mask])
	{
		return YES;
	}
	else
	{
		return NO;
	}
}

@end
