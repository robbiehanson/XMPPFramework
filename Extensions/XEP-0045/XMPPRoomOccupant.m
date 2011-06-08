//
// XMPPRoomOccupant
// A chat room. XEP-0045 Implementation.
//

#import "XMPPRoomOccupant.h"


@implementation XMPPRoomOccupant

+ (XMPPRoomOccupant *)occupantWithJID:(XMPPJID *)aJid nick:(NSString *)aNick role:(NSString *)aRole
{
	return [[[XMPPRoomOccupant alloc] initWithJID:aJid nick:aNick role:aRole] autorelease];
}

@dynamic jid;
@dynamic role;
@dynamic nick;

- (id)initWithJID:(XMPPJID *)aJid nick:(NSString *)aNick role:(NSString *)aRole
{
	if ((self = [super init]))
	{
		jid = [aJid copy];
		nick = [aNick copy];
		role = [aRole copy];
	}
	return self;
}

- (void)dealloc
{
	[jid release];
	[nick release];
	[role release];
	[super dealloc];
}

// Why are these here?
// Why not just let @synthesize do it for us?
// 
// Since these variables are readonly, their getters should act like nonatomic getters.
// However, using the label nonatomic on their property definitions is misleading,
// and might cause some to assume this class isn't thread-safe when, in fact, it is.

- (XMPPJID *)jid {
	return jid;
}

- (NSString *)nick {
	return nick;
}

- (NSString *)role {
	return role;
}

@end
