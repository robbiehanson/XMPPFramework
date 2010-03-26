#import "XMPPElement.h"
#import "XMPPJID.h"
#import "NSXMLElementAdditions.h"


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

- (NSString *)toStr
{
	return [[self attributeForName:@"to"] stringValue];
}

- (NSString *)fromStr
{
	return [[self attributeForName:@"from"] stringValue];;
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
#pragma mark Common XEP Support
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)wasDelayed
{
	NSXMLElement *delay;
	
	delay = [self elementForName:@"delay" xmlns:@"urn:xmpp:delay"];
	if (delay)
	{
		return YES;
	}
	
	delay = [self elementForName:@"delay" xmlns:@"jabber:x:delay"];
	if (delay)
	{
		return YES;
	}
	
	return NO;
}

- (NSDate *)delayedDeliveryDate
{
	NSXMLElement *delay;
	
	// From XEP-0203 (Delayed Delivery)
	// 
	// <delay xmlns='urn:xmpp:delay'
	//         from='juliet@capulet.com/balcony'
	//        stamp='2002-09-10T23:41:07Z'/>
	
	delay = [self elementForName:@"delay" xmlns:@"urn:xmpp:delay"];
	if (delay)
	{
		NSDate *stamp;
		
		NSString *stampValue = [delay attributeStringValueForName:@"stamp"];
		
		NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
		[dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
		[dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
		[dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
		
		stamp = [dateFormatter dateFromString:stampValue];
		
		[dateFormatter release];
		return stamp;
	}
	
	// From XEP-0091 (Legacy Delayed Delivery)
	// 
	// <x xmlns='jabber:x:delay'
	//     from='capulet.com'
	//    stamp='20020910T23:08:25'>
	
	delay = [self elementForName:@"delay" xmlns:@"jabber:x:delay"];
	if (delay)
	{
		NSDate *stamp;
		
		NSString *stampValue = [delay attributeStringValueForName:@"stamp"];
		
		NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
		[dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
		[dateFormatter setDateFormat:@"yyyyMMdd'T'HH:mm:ss"];
		[dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
		
		stamp = [dateFormatter dateFromString:stampValue];
		
		[dateFormatter release];
		return stamp;
	}
	
	return nil;
}

@end
