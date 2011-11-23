//
// XMPPRoomOccupant
// A chat room. XEP-0045 Implementation.
//

#import "XMPPRoomOccupant.h"
#import "XMPPJID.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif


@implementation XMPPRoomOccupant

+ (XMPPRoomOccupant *)occupantWithJID:(XMPPJID *)aJid nick:(NSString *)aNick role:(NSString *)aRole
{
	return [[XMPPRoomOccupant alloc] initWithJID:aJid nick:aNick role:aRole];
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
