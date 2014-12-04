#import "XMPPRoomOccupantMemoryStorageObject.h"


@implementation XMPPRoomOccupantMemoryStorageObject
{
	XMPPPresence *presence;
	XMPPJID *jid;
}

- (id)initWithPresence:(XMPPPresence *)inPresence
{
	if ((self = [super init]))
	{
		presence = inPresence;
		jid = [inPresence from];
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
                presence = [coder decodeObjectOfClass:[XMPPPresence class] forKey:@"presence"];
                jid      = [coder decodeObjectOfClass:[XMPPJID class] forKey:@"jid"];
            }
            else
            {
                presence = [coder decodeObjectForKey:@"presence"];
                jid      = [coder decodeObjectForKey:@"jid"];
            }
		}
		else
		{
			presence = [coder decodeObject];
			jid      = [coder decodeObject];
		}
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	if ([coder allowsKeyedCoding])
	{
		[coder encodeObject:presence forKey:@"presence"];
		[coder encodeObject:jid forKey:@"jid"];
	}
	else
	{
		[coder encodeObject:presence];
		[coder encodeObject:jid];
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
	
	XMPPRoomOccupantMemoryStorageObject *deepCopy = (XMPPRoomOccupantMemoryStorageObject *)[[[self class] alloc] init];
	
	deepCopy->presence = [presence copy];
	deepCopy->jid = [jid copy];
	
	return deepCopy;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Updates
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)updateWithPresence:(XMPPPresence *)inPresence
{
	presence = inPresence;
	jid = [inPresence from];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (XMPPJID *)roomJID
{
	return [jid bareJID];
}

- (XMPPJID *)jid
{
	return jid;
}

- (NSString *)nickname
{
	return [jid resource];
}

- (NSString *)itemAttributeStringValueForName:(NSString *)attrName
{
	NSXMLElement *x = [presence elementForName:@"x" xmlns:@"http://jabber.org/protocol/muc#user"];
	NSXMLElement *item = [x elementForName:@"item"];
	if (item)
	{
		NSString *result = [item attributeStringValueForName:attrName];
		if (result)
		{
			return [result lowercaseString];
		}
	}
	
	return nil;
}

- (NSString *)role
{
	return [self itemAttributeStringValueForName:@"role"];
}

- (NSString *)affiliation
{
	return [self itemAttributeStringValueForName:@"affiliation"];
}

- (XMPPJID *)realJID
{
	NSString *jidStr = [self itemAttributeStringValueForName:@"jid"];
	if (jidStr)
		return [XMPPJID jidWithString:jidStr];
	else
		return nil;
}

- (XMPPPresence *)presence
{
	return presence;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Comparisons
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSComparisonResult)compare:(XMPPRoomOccupantMemoryStorageObject *)another
{
	return [self.nickname compare:another.nickname];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSObject Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSUInteger)hash
{
	return [jid hash];
}

- (BOOL)isEqual:(id)anObject
{
	if ([anObject isMemberOfClass:[self class]])
	{
		XMPPRoomOccupantMemoryStorageObject *another = (XMPPRoomOccupantMemoryStorageObject *)anObject;
		
		return [jid isEqualToJID:[another jid]];
	}
	
	return NO;
}

@end
