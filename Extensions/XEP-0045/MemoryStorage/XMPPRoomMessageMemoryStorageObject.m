#import "XMPPRoomMessageMemoryStorageObject.h"
#import "XMPP.h"
#import "NSXMLElement+XEP_0203.h"


@implementation XMPPRoomMessageMemoryStorageObject
{
	XMPPMessage *message;
	XMPPJID *jid;
	NSDate *localTimestamp;
	NSDate *remoteTimestamp;
	BOOL isFromMe;
}

- (id)initWithIncomingMessage:(XMPPMessage *)inMessage
{
	if ((self = [super init]))
	{
		message = inMessage;
		jid = [inMessage from];
		isFromMe = NO;
		
		remoteTimestamp = [inMessage delayedDeliveryDate];
		if (remoteTimestamp)
			localTimestamp = remoteTimestamp;
		else
			localTimestamp = [[NSDate alloc] init];
	}
	return self;
}

- (id)initWithOutgoingMessage:(XMPPMessage *)inMessage  jid:(XMPPJID *)myRoomJID
{
	if ((self = [super init]))
	{
		message = inMessage;
		jid = myRoomJID;
		isFromMe = YES;
		
		localTimestamp = [[NSDate alloc] init];
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
            if([coder respondsToSelector:@selector(requiresSecureCoding)] &&
               [coder requiresSecureCoding])
            {
                message         = [coder decodeObjectOfClass:[XMPPMessage class] forKey:@"message"];
                jid             = [coder decodeObjectOfClass:[XMPPJID class] forKey:@"jid"];
                localTimestamp  = [coder decodeObjectOfClass:[NSDate class] forKey:@"localTimestamp"];
                remoteTimestamp = [coder decodeObjectOfClass:[NSDate class] forKey:@"remoteTimestamp"];
                isFromMe        = [coder decodeBoolForKey:@"isFromMe"];
            }
            else
            {
                message         = [coder decodeObjectForKey:@"message"];
                jid             = [coder decodeObjectForKey:@"jid"];
                localTimestamp  = [coder decodeObjectForKey:@"localTimestamp"];
                remoteTimestamp = [coder decodeObjectForKey:@"remoteTimestamp"];
                isFromMe        = [coder decodeBoolForKey:@"isFromMe"];
            }
			
		}
		else
		{
			message         = [coder decodeObject];
			jid             = [coder decodeObject];
			localTimestamp  = [coder decodeObject];
			remoteTimestamp = [coder decodeObject];
			isFromMe        = [[coder decodeObject] boolValue];
		}
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	if ([coder allowsKeyedCoding])
	{
		[coder encodeObject:message         forKey:@"message"];
		[coder encodeObject:jid             forKey:@"jid"];
		[coder encodeObject:localTimestamp  forKey:@"timestamp"];
		[coder encodeObject:remoteTimestamp forKey:@"remoteTimestamp"];
		[coder encodeBool:isFromMe          forKey:@"isFromMe"];
	}
	else
	{
		[coder encodeObject:message];
		[coder encodeObject:jid];
		[coder encodeObject:localTimestamp];
		[coder encodeObject:remoteTimestamp];
    [coder encodeObject:@(isFromMe)];
	}
}

+ (BOOL) supportsSecureCoding
{
    return YES;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Copying
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)copyWithZone:(NSZone *)zone
{
	// We use [self class] to support subclassing
	
	XMPPRoomMessageMemoryStorageObject *deepCopy = (XMPPRoomMessageMemoryStorageObject *)[[[self class] alloc] init];
	
	deepCopy->message = [message copy];
	deepCopy->jid = [jid copy];
	deepCopy->localTimestamp = [localTimestamp copy];
	deepCopy->remoteTimestamp = [remoteTimestamp copy];
	deepCopy->isFromMe = isFromMe;
	
	return deepCopy;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@synthesize message;
@synthesize jid;
@synthesize localTimestamp;
@synthesize remoteTimestamp;
@synthesize isFromMe;

- (XMPPJID *)roomJID
{
	return [jid bareJID];
}

- (NSString *)nickname
{
	return [jid resource];
}

- (NSString *)body
{
	return [[message elementForName:@"body"] stringValue];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Comparisons
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSComparisonResult)compare:(XMPPRoomMessageMemoryStorageObject *)another
{
	return [localTimestamp compare:[another localTimestamp]];
}

@end
