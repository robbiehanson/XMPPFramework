#import "XMPPRoom.h"
#import "XMPPMessage+XEP0045.h"
#import "XMPPLogging.h"


// Log levels: off, error, warn, info, verbose
// Log flags: trace
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

static NSString *const XMPPMUCNamespaceName      = @"http://jabber.org/protocol/muc";
static NSString *const XMPPMUCUserNamespaceName  = @"http://jabber.org/protocol/muc#user";
static NSString *const XMPPMUCOwnerNamespaceName = @"http://jabber.org/protocol/muc#owner";

@interface XMPPRoom ()
@property (readwrite, assign) BOOL isJoined;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPRoom

@dynamic roomName;
@dynamic nickName;
@dynamic subject;
@dynamic isJoined;
@dynamic occupants;
@dynamic invitedUser;

- (id)init
{
	// This will cause a crash - it's designed to.
	// Only the init methods listed in XMPPRoom.h are supported.
	
	return [self initWithRoomName:nil nickName:nil dispatchQueue:NULL];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	// This will cause a crash - it's designed to.
	// Only the init methods listed in XMPPRoom.h are supported.
	
	return [self initWithRoomName:nil nickName:nil dispatchQueue:NULL];
}

- (id)initWithRoomName:(NSString *)aRoomName nickName:(NSString *)aNickName
{
	return [self initWithRoomName:aRoomName nickName:aNickName dispatchQueue:NULL];
}

- (id)initWithRoomName:(NSString *)aRoomName nickName:(NSString *)aNickName dispatchQueue:(dispatch_queue_t)queue
{
	NSParameterAssert(aRoomName != nil);
	NSParameterAssert(aNickName != nil);
	
	if ((self = [super initWithDispatchQueue:queue]))
	{
		roomName = [aRoomName copy];
		nickName = [aNickName copy];
		
		occupants = [[NSMutableDictionary alloc] init];
		
		XMPPLogTrace2(@"%@: init -> roomName(%@) nickName(%@)", [self class], roomName, nickName);
	}
	return self;
}

- (BOOL)activate:(XMPPStream *)aXmppStream
{
	if ([super activate:aXmppStream])
	{
		// Custom code goes here (if needed)
		
		return YES;
	}
	
	return NO;
}

- (void)deactivate
{
	XMPPLogTrace();
	
	if (self.isJoined)
	{
		[self leaveRoom];
	}
	
	[super deactivate];
}

- (void)dealloc
{
	[roomName release];
	[nickName release];
	[subject release];
	[invitedUser release];
	[occupants release];
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)roomName
{
	if (dispatch_get_current_queue() == moduleQueue)
	{
		return roomName;
	}
	else
	{
		// This variable is readonly - set in init method and never changed.
		
		return [[roomName retain] autorelease];
	}
}

- (NSString *)nickName
{
	if (dispatch_get_current_queue() == moduleQueue)
	{
		return nickName;
	}
	else
	{
		// This variable is readonly - set in init method and never changed.
		
		return [[nickName retain] autorelease];
	}
}

- (NSString *)subject
{
	if (dispatch_get_current_queue() == moduleQueue)
	{
		return subject;
	}
	else
	{
		__block NSString *result;
		
		dispatch_sync(moduleQueue, ^{
			result = [subject retain];
		});
		
		return [result autorelease];
	}
}

- (BOOL)isJoined
{
	if (dispatch_get_current_queue() == moduleQueue)
	{
		return _isJoined;
	}
	else
	{
		__block BOOL result;
		
		dispatch_sync(moduleQueue, ^{
			result = _isJoined;
		});
		
		return result;
	}
}

- (void)setIsJoined:(BOOL)newIsJoined
{
	NSAssert(dispatch_get_current_queue() == moduleQueue, @"Invoked on incorrect queue");
	
	if (_isJoined != newIsJoined)
	{
		_isJoined = newIsJoined;
		
		if (newIsJoined)
			[multicastDelegate xmppRoomDidEnter:self];
		else
			[multicastDelegate xmppRoomDidLeave:self];
	}
}

- (NSDictionary *)occupants
{
	if (dispatch_get_current_queue() == moduleQueue)
	{
		return occupants;
	}
	else
	{
		__block NSDictionary *result;
		
		dispatch_sync(moduleQueue, ^{
			result = [occupants copy];
		});
		
		return [result autorelease];
	}
}

- (NSString *)invitedUser
{
	if (dispatch_get_current_queue() == moduleQueue)
	{
		return invitedUser;
	}
	else
	{
		__block NSString *result;
		
		dispatch_sync(moduleQueue, ^{
			result = [invitedUser retain];
		});
		
		return [result autorelease];
	}
}

- (void)setInvitedUser:(NSString *)newInvitedUser
{
	if (dispatch_get_current_queue() == moduleQueue)
	{
		if (![invitedUser isEqual:newInvitedUser])
		{
			[invitedUser release];
			invitedUser = [newInvitedUser retain];
		}
	}
	else
	{
		NSString *newInvitedUserCopy = [newInvitedUser copy];
		
		dispatch_async(moduleQueue, ^{
			
			if (![invitedUser isEqual:newInvitedUserCopy])
			{
				[invitedUser release];
				invitedUser = [newInvitedUserCopy retain];
			}
		});
		
		[newInvitedUserCopy release];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Room Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)createOrJoinRoom
{
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		XMPPLogTrace();
		
		// <presence to='darkcave@chat.shakespeare.lit/firstwitch'>
		//   <x xmlns='http://jabber.org/protocol/muc'/>
		// </presence>
		
		NSString *to = [NSString stringWithFormat:@"%@/%@", roomName, nickName];
		
		NSXMLElement *x = [NSXMLElement elementWithName:@"x" xmlns:XMPPMUCNamespaceName];
		
		XMPPPresence *presence = [XMPPPresence presence];
		[presence addAttributeWithName:@"to" stringValue:to];
		[presence addChild:x];
		
		[xmppStream sendElement:presence];
		
		[pool drain];
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)sendInstantRoomConfig
{
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		XMPPLogTrace();
		
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
		
		NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:XMPPMUCOwnerNamespaceName];
		[query addChild:x];
		
		XMPPIQ *iq = [XMPPIQ iq];
		[iq addAttributeWithName:@"id" stringValue:[NSString stringWithFormat:@"inroom-cr%@", roomName]];
		[iq addAttributeWithName:@"to" stringValue:roomName];
		[iq addAttributeWithName:@"type" stringValue:@"set"];
		[iq addChild:query];
		
		[xmppStream sendElement:iq];
		
		[pool drain];
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)joinRoom
{
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		XMPPLogTrace();
		
		// <presence to='darkcave@chat.shakespeare.lit/thirdwitch'/>
		
		NSString *to = [NSString stringWithFormat:@"%@/%@", roomName, nickName];
		
		XMPPPresence *presence = [XMPPPresence presence];
		[presence addAttributeWithName:@"to" stringValue:to];
		
		[xmppStream sendElement:presence];
		
		[pool drain];
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)leaveRoom
{
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		XMPPLogTrace();
		
		// <presence type='unavailable' to='darkcave@chat.shakespeare.lit/thirdwitch'/>
		
		NSString *to = [NSString stringWithFormat:@"%@/%@", roomName, nickName];
		
		XMPPPresence *presence = [XMPPPresence presence];
		[presence addAttributeWithName:@"to" stringValue:to];
		[presence addAttributeWithName:@"type" stringValue:@"unavailable"];
		
		[xmppStream sendElement:presence];
		self.isJoined = NO;
		
		[pool drain];
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
}

/**
 * Changes the nickname for room by joining room again with new nick.
**/
- (void)chageNickForRoom:(NSString *)newNickName
{
	NSString *newNickNameCopy = [newNickName copy];
	
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		XMPPLogTrace();
		
		if (![nickName isEqual:newNickNameCopy])
		{
			[nickName release];
			nickName = [newNickNameCopy retain];
			
			[self joinRoom];
		}
		
		[pool drain];
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
	
	[newNickNameCopy release];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark RoomInvite Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)inviteUser:(XMPPJID *)jid withMessage:(NSString *)inviteMessageStr
{
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
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
		
		NSXMLElement *reason = [NSXMLElement elementWithName:@"reason" stringValue:inviteMessageStr];
		
		NSXMLElement *invite = [NSXMLElement elementWithName:@"invite"];
		[invite addAttributeWithName:@"to" stringValue:[jid full]];
		[invite addChild:reason];
		
		NSXMLElement *x = [NSXMLElement elementWithName:@"x" xmlns:XMPPMUCUserNamespaceName];
		[x addChild:invite];
		
		XMPPMessage *message = [XMPPMessage message];
		[message addAttributeWithName:@"to" stringValue:roomName];
		[message addChild:x];
		
		[xmppStream sendElement:message];
		
		[pool drain];
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)acceptInvitation
{
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		XMPPLogTrace();
		
		// Just need to send presence to room to accept it. We are done.
		[self joinRoom];
		
		[pool drain];
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)rejectInvitation
{
	[self rejectInvitationWithMessage:nil];
}

- (void)rejectInvitationWithMessage:(NSString *)rejectMessageStr
{
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		XMPPLogTrace();
		
		// <message to='darkcave@chat.shakespeare.lit'>
		//   <x xmlns='http://jabber.org/protocol/muc#user'>
		//     <decline to='crone1@shakespeare.lit'>
		//       <reason>
		//         Sorry, I'm too busy right now.
		//       </reason>
		//     </decline>
		//   </x>
		// </message>
		
		NSXMLElement *reason = nil;
		if (rejectMessageStr)
		{
			reason = [NSXMLElement elementWithName:@"reason" stringValue:rejectMessageStr];
		}
		
		NSXMLElement *decline = [NSXMLElement elementWithName:@"decline"];
		[decline addAttributeWithName:@"to" stringValue:invitedUser];
		if (reason)
		{
			[decline addChild:reason];
		}
		
		NSXMLElement *x = [NSXMLElement elementWithName:@"x" xmlns:XMPPMUCUserNamespaceName];
		[x addChild:decline];
		
		NSXMLElement *message = [XMPPMessage message];
		[message addAttributeWithName:@"to" stringValue:roomName];
		[message addChild:x];
		
		[xmppStream sendElement:message];
		
		[pool drain];
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Message Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)sendMessage:(NSString *)msg
{
	if ([msg length] == 0) return;
	
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		XMPPLogTrace();
		
		// <message type='groupchat' to='darkcave@chat.shakespeare.lit/firstwitch'>
		//   <body>I'll give thee a wind.</body>
		// </message>
	
		NSXMLElement *body = [NSXMLElement elementWithName:@"body" stringValue:msg];
		
		XMPPMessage *message = [XMPPMessage message];
		[message addAttributeWithName:@"to" stringValue:roomName];
		[message addAttributeWithName:@"type" stringValue:@"groupchat"];
		[message addChild:body];
		
		[xmppStream sendElement:message];
		
		[pool drain];
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)onDidChangeOccupants
{
	// We cannot directly pass our NSMutableDictionary *occupants
	// to the delegates as NSMutableDictionary is not thread-safe.
	// 
	// And even if it was, we don't want this dictionary changing on them.
	// That's what this delegate method is for.
	// 
	// So we create an immutable copy of the dictionary to send to the delegates.
	// And we don't have to worry about the XMPPRoomOccupant objects changing as they are immutable.
	
	NSDictionary *occupantsCopy = [[occupants copy] autorelease];
	
	[multicastDelegate xmppRoom:self didChangeOccupants:occupantsCopy];
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
	// This method must be invoked on the moduleQueue
	NSAssert(dispatch_get_current_queue() == moduleQueue, @"Invoked on incorrect queue");
	
	NSArray *components = [[presence fromStr] componentsSeparatedByString:@"/"];
	
	NSString *aRoomName = [components count] > 0 ? [components objectAtIndex:0] : nil;
	NSString *aNickName = [components count] > 1 ? [components objectAtIndex:1] : nil;
	
	if (![aRoomName isEqualToString:roomName]) return;
	
	XMPPLogTrace2(@"%@: didReceivePresence: ROOM: %@", [self class], roomName);
	
	NSXMLElement *priorityElement = [presence elementForName:@"priority"];
	if (priorityElement)
		XMPPLogVerbose(@"%@: didReceivePresence: priority:%@", [self class], [priorityElement stringValue]);
	
	NSXMLElement *x = [presence elementForName:@"x" xmlns:XMPPMUCUserNamespaceName];
	NSXMLElement *xItem = [x elementForName:@"item"];
	
	NSString *jidStr  = [xItem attributeStringValueForName:@"jid"];
	NSString *role    = [xItem attributeStringValueForName:@"role"];
	NSString *newNick = [xItem attributeStringValueForName:@"nick"];
	
	XMPPLogVerbose(@"%@: didReceivePresence: nick:%@ role:%@ newnick:%@ jid:%@",
				   [self class], aNickName, role, newNick, jidStr);
	
	if (newNick)
	{
		// We are joined, getting presence for room
		self.isJoined = YES;
		
		// Handle nick Change having "nick" in <item> element.
		[occupants removeObjectForKey:aNickName];
		
		// Add new room occupant
		XMPPJID *jid = [XMPPJID jidWithString:jidStr];
		XMPPRoomOccupant *occupant = [XMPPRoomOccupant occupantWithJID:jid nick:newNick role:role];
		
		[occupants setObject:occupant forKey:newNick];
		[self onDidChangeOccupants];
		
		return;
	}
	else if (aNickName)
	{
		if ([[presence type] isEqualToString:@"unavailable"])
		{
			if ([aNickName isEqualToString:nickName])
			{
				// We got presence from our nick to us about leaving.
				self.isJoined = NO;
				
				[occupants removeAllObjects];
				[self onDidChangeOccupants];
			}
			else
			{
				// We're getting presence from the room, so that means we are joined
				self.isJoined = YES;
				
				// This is about some one else leaving the Room.
				// Remove them and notify delegate.
				
				[occupants removeObjectForKey:aNickName];
				[self onDidChangeOccupants];
			}
		}
		else
		{
			// We're getting presence from the room, so that means we are joined
			self.isJoined = YES;
			
			// This is about some sort of available presence. i don't mind even if they are busy.
			// if the user is there. no need to notify. let's check that.
			XMPPRoomOccupant *occupant = [occupants objectForKey:aNickName];
			if (!occupant)
			{
				XMPPJID *jid = [XMPPJID jidWithString:jidStr];
				occupant = [XMPPRoomOccupant occupantWithJID:jid nick:aNickName role:role];
				
				[occupants setObject:occupant forKey:aNickName];
				[self onDidChangeOccupants];
			}
		}
	}
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	// This method must be invoked on the moduleQueue
	NSAssert(dispatch_get_current_queue() == moduleQueue, @"Invoked on incorrect queue");
	
	// Check if its group chat, and make sure it's for this Room
	if ([message isGroupChatMessageWithBody])
	{
		NSArray *components = [[message fromStr] componentsSeparatedByString:@"/"];
		
		NSString *aRoomName = [components count] > 0 ? [components objectAtIndex:0] : nil;
		NSString *aNickName = [components count] > 1 ? [components objectAtIndex:1] : nil;
		
		if (![aRoomName isEqualToString:roomName]) return;
		
		if (aNickName == nil)
		{
			// Todo - A proper implementation...
			
		//	NSString *body = [[message elementForName:@"body"] stringValue];
		//	
		//	if ([body isEqualToString:@"This room is locked from entry until configuration is confirmed."])
		//	{
		//		[self sendInstantRoomConfig];
		//		return;
		//	}
		//	
		//	if ([body isEqualToString:@"This room is now unlocked."])
		//	{
		//		[multicastDelegate xmppRoomDidCreate:self];
		//		return;
		//	}
		}
		
		[multicastDelegate xmppRoom:self didReceiveMessage:message fromNick:aNickName];
	}
}

@end
