#import "XMPPMUC.h"
#import "XMPPFramework.h"


@implementation XMPPMUC

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	if ((self = [super initWithDispatchQueue:queue]))
	{
		rooms = [[NSMutableSet alloc] init];
	}
	return self;
}

- (BOOL)activate:(XMPPStream *)aXmppStream
{
	if ([super activate:aXmppStream])
	{
#ifdef _XMPP_CAPABILITIES_H
		[xmppStream autoAddDelegate:self delegateQueue:moduleQueue toModulesOfClass:[XMPPCapabilities class]];
#endif
		return YES;
	}
	
	return NO;
}

- (void)deactivate
{
#ifdef _XMPP_CAPABILITIES_H
	[xmppStream removeAutoDelegate:self delegateQueue:moduleQueue fromModulesOfClass:[XMPPCapabilities class]];
#endif
	
	[super deactivate];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Public API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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

#ifdef _XMPP_CAPABILITIES_H
/**
 * If an XMPPCapabilites instance is used we want to advertise our support for MUC.
**/
- (void)xmppCapabilities:(XMPPCapabilities *)sender collectingMyCapabilities:(NSXMLElement *)query
{
	// This method is invoked on our moduleQueue.
	
	// <query xmlns="http://jabber.org/protocol/disco#info">
	//   ...
	//   <feature var='http://jabber.org/protocol/muc'/>
	//   ...
	// </query>
	
	NSXMLElement *feature = [NSXMLElement elementWithName:@"feature"];
	[feature addAttributeWithName:@"var" stringValue:@"http://jabber.org/protocol/muc"];
	
	[query addChild:feature];
}
#endif

@end
