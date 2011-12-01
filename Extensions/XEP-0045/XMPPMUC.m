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

- (BOOL)isMUCRoomElement:(XMPPElement *)element
{
	XMPPJID *bareFrom = [[element from] bareJID];
	if (bareFrom == nil)
	{
		return NO;
	}
	
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		result = [rooms containsObject:bareFrom];
		
	}};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

- (BOOL)isMUCRoomPresence:(XMPPPresence *)presence
{
	return [self isMUCRoomElement:presence];
}

- (BOOL)isMUCRoomMessage:(XMPPMessage *)message
{
	return [self isMUCRoomElement:message];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
