#import "XMPPRoomOccupantCoreDataStorageObject.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif


@interface XMPPRoomOccupantCoreDataStorageObject ()

@property(nonatomic,strong) XMPPPresence * primitivePresence;
@property(nonatomic,strong) NSString * primitivePresenceStr;

@property(nonatomic,strong) XMPPJID * primitiveRoomJID;
@property(nonatomic,strong) NSString * primitiveRoomJIDStr;

@property(nonatomic,strong) XMPPJID * primitiveJid;
@property(nonatomic,strong) NSString * primitiveJidStr;

@property(nonatomic,strong) XMPPJID * primitiveRealJID;
@property(nonatomic,strong) NSString * primitiveRealJIDStr;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPRoomOccupantCoreDataStorageObject

@dynamic presence, primitivePresence;
@dynamic presenceStr, primitivePresenceStr;
@dynamic roomJID, primitiveRoomJID;
@dynamic roomJIDStr, primitiveRoomJIDStr;
@dynamic jid, primitiveJid;
@dynamic jidStr, primitiveJidStr;
@dynamic nickname;
@dynamic role;
@dynamic affiliation;
@dynamic realJID, primitiveRealJID;
@dynamic realJIDStr, primitiveRealJIDStr;
@dynamic createdAt;
@dynamic streamBareJidStr;

#pragma mark Transient presence

- (XMPPPresence *)presence
{
	// Create and cache on demand
	
	[self willAccessValueForKey:@"presence"];
	XMPPPresence *presence = self.primitivePresence;
	[self didAccessValueForKey:@"presence"];
	
	if (presence == nil)
	{
		NSString *presenceStr = self.presenceStr;
		if (presenceStr)
		{
			NSXMLElement *element = [[NSXMLElement alloc] initWithXMLString:presenceStr error:nil];
			presence = [XMPPPresence presenceFromElement:element];
			self.primitivePresence = presence;
		}
    }
	
    return presence;
}

- (void)setPresence:(XMPPPresence *)newPresence
{
	[self willChangeValueForKey:@"presence"];
	[self willChangeValueForKey:@"presenceStr"];
	
	self.primitivePresence = newPresence;
	self.primitivePresenceStr = [newPresence compactXMLString];
	
	[self didChangeValueForKey:@"presence"];
	[self didChangeValueForKey:@"presenceStr"];
}

- (void)setPresenceStr:(NSString *)presenceStr
{
	[self willChangeValueForKey:@"presence"];
	[self willChangeValueForKey:@"presenceStr"];
	
	NSXMLElement *element = [[NSXMLElement alloc] initWithXMLString:presenceStr error:nil];
	self.primitivePresence = [XMPPPresence presenceFromElement:element];
	self.primitivePresenceStr = presenceStr;
	
	[self didChangeValueForKey:@"presence"];
	[self didChangeValueForKey:@"presenceStr"];
}

#pragma mark Transient roomJID

- (XMPPJID *)roomJID
{
	// Create and cache on demand
	
	[self willAccessValueForKey:@"roomJID"];
	XMPPJID *tmp = self.primitiveRoomJID;
	[self didAccessValueForKey:@"roomJID"];
	
	if (tmp == nil)
	{
		NSString *roomJIDStr = self.roomJIDStr;
		if (roomJIDStr)
		{
			tmp = [XMPPJID jidWithString:roomJIDStr];
			self.primitiveRoomJID = tmp;
		}
	}
	
	return tmp;
}

- (void)setRoomJID:(XMPPJID *)roomJID
{
	[self willChangeValueForKey:@"roomJID"];
	[self willChangeValueForKey:@"roomJIDStr"];
	
	self.primitiveRoomJID = roomJID;
	self.primitiveRoomJIDStr = [roomJID full];
	
	[self didChangeValueForKey:@"roomJID"];
	[self didChangeValueForKey:@"roomJIDStr"];
}

- (void)setRoomJIDStr:(NSString *)roomJIDStr
{
	[self willChangeValueForKey:@"roomJID"];
	[self willChangeValueForKey:@"roomJIDStr"];
	
	self.primitiveRoomJID = [XMPPJID jidWithString:roomJIDStr];
	self.primitiveRoomJIDStr = roomJIDStr;
	
	[self didChangeValueForKey:@"roomJID"];
	[self didChangeValueForKey:@"roomJIDStr"];
}

#pragma mark Transient jid

- (XMPPJID *)jid
{
	// Create and cache on demand
	
	[self willAccessValueForKey:@"jid"];
	XMPPJID *tmp = self.primitiveJid;
	[self didAccessValueForKey:@"jid"];
	
	if (tmp == nil)
	{
		NSString *jidStr = self.jidStr;
		if (jidStr)
		{
			tmp = [XMPPJID jidWithString:jidStr];
			self.primitiveJid = tmp;
		}
	}
	
	return tmp;
}

- (void)setJid:(XMPPJID *)jid
{
	[self willChangeValueForKey:@"jid"];
	[self willChangeValueForKey:@"jidStr"];
	
	self.primitiveJid = jid;
	self.primitiveJidStr = [jid full];
	
	[self didChangeValueForKey:@"jid"];
	[self didChangeValueForKey:@"jidStr"];
}

- (void)setJidStr:(NSString *)jidStr
{
	[self willChangeValueForKey:@"jid"];
	[self willChangeValueForKey:@"jidStr"];
	
	self.primitiveJid = [XMPPJID jidWithString:jidStr];
	self.primitiveJidStr = jidStr;
	
	[self didChangeValueForKey:@"jid"];
	[self didChangeValueForKey:@"jidStr"];
}

#pragma mark Transient realJID

- (XMPPJID *)realJID
{
	// Create and cache on demand
	
	[self willAccessValueForKey:@"realJID"];
	XMPPJID *tmp = self.primitiveRealJID;
	[self didAccessValueForKey:@"realJID"];
	
	if (tmp == nil)
	{
		NSString *realJIDStr = self.realJIDStr;
		if (realJIDStr)
		{
			tmp = [XMPPJID jidWithString:realJIDStr];
			self.primitiveRealJID = tmp;
		}
	}
	
	return tmp;
}

- (void)setRealJID:(XMPPJID *)realJID
{
	[self willChangeValueForKey:@"realJID"];
	[self willChangeValueForKey:@"realJIDStr"];
	
	self.primitiveRealJID = realJID;
	self.primitiveRealJIDStr = [realJID full];
	
	[self didChangeValueForKey:@"realJID"];
	[self didChangeValueForKey:@"realJIDStr"];
}

- (void)setRealJIDStr:(NSString *)realJIDStr
{
	[self willChangeValueForKey:@"realJID"];
	[self willChangeValueForKey:@"realJIDStr"];
	
	self.primitiveRealJID = [XMPPJID jidWithString:realJIDStr];
	self.primitiveRealJIDStr = realJIDStr;
	
	[self didChangeValueForKey:@"realJID"];
	[self didChangeValueForKey:@"realJIDStr"];
}

@end
