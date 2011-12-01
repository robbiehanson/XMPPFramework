#import "XMPPRoomMessageMemoryStorage.h"
#import "XMPP.h"
#import "XMPPElement+Delay.h"


@implementation XMPPRoomMessageMemoryStorage
{
	XMPPMessage *message;
	NSDate *timestamp;
}

- (id)initWithMessage:(XMPPMessage *)inMessage
{
	if ((self = [super init]))
	{
		message = inMessage;
		
		timestamp = [inMessage delayedDeliveryDate];
		if (timestamp == nil)
			timestamp = [[NSDate alloc] init];
	}
	return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Encoding, Decoding
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#if ! TARGET_OS_IPHONE
- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder
{
	if ([encoder isBycopy])
		return self;
	else
		return [super replacementObjectForPortCoder:encoder];
	//	return [NSDistantObject proxyWithLocal:self connection:[encoder connection]];
}
#endif

- (id)initWithCoder:(NSCoder *)coder
{
	if ((self = [super init]))
	{
		if ([coder allowsKeyedCoding])
		{
			message   = [coder decodeObjectForKey:@"message"];
			timestamp = [coder decodeObjectForKey:@"timestamp"];
		}
		else
		{
			message   = [coder decodeObject];
			timestamp = [coder decodeObject];
		}
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	if ([coder allowsKeyedCoding])
	{
		[coder encodeObject:message   forKey:@"message"];
		[coder encodeObject:timestamp forKey:@"timestamp"];
	}
	else
	{
		[coder encodeObject:message];
		[coder encodeObject:timestamp];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Copying
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)copyWithZone:(NSZone *)zone
{
	// We use [self class] to support subclassing
	
	XMPPRoomMessageMemoryStorage *deepCopy = (XMPPRoomMessageMemoryStorage *)[[[self class] alloc] init];
	
	deepCopy->message = [message copy];
	deepCopy->timestamp = [timestamp copy];
	
	return deepCopy;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@synthesize message;
@synthesize timestamp;

- (XMPPJID *)jid
{
	return [message from];
}

- (NSString *)nickname
{
	return [[message from] resource];
}

- (NSString *)body
{
	return [[message elementForName:@"body"] stringValue];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Comparisons
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSComparisonResult)compare:(XMPPRoomMessageMemoryStorage *)another
{
	return [timestamp compare:[another timestamp]];
}

@end
