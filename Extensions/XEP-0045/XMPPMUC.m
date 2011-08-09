#import "XMPPMUC.h"
#import "XMPPRoom.h"


@implementation XMPPMUC

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	if ((self = [super initWithDispatchQueue:queue]))
	{
		rooms = [[NSMutableSet alloc] init];
	}
	return self;
}

- (BOOL)isMUCRoomPresence:(XMPPPresence *)presence
{
	__block BOOL result;
	
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		XMPPJID *bareFrom = [[presence from] bareJID];
		
		result = [rooms containsObject:bareFrom];
		
		[pool drain];
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

- (void)xmppStream:(XMPPStream *)sender didRegisterModule:(id)module
{
	if ([module isKindOfClass:[XMPPRoom class]])
	{
		XMPPRoom *room = (XMPPRoom *)module;
		
		[rooms addObject:room.roomJID];
	}
}

- (void)xmppStream:(XMPPStream *)sender willUnregisterModule:(id)module
{
	if ([module isKindOfClass:[XMPPRoom class]])
	{
		XMPPRoom *room = (XMPPRoom *)module;
		
		[rooms removeObject:room.roomJID];
	}
}

@end
