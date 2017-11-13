#import "NSXMLElement+XEP_0203.h"
#import "XMPPDateTimeProfiles.h"
#import "NSXMLElement+XMPP.h"
#import "XMPPJID.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

@implementation NSXMLElement (XEP_0203)

- (BOOL)wasDelayed
{
    return [self anyDelayedDeliveryChildElement] != nil;
}

- (NSDate *)delayedDeliveryDate
{
	// From XEP-0203 (Delayed Delivery)
	//
	// <delay xmlns='urn:xmpp:delay'
	//         from='juliet@capulet.com/balcony'
	//        stamp='2002-09-10T23:41:07Z'/>
	//
	// The format [of the stamp attribute] MUST adhere to the dateTime format
	// specified in XEP-0082 and MUST be expressed in UTC.
	
	NSXMLElement *delay = [self delayedDeliveryChildElement];
	if (delay)
	{
		NSString *stampValue = [delay attributeStringValueForName:@"stamp"];
		
		// There are other considerations concerning XEP-0082.
		// For example, it may optionally contain milliseconds.
		// And it may possibly express UTC as "+00:00" instead of "Z".
		//
		// Thankfully there is already an implementation that takes into account all these possibilities.
		
		return [XMPPDateTimeProfiles parseDateTime:stampValue];
	}
	
	// From XEP-0091 (Legacy Delayed Delivery)
	//
	// <x xmlns='jabber:x:delay'
	//     from='capulet.com'
	//    stamp='20020910T23:08:25'>
	
	NSXMLElement *legacyDelay = [self legacyDelayedDeliveryChildElement];
	if (legacyDelay)
	{
		NSDate *stamp;
		
		NSString *stampValue = [legacyDelay attributeStringValueForName:@"stamp"];
		
		NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
		[dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
        [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
		[dateFormatter setDateFormat:@"yyyyMMdd'T'HH:mm:ss"];
		[dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
		
		stamp = [dateFormatter dateFromString:stampValue];
		
		return stamp;
	}
	
	return nil;
}

- (XMPPJID *)delayedDeliveryFrom
{
    NSString *delayedDeliveryFromString = [[self anyDelayedDeliveryChildElement] attributeStringValueForName:@"from"];
    return delayedDeliveryFromString ? [XMPPJID jidWithString:delayedDeliveryFromString] : nil;
}

- (NSString *)delayedDeliveryReasonDescription
{
    return [self anyDelayedDeliveryChildElement].stringValue;
}

- (NSXMLElement *)delayedDeliveryChildElement
{
    return [self elementForName:@"delay" xmlns:@"urn:xmpp:delay"];
}

- (NSXMLElement *)legacyDelayedDeliveryChildElement
{
    return [self elementForName:@"x" xmlns:@"jabber:x:delay"];
}

- (NSXMLElement *)anyDelayedDeliveryChildElement
{
    return [self delayedDeliveryChildElement] ?: [self legacyDelayedDeliveryChildElement];
}

@end
