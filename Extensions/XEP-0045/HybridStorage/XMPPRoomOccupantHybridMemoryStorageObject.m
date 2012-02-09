#import "XMPPRoomOccupantHybridMemoryStorageObject.h"


@implementation XMPPRoomOccupantHybridMemoryStorageObject
{
	XMPPPresence *presence;
	XMPPJID *jid;
	NSDate *createdAt;
	XMPPJID *streamFullJid;
}

- (id)initWithPresence:(XMPPPresence *)inPresence streamFullJid:(XMPPJID *)inStreamFullJid
{
	NSParameterAssert(inPresence != nil);
	NSParameterAssert(inStreamFullJid != nil);
	
	if ((self = [super init]))
	{
		presence = inPresence;
		jid = [presence from];
		createdAt = [[NSDate alloc] init];
		streamFullJid = inStreamFullJid;
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
			presence      = [coder decodeObjectForKey:@"presence"];
			jid           = [coder decodeObjectForKey:@"jid"];
			createdAt     = [coder decodeObjectForKey:@"createdAt"];
			streamFullJid = [coder decodeObjectForKey:@"streamFullJid"];
		}
		else
		{
			presence      = [coder decodeObject];
			jid           = [coder decodeObject];
			createdAt     = [coder decodeObject];
			streamFullJid = [coder decodeObject];
		}
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	if ([coder allowsKeyedCoding])
	{
		[coder encodeObject:presence      forKey:@"presence"];
		[coder encodeObject:jid           forKey:@"jid"];
		[coder encodeObject:createdAt     forKey:@"createdAt"];
		[coder encodeObject:streamFullJid forKey:@"streamFullJid"];
	}
	else
	{
		[coder encodeObject:presence];
		[coder encodeObject:jid];
		[coder encodeObject:createdAt];
		[coder encodeObject:streamFullJid];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Copying
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)copyWithZone:(NSZone *)zone
{
	// We use [self class] to support subclassing
	
	XMPPRoomOccupantHybridMemoryStorageObject *deepCopy;
	deepCopy = (XMPPRoomOccupantHybridMemoryStorageObject *)[[[self class] alloc] init];
	
	deepCopy->presence      = [presence copy];
	deepCopy->jid           = [jid copy];
	deepCopy->createdAt     = [createdAt copy];
	deepCopy->streamFullJid = [streamFullJid copy];
	
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

- (XMPPPresence *)presence
{
	return presence;
}

- (XMPPJID *)jid
{
	return jid;
}

- (XMPPJID *)roomJID
{
	return [jid bareJID];
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

- (NSDate *)createdAt
{
	return createdAt;
}

- (XMPPJID *)streamFullJid
{
	return streamFullJid;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Compare
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSComparisonResult)compareByNickname:(XMPPRoomOccupantHybridMemoryStorageObject *)another
{
	return [self.nickname compare:another.nickname];
}

- (NSComparisonResult)compareByCreatedAt:(XMPPRoomOccupantHybridMemoryStorageObject *)another
{
	return [self.createdAt compare:another.createdAt];
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
		XMPPRoomOccupantHybridMemoryStorageObject *another = (XMPPRoomOccupantHybridMemoryStorageObject *)anObject;
		
		if ([jid isEqualToJID:[another jid]])
		{
			if ([streamFullJid isEqualToJID:[another streamFullJid]])
			{
				return YES;
			}
		}
	}
	
	return NO;
}

@end
