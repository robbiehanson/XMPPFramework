#import "XMPP.h"
#import "XMPPRoom.h"
#import "XMPPIDTracker.h"
#import "XMPPMessage+XEP0045.h"
#import "XMPPLogging.h"


// Log levels: off, error, warn, info, verbose
// Log flags: trace
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

enum XMPPRoomState
{
	kXMPPRoomStateNone        = 0,
	kXMPPRoomStateCreated     = 1 << 1,
	kXMPPRoomStateJoining     = 1 << 3,
	kXMPPRoomStateJoined      = 1 << 4,
	kXMPPRoomStateLeaving     = 1 << 5,
};

@interface XMPPRoom ()

// List private methods here

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPRoom

- (id)init
{
	// This will cause a crash - it's designed to.
	// Only the init methods listed in XMPPRoom.h are supported.
	
	return [self initWithRoomStorage:nil jid:nil dispatchQueue:NULL];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	// This will cause a crash - it's designed to.
	// Only the init methods listed in XMPPRoom.h are supported.
	
	return [self initWithRoomStorage:nil jid:nil dispatchQueue:queue];
}

- (id)initWithRoomStorage:(id <XMPPRoomStorage>)storage jid:(XMPPJID *)aRoomJID
{
	return [self initWithRoomStorage:storage jid:aRoomJID dispatchQueue:NULL];
}

- (id)initWithRoomStorage:(id <XMPPRoomStorage>)storage jid:(XMPPJID *)aRoomJID dispatchQueue:(dispatch_queue_t)queue
{
	NSParameterAssert(storage != nil);
	NSParameterAssert(aRoomJID != nil);
	
	if ((self = [super initWithDispatchQueue:queue]))
	{
		if ([storage configureWithParent:self queue:moduleQueue])
		{
			xmppRoomStorage = storage;
		}
		else
		{
			XMPPLogError(@"%@: %@ - Unable to configure storage!", THIS_FILE, THIS_METHOD);
		}
		
		roomJID = [aRoomJID bareJID];
	}
	return self;
}

- (BOOL)activate:(XMPPStream *)aXmppStream
{
	if ([super activate:aXmppStream])
	{
		responseTracker = [[XMPPIDTracker alloc] initWithDispatchQueue:moduleQueue];
		
		return YES;
	}
	
	return NO;
}

- (void)deactivate
{
	XMPPLogTrace();
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if (self.isJoined)
		{
			[self leaveRoom];
		}
		
		[responseTracker removeAllIDs];
		responseTracker = nil;
		
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	[super deactivate];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Internal
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method may optionally be used by XMPPRosterStorage classes (method declared in XMPPRosterPrivate.h)
**/
- (dispatch_queue_t)moduleQueue
{
	return moduleQueue;
}

/**
 * This method may optionally be used by XMPPRosterStorage classes (method declared in XMPPRosterPrivate.h).
**/
- (GCDMulticastDelegate *)multicastDelegate
{
	return multicastDelegate;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id <XMPPRoomStorage>)xmppRoomStorage
{
	// This variable is readonly - set in init method and never changed.
	return xmppRoomStorage;
}

- (XMPPJID *)roomJID
{
	// This variable is readonly - set in init method and never changed.
	return roomJID;
}

- (XMPPJID *)myRoomJID
{
	if (dispatch_get_specific(moduleQueueTag))
	{
		return myRoomJID;
	}
	else
	{
		__block XMPPJID *result;
		
		dispatch_sync(moduleQueue, ^{
			result = myRoomJID;
		});
		
		return result;
	}
}

- (NSString *)myNickname
{
	if (dispatch_get_specific(moduleQueueTag))
	{
		return myNickname;
	}
	else
	{
		__block NSString *result;
		
		dispatch_sync(moduleQueue, ^{
			result = myNickname;
		});
		
		return result;
	}
}

- (NSString *)roomSubject
{
	if (dispatch_get_specific(moduleQueueTag))
	{
		return roomSubject;
	}
	else
	{
		__block NSString *result;
		
		dispatch_sync(moduleQueue, ^{
			result = roomSubject;
		});
		
		return result;
	}
}

- (BOOL)isJoined
{
	__block BOOL result = 0;
	
	dispatch_block_t block = ^{
		result = (state & kXMPPRoomStateJoined) ? YES : NO;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}
/*
- (BOOL)isRoomOwner
{
	__block BOOL result;
	
	dispatch_block_t block = ^{
		
		id <XMPPRoomOccupant> myOccupant = [xmppRoomStorage occupantForJID:myRoomJID stream:xmppStream];
		
		result = [myOccupant.affiliation isEqualToString:@"owner"];
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}
*/

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Create & Join
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)preJoinWithNickname:(NSString *)nickname
{
	if ((state != kXMPPRoomStateNone) && (state != kXMPPRoomStateLeaving))
	{
		XMPPLogWarn(@"%@[%@] - Cannot create/join room when already creating/joining/joined", THIS_FILE, roomJID);
		
		return NO;
	}
	
	myNickname = [nickname copy];
	myRoomJID = [XMPPJID jidWithUser:[roomJID user] domain:[roomJID domain] resource:myNickname];
	
	return YES;
}

- (void)joinRoomUsingNickname:(NSString *)desiredNickname history:(NSXMLElement *)history
{
	[self joinRoomUsingNickname:desiredNickname history:history password:nil];
}

- (void)joinRoomUsingNickname:(NSString *)desiredNickname history:(NSXMLElement *)history password:(NSString *)passwd
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		XMPPLogTrace2(@"%@[%@] - %@", THIS_FILE, roomJID, THIS_METHOD);
		
		// Check state and update variables
		
		if (![self preJoinWithNickname:desiredNickname])
		{
			return;
		}
		
		// <presence to='darkcave@chat.shakespeare.lit/firstwitch'>
		//   <x xmlns='http://jabber.org/protocol/muc'/>
		//     <history/>
		//     <password>passwd</password>
		//   </x>
		// </presence>
		
		NSXMLElement *x = [NSXMLElement elementWithName:@"x" xmlns:XMPPMUCNamespace];
		if (history)
		{
			[x addChild:history];
		}
		if (passwd)
		{
			[x addChild:[NSXMLElement elementWithName:@"password" stringValue:passwd]];
		}
		
		XMPPPresence *presence = [XMPPPresence presenceWithType:nil to:myRoomJID];
		[presence addChild:x];
		
		[xmppStream sendElement:presence];
		
		state |= kXMPPRoomStateJoining;
		
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Room Configuration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)handleConfigurationFormResponse:(XMPPIQ *)iq withInfo:(id <XMPPTrackingInfo>)info
{
	XMPPLogTrace();
	
	if ([[iq type] isEqualToString:@"result"])
	{
		// <iq type='result'
		//     from='coven@chat.shakespeare.lit'
		//       id='create1'>
		//   <query xmlns='http://jabber.org/protocol/muc#owner'>
		//     <x xmlns='jabber:x:data' type='form'>
		//       <title>Configuration for "coven" Room</title>
		//       <field type='hidden'
		//               var='FORM_TYPE'>
		//         <value>http://jabber.org/protocol/muc#roomconfig</value>
		//       </field>
		//       <field label='Natural-Language Room Name'
		//               type='text-single'
		//                var='muc#roomconfig_roomname'/>
		//       <field label='Enable Public Logging?'
		//               type='boolean'
		//                var='muc#roomconfig_enablelogging'>
		//         <value>0</value>
		//       </field>
		//       ...
		//     </x>
		//   </query>
		// </iq>
		
		NSXMLElement *query = [iq elementForName:@"query" xmlns:XMPPMUCOwnerNamespace];
		NSXMLElement *x = [query elementForName:@"x" xmlns:@"jabber:x:data"];
		
		[multicastDelegate xmppRoom:self didFetchConfigurationForm:x];
	}
}

- (void)fetchConfigurationForm
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		XMPPLogTrace();
		
		// <iq type='get'
		//       id='config1'
		//       to='coven@chat.shakespeare.lit'>
		//   <query xmlns='http://jabber.org/protocol/muc#owner'/>
		// </iq>
		
		NSString *fetchID = [xmppStream generateUUID];
		
		NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:XMPPMUCOwnerNamespace];
		XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:roomJID elementID:fetchID child:query];
		
		[xmppStream sendElement:iq];
		
		[responseTracker addID:fetchID
		                target:self
		              selector:@selector(handleConfigurationFormResponse:withInfo:)
		               timeout:60.0];
		
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)handleConfigureRoomResponse:(XMPPIQ *)iq withInfo:(id <XMPPTrackingInfo>)info
{
	XMPPLogTrace();
	
	if ([[iq type] isEqualToString:@"result"])
	{
		[multicastDelegate xmppRoom:self didConfigure:iq];
	}
	else
	{
		[multicastDelegate xmppRoom:self didNotConfigure:iq];
	}
}

- (void)configureRoomUsingOptions:(NSXMLElement *)roomConfigForm
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		XMPPLogTrace();
		
		if (roomConfigForm)
		{
			// Explicit configuration using given form.
			// 
			// <iq type='set'
			//       id='create2'
			//       to='coven@chat.shakespeare.lit'>
			//   <query xmlns='http://jabber.org/protocol/muc#owner'>
			//     <x xmlns='jabber:x:data' type='submit'>
			//       <field var='FORM_TYPE'>
			//         <value>http://jabber.org/protocol/muc#roomconfig</value>
			//       </field>
			//       <field var='muc#roomconfig_roomname'>
			//         <value>A Dark Cave</value>
			//       </field>
			//       <field var='muc#roomconfig_enablelogging'>
			//         <value>0</value>
			//       </field>
			//       ...
			//     </x>
			//   </query>
			// </iq>
			
			NSXMLElement *x = roomConfigForm;
			[x addAttributeWithName:@"type" stringValue:@"submit"];
			
			NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:XMPPMUCOwnerNamespace];
			[query addChild:x];
			
			NSString *iqID = [xmppStream generateUUID];
			
			XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:roomJID elementID:iqID child:query];
			
			[xmppStream sendElement:iq];
			
			[responseTracker addID:iqID
			                target:self
			              selector:@selector(handleConfigureRoomResponse:withInfo:)
			               timeout:60.0];
		}
		else
		{
			// Default room configuration (as per server settings).
			// 
			// <iq type='set'
			//     from='crone1@shakespeare.lit/desktop'
			//       id='create1'
			//       to='darkcave@chat.shakespeare.lit'>
			//   <query xmlns='http://jabber.org/protocol/muc#owner'>
			//     <x xmlns='jabber:x:data' type='submit'/>
			//   </query>
			// </iq>
			
			NSXMLElement *x = [NSXMLElement elementWithName:@"x" xmlns:@"jabber:x:data"];
			[x addAttributeWithName:@"type" stringValue:@"submit"];
			
			NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:XMPPMUCOwnerNamespace];
			[query addChild:x];
			
			NSString *iqID = [xmppStream generateUUID];
			
			XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:roomJID elementID:iqID child:query];
			
			[xmppStream sendElement:iq];
			
			[responseTracker addID:iqID
			                target:self
			              selector:@selector(handleConfigureRoomResponse:withInfo:)
			               timeout:60.0];
		}
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)changeNickname:(NSString *)newNickname
{
	myOldNickname = [myNickname copy];
	myNickname = [newNickname copy];
    myRoomJID = [XMPPJID jidWithUser:[roomJID user] domain:[roomJID domain] resource:myNickname];
    XMPPPresence *presence = [XMPPPresence presenceWithType:nil to:myRoomJID];
    [xmppStream sendElement:presence];
}

- (void)changeRoomSubject:(NSString *)newRoomSubject
{
    NSXMLElement *subject = [NSXMLElement elementWithName:@"subject" stringValue:newRoomSubject];
    
    XMPPMessage *message = [XMPPMessage message];
    [message addAttributeWithName:@"from" stringValue:[myRoomJID full]];
    [message addChild:subject];
    
    [self sendMessage:message];
}

- (void)handleFetchBanListResponse:(XMPPIQ *)iq withInfo:(id <XMPPTrackingInfo>)info
{
	if ([[iq type] isEqualToString:@"result"])
	{
		// <iq type='result'
		//     from='southampton@henryv.shakespeare.lit'
		//       id='ban2'>
		//   <query xmlns='http://jabber.org/protocol/muc#admin'>
		//     <item affiliation='outcast' jid='earlofcambridge@shakespeare.lit'>
		//       <reason>Treason</reason>
		//     </item>
		//   </query>
		// </iq>
		
		NSXMLElement *query = [iq elementForName:@"query" xmlns:XMPPMUCAdminNamespace];
		NSArray *items = [query elementsForName:@"item"];
		
		[multicastDelegate xmppRoom:self didFetchBanList:items];
	}
	else
	{
		[multicastDelegate xmppRoom:self didNotFetchBanList:iq];
	}
}

- (void)fetchBanList
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		XMPPLogTrace();
		
		// <iq type='get'
		//       id='ban2'
		//       to='southampton@henryv.shakespeare.lit'>
		//   <query xmlns='http://jabber.org/protocol/muc#admin'>
		//     <item affiliation='outcast'/>
		//   </query>
		// </iq>
		
		NSString *fetchID = [xmppStream generateUUID];
		
		NSXMLElement *item = [NSXMLElement elementWithName:@"item"];
		[item addAttributeWithName:@"affiliation" stringValue:@"outcast"];
		
		NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:XMPPMUCAdminNamespace];
		[query addChild:item];
		
		XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:roomJID elementID:fetchID child:query];
		
		[xmppStream sendElement:iq];
		
		[responseTracker addID:fetchID
		               target:self
		             selector:@selector(handleFetchBanListResponse:withInfo:)
		              timeout:60.0];
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)handleFetchMembersListResponse:(XMPPIQ *)iq withInfo:(id <XMPPTrackingInfo>)info
{
	if ([[iq type] isEqualToString:@"result"])
	{
		// <iq type='result'
		//     from='coven@chat.shakespeare.lit'
		//       id='member3'>
		//   <query xmlns='http://jabber.org/protocol/muc#admin'>
		//     <item affiliation='member' jid='hag66@shakespeare.lit' nick='thirdwitch' role='participant'/>
		//   </query>
		// </iq>
		
		NSXMLElement *query = [iq elementForName:@"query" xmlns:XMPPMUCAdminNamespace];
		NSArray *items = [query elementsForName:@"item"];
		
		[multicastDelegate xmppRoom:self didFetchMembersList:items];
	}
	else
	{
		[multicastDelegate xmppRoom:self didNotFetchMembersList:iq];
	}
}

- (void)fetchMembersList
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		XMPPLogTrace();
		
		// <iq type='get'
		//       id='member3'
		//       to='coven@chat.shakespeare.lit'>
		//   <query xmlns='http://jabber.org/protocol/muc#admin'>
		//     <item affiliation='member'/>
		//   </query>
		// </iq>
		
		NSString *fetchID = [xmppStream generateUUID];
		
		NSXMLElement *item = [NSXMLElement elementWithName:@"item"];
		[item addAttributeWithName:@"affiliation" stringValue:@"member"];
		
		NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:XMPPMUCAdminNamespace];
		[query addChild:item];
		
		XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:roomJID elementID:fetchID child:query];
		
		[xmppStream sendElement:iq];
		
		[responseTracker addID:fetchID
		               target:self
		             selector:@selector(handleFetchMembersListResponse:withInfo:)
		              timeout:60.0];
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
	
	
}

- (void)handleFetchModeratorsListResponse:(XMPPIQ *)iq withInfo:(id <XMPPTrackingInfo>)info
{
	if ([[iq type] isEqualToString:@"result"])
	{
		// <iq type='result'
		//       id='mod3'
		//       to='crone1@shakespeare.lit/desktop'>
		//   <query xmlns='http://jabber.org/protocol/muc#admin'>
		//     <item affiliation='member' jid='hag66@shakespeare.lit/pda' nick='thirdwitch' role='moderator'/>
		//   </query>
		// </iq>
		
		NSXMLElement *query = [iq elementForName:@"query" xmlns:XMPPMUCAdminNamespace];
		NSArray *items = [query elementsForName:@"item"];
		
		[multicastDelegate xmppRoom:self didFetchModeratorsList:items];
	}
	else
	{
		[multicastDelegate xmppRoom:self didNotFetchModeratorsList:iq];
	}
}

- (void)fetchModeratorsList
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		// <iq type='get'
		//       id='mod3'
		//       to='coven@chat.shakespeare.lit'>
		//   <query xmlns='http://jabber.org/protocol/muc#admin'>
		//     <item role='moderator'/>
		//   </query>
		// </iq>
		
		NSString *fetchID = [xmppStream generateUUID];
		
		NSXMLElement *item = [NSXMLElement elementWithName:@"item"];
		[item addAttributeWithName:@"role" stringValue:@"moderator"];
		
		NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:XMPPMUCAdminNamespace];
		[query addChild:item];
		
		XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:roomJID elementID:fetchID child:query];
		
		[xmppStream sendElement:iq];
		
		[responseTracker addID:fetchID
		               target:self
		             selector:@selector(handleFetchModeratorsListResponse:withInfo:)
		              timeout:60.0];
		
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)handleEditRoomPrivilegesResponse:(XMPPIQ *)iq withInfo:(id <XMPPTrackingInfo>)info
{
	if ([[iq type] isEqualToString:@"result"])
	{
		[multicastDelegate xmppRoom:self didEditPrivileges:iq];
	}
	else
	{
		[multicastDelegate xmppRoom:self didNotEditPrivileges:iq];
	}
}

- (NSString *)editRoomPrivileges:(NSArray *)items
{
	NSString *iqID = [xmppStream generateUUID];
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		XMPPLogTrace();
		
		// <iq type='set'
		//       id='mod4'
		//       to='coven@chat.shakespeare.lit'>
		//   <query xmlns='http://jabber.org/protocol/muc#admin'>
		//     <item jid='hag66@shakespeare.lit/pda' role='participant'/>
		//     <item jid='hecate@shakespeare.lit/broom' role='moderator'/>
		//   </query>
		// </iq>
		
		NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:XMPPMUCAdminNamespace];
		for (NSXMLElement *item in items)
		{
			[query addChild:item];
		}
		
		XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:roomJID elementID:iqID child:query];
		
		[xmppStream sendElement:iq];
		
		[responseTracker addID:iqID
		                target:self
		              selector:@selector(handleEditRoomPrivilegesResponse:withInfo:)
		               timeout:60.0];
		
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
	
	return iqID;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Leave & Destroy
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)leaveRoom
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		XMPPLogTrace();
		
		// <presence type='unavailable' to='darkcave@chat.shakespeare.lit/thirdwitch'/>
		
		XMPPPresence *presence = [XMPPPresence presence];
		[presence addAttributeWithName:@"to" stringValue:[myRoomJID full]];
		[presence addAttributeWithName:@"type" stringValue:@"unavailable"];
		
		[xmppStream sendElement:presence];
		
		state &= ~kXMPPRoomStateJoining;
		state &= ~kXMPPRoomStateJoined;
		state |=  kXMPPRoomStateLeaving;
		
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)handleDestroyRoomResponse:(XMPPIQ *)iq withInfo:(id <XMPPTrackingInfo>)info
{
	XMPPLogTrace();
	
	if ([iq isResultIQ])
	{
		[multicastDelegate xmppRoomDidDestroy:self];
	}
	else
	{
		[multicastDelegate xmppRoom:self didFailToDestroy:iq];
	}
}

- (void)destroyRoom
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		XMPPLogTrace();
		
		// <iq type="set" to="roomName" id="abc123">
		//   <query xmlns="http://jabber.org/protocol/muc#owner">
		//     <destroy/>
		//   </query>
		// </iq>
		
		NSXMLElement *destroy = [NSXMLElement elementWithName:@"destroy"];
		
		NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:XMPPMUCOwnerNamespace];
		[query addChild:destroy];
		
		NSString *iqID = [xmppStream generateUUID];
		
		XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:roomJID elementID:iqID child:query];
		
		[xmppStream sendElement:iq];
		
		[responseTracker addID:iqID
			                target:self
			              selector:@selector(handleDestroyRoomResponse:withInfo:)
			               timeout:60.0];
		
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Messages
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)inviteUser:(XMPPJID *)jid withMessage:(NSString *)inviteMessageStr
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		XMPPLogTrace();
		
		// <message to='darkcave@chat.shakespeare.lit'>
		//   <x xmlns='http://jabber.org/protocol/muc#user'>
		//     <invite to='hecate@shakespeare.lit'>
		//       <reason>
		//         Hey Hecate, this is the place for all good witches!
		//       </reason>
		//     </invite>
		//   </x>
		// </message>
		
		NSXMLElement *invite = [NSXMLElement elementWithName:@"invite"];
		[invite addAttributeWithName:@"to" stringValue:[jid full]];
		
		if ([inviteMessageStr length] > 0)
		{
			[invite addChild:[NSXMLElement elementWithName:@"reason" stringValue:inviteMessageStr]];
		}
		
		NSXMLElement *x = [NSXMLElement elementWithName:@"x" xmlns:XMPPMUCUserNamespace];
		[x addChild:invite];
		
		XMPPMessage *message = [XMPPMessage message];
		[message addAttributeWithName:@"to" stringValue:[roomJID full]];
		[message addChild:x];
		
		[xmppStream sendElement:message];
		
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)sendMessage:(XMPPMessage *)message
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		XMPPLogTrace();
				
		[message addAttributeWithName:@"to" stringValue:[roomJID full]];
		[message addAttributeWithName:@"type" stringValue:@"groupchat"];
		
		[xmppStream sendElement:message];
		
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)sendMessageWithBody:(NSString *)messageBody
{
	if ([messageBody length] == 0) return;
		
	NSXMLElement *body = [NSXMLElement elementWithName:@"body" stringValue:messageBody];
	
	XMPPMessage *message = [XMPPMessage message];
	[message addChild:body];
	
	[self sendMessage:message];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	// This method is invoked on the moduleQueue.
	
	XMPPLogTrace();
	
	state = kXMPPRoomStateNone;
	
	// Auto-rejoin?
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	NSString *type = [iq type];
	
	if ([type isEqualToString:@"result"] || [type isEqualToString:@"error"])
	{
		return [responseTracker invokeForID:[iq elementID] withObject:iq];
	}
	
	return NO;
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
	// This method is invoked on the moduleQueue.
	
	XMPPJID *from = [presence from];
	
	if (![roomJID isEqualToJID:from options:XMPPJIDCompareBare])
	{
		return; // Stanza isn't for our room
	}
	
	XMPPLogTrace();
	
	[xmppRoomStorage handlePresence:presence room:self];
	
	// My presence:
	// 
	// <presence from='coven@chat.shakespeare.lit/thirdwitch'>
	//   <x xmlns='http://jabber.org/protocol/muc#user'>
	//     <item affiliation='member' role='participant'/>
	//     <status code='110'/>
	//     <status code='210'/>
	//   </x>
	// </presence>
	// 
	// 
	// Another's presence:
	// 
	// <presence from='coven@chat.shakespeare.lit/firstwitch'>
	//   <x xmlns='http://jabber.org/protocol/muc#user'>
	//     <item affiliation='owner' role='moderator'/>
	//   </x>
	// </presence>
	
	NSXMLElement *x = [presence elementForName:@"x" xmlns:XMPPMUCUserNamespace];
	
	// Process status codes.
	// 
	// 110 - Inform user that presence refers to one of its own room occupants.
	// 201 - Inform user that a new room has been created.
	// 210 - Inform user that service has assigned or modified occupant's roomnick.
	// 303 - Inform all occupants of new room nickname.
	
	BOOL isMyPresence = NO;
	BOOL didCreateRoom = NO;
	BOOL isNicknameChange = NO;
	
	for (NSXMLElement *status in [x elementsForName:@"status"])
	{
		switch ([status attributeIntValueForName:@"code"])
		{
			case 110 : isMyPresence = YES;     break;
			case 201 : didCreateRoom = YES;    break;
			case 210 :
			case 303 : isNicknameChange = YES; break;
		}
	}
	
	// Extract presence type
	
	NSString *presenceType = [presence type];
	
	BOOL isAvailable   = [presenceType isEqualToString:@"available"];
	BOOL isUnavailable = [presenceType isEqualToString:@"unavailable"];
	
	// Server's don't always properly send the statusCodes in every situation.
	// So we have some extra checks to ensure the boolean variables are correct.
	
	if (didCreateRoom)
	{
		isMyPresence = YES;
	}
	if (!isMyPresence)
	{
		if ([[from resource] isEqualToString:myNickname])
			isMyPresence = YES;
	}
	if (!isMyPresence && isNicknameChange && myOldNickname)
	{
		if ([[from resource] isEqualToString:myOldNickname]) {
			isMyPresence = YES;
			myOldNickname = nil;
		}
	}
	
	XMPPLogVerbose(@"%@[%@] - isMyPresence = %@", THIS_FILE, roomJID, (isMyPresence ? @"YES" : @"NO"));
	XMPPLogVerbose(@"%@[%@] - didCreateRoom = %@", THIS_FILE, roomJID, (didCreateRoom ? @"YES" : @"NO"));
	XMPPLogVerbose(@"%@[%@] - isNicknameChange = %@", THIS_FILE, roomJID, (isNicknameChange ? @"YES" : @"NO"));
	
	// Process presence
	
	if (didCreateRoom)
	{
		state |= kXMPPRoomStateCreated;
		
		[multicastDelegate xmppRoomDidCreate:self];
	}
	
	if (isMyPresence)
	{
		if (isAvailable)
		{
			myRoomJID = from;
			myNickname = [from resource];
            
			if (state & kXMPPRoomStateJoining)
			{
				state &= ~kXMPPRoomStateJoining;
				state |=  kXMPPRoomStateJoined;
				
				if ([xmppRoomStorage respondsToSelector:@selector(handleDidJoinRoom:withNickname:)])
					[xmppRoomStorage handleDidJoinRoom:self withNickname:myNickname];
				[multicastDelegate xmppRoomDidJoin:self];
			}
		}
		else if (isUnavailable && !isNicknameChange)
		{
			state = kXMPPRoomStateNone;
			[responseTracker removeAllIDs];
			
			[xmppRoomStorage handleDidLeaveRoom:self];
			[multicastDelegate xmppRoomDidLeave:self];
		}
	}
	else
	{
		if (isAvailable)
		{
			[multicastDelegate xmppRoom:self occupantDidJoin:from withPresence:presence];
		}
		else if (isUnavailable)
		{
			[multicastDelegate xmppRoom:self occupantDidLeave:from withPresence:presence];
		}
	}
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	// This method is invoked on the moduleQueue.
	
	XMPPJID *from = [message from];
	
	if (![roomJID isEqualToJID:from options:XMPPJIDCompareBare])
	{
		return; // Stanza isn't for our room
	}
	
	XMPPLogTrace();
	
	// Is this a message we need to store (a chat message)?
	// 
	// A message to all recipients MUST be of type groupchat.
	// A message to an individual recipient would have a <body/>.
	
	BOOL isChatMessage;
	
	if ([from isFull])
		isChatMessage = [message isGroupChatMessageWithBody];
	else
		isChatMessage = [message isMessageWithBody];
	
	if (isChatMessage)
	{
		[xmppRoomStorage handleIncomingMessage:message room:self];
		[multicastDelegate xmppRoom:self didReceiveMessage:message fromOccupant:from];
	}
    else if ([message isGroupChatMessageWithSubject])
    {
        roomSubject = [message subject];
    }
	else
	{
		// Todo... Handle other types of messages.
	}
}

- (void)xmppStream:(XMPPStream *)sender didSendMessage:(XMPPMessage *)message
{
	// This method is invoked on the moduleQueue.
	
	XMPPJID *to = [message to];
	
	if (![roomJID isEqualToJID:to options:XMPPJIDCompareBare])
	{
		return; // Stanza isn't for our room
	}
	
	XMPPLogTrace();
	
	// Is this a message we need to store (a chat message)?
	// 
	// A message to all recipients MUST be of type groupchat.
	// A message to an individual recipient would have a <body/>.
	
	BOOL isChatMessage;
	
	if ([to isFull])
		isChatMessage = [message isGroupChatMessageWithBody];
	else
		isChatMessage = [message isMessageWithBody];
	
	if (isChatMessage)
	{
		[xmppRoomStorage handleOutgoingMessage:message room:self];	
	}
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
	// This method is invoked on the moduleQueue.
	
	XMPPLogTrace();
	
	state = kXMPPRoomStateNone;
	[responseTracker removeAllIDs];
	
	[xmppRoomStorage handleDidLeaveRoom:self];
	[multicastDelegate xmppRoomDidLeave:self];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Class Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSXMLElement *)itemWithAffiliation:(NSString *)affiliation jid:(XMPPJID *)jid
{
	NSXMLElement *item = [NSXMLElement elementWithName:@"item"];
	
	if (affiliation)
		[item addAttributeWithName:@"affiliation" stringValue:affiliation];
	
	if (jid)
		[item addAttributeWithName:@"jid" stringValue:[jid full]];
	
	return item;
}

+ (NSXMLElement *)itemWithRole:(NSString *)role jid:(XMPPJID *)jid
{
	NSXMLElement *item = [NSXMLElement elementWithName:@"item"];
	
	if (role)
		[item addAttributeWithName:@"role" stringValue:role];
	
	if (jid)
		[item addAttributeWithName:@"jid" stringValue:[jid full]];
	
	return item;
}

@end
