#import "XMPPRoom.h"

#import "XMPPMessage+XEP0045.h"
#import "XMPPStream.h"
#import "XMPPJID.h"

@interface XMPPRoom ()
- (void)sendInstantRoomConfig;
@end

static NSString *const XMPPMUCNamespaceName = @"http://jabber.org/protocol/muc";
static NSString *const XMPPMUCUserNamespaceName = @"http://jabber.org/protocol/muc#user";
static NSString *const XMPPMUCOwnerNamespaceName = @"http://jabber.org/protocol/muc#owner";

@implementation XMPPRoom
@synthesize stream;
@synthesize roomName, nickName, subject;
@synthesize isJoined;
@synthesize occupants;

/////////////////////////////////////////////////
#pragma mark Constructor Methods
/////////////////////////////////////////////////

- (id)init
{
	NSAssert(NO, @"Do not alloc XMPPRoom. Use -initWithStream:roomName:");
	return nil;
}

// initializes a room for given room name and for nick name.
// Provide Room Name as [name]@conference.[yourhostname] as Input.
- (id)initWithStream:(XMPPStream *)aStream roomName:(NSString *)name nickName:(NSString *)nickname
{
	if((self = [super init]))
	{
		stream = [aStream retain];
		roomName = [name retain];
		nickName = [nickname retain];
		[stream addDelegate:self];
		occupants = [NSMutableDictionary new];
		NSLog(@"[XMPPRoom] initWithStream:roomName:%@ nick:%@",roomName,nickName);
	}
	return self;
}

/////////////////////////////////////////////////
#pragma mark Properties
/////////////////////////////////////////////////

- (XMPPStream *)stream {
	return stream;
}

- (NSString *)roomName {
	return roomName;
}

- (NSString *)nickname {
	return nickName;
}

- (NSString *)subject {
	return subject;
}

- (BOOL)isJoined {
	return isJoined;
}

- (NSMutableDictionary *)occupants {
	return occupants;
}

- (NSString *)invitedUser {
	return invitedUser;
}

- (void)setInvitedUser:(NSString *)ainvitedUser {
	if (invitedUser) [invitedUser release];
	invitedUser = [ainvitedUser retain];
}

/////////////////////////////////////////////////
#pragma mark Class Accessors
/////////////////////////////////////////////////

- (void)setDelegate:(id)aDelegate
{
	delegate = aDelegate; // weak
}

- (id)delegate
{
	return delegate;
}

/////////////////////////////////////////////////
#pragma mark Room Methods
/////////////////////////////////////////////////
// Creates a temporary Chat Room at Server.
- (void)createOrJoinRoom {
	if ([stream isConnected]) {
//		<presence
//		from='crone1@shakespeare.lit/desktop'
//		to='darkcave@chat.shakespeare.lit/firstwitch'>
//			<x xmlns='http://jabber.org/protocol/muc'/>
//		</presence>
		
		NSXMLElement *presence = [NSXMLElement elementWithName:@"presence"];
		[presence addAttributeWithName:@"from" stringValue:[[stream myJID]full]];
		[presence addAttributeWithName:@"to" stringValue:[NSString stringWithFormat:@"%@/%@", roomName, nickName]];
		NSXMLElement *xelement = [NSXMLElement elementWithName:@"x" xmlns:XMPPMUCNamespaceName];
		[presence addChild:xelement];
		[stream sendElement:presence];
	}
}
- (void)sendInstantRoomConfig {
//	<iq from='crone1@shakespeare.lit/desktop'
//    id='create1'
//    to='darkcave@chat.shakespeare.lit'
//    type='set'>
//	<query xmlns='http://jabber.org/protocol/muc#owner'>
//    <x xmlns='jabber:x:data' type='submit'/>
//	</query>
//	</iq>
	NSLog(@"[XMPPRoom] sendInstantRoomConfig:");
	NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
	[iq addAttributeWithName:@"id" stringValue:[NSString stringWithFormat:@"inroom-cr%@",roomName]];
	[iq addAttributeWithName:@"to" stringValue:roomName];
	[iq addAttributeWithName:@"type" stringValue:@"set"];
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:XMPPMUCOwnerNamespaceName];
	NSXMLElement *xelem = [NSXMLElement elementWithName:@"x" xmlns:@"jabber:x:data"];
	[xelem addAttributeWithName:@"type" stringValue:@"submit"];
	[query addChild:xelem];
	[iq addChild:query];
	[stream sendElement:iq]; 
}
// Joins the room by sending presence with nickname.
- (void)joinRoom {
	if ([stream isConnected]) {
		
//		<presence
//		from='hag66@shakespeare.lit/pda'
//		to='darkcave@chat.shakespeare.lit/thirdwitch'/>
		
		NSLog(@"[XMPPRoom] joinRoom: %@", roomName);
		NSXMLElement *presence = [NSXMLElement elementWithName:@"presence"];
		[presence addAttributeWithName:@"from" stringValue:[[stream myJID]full]];
		[presence addAttributeWithName:@"to" stringValue:[NSString stringWithFormat:@"%@/%@", roomName, nickName]];
		[stream sendElement:presence];
	}
}
// Leaves the chat room by sending presence as unavailable.
- (void)leaveRoom {
	if ([stream isConnected]) {
		NSLog(@"[XMPPRoom] leaveRoom: %@", roomName);
//		<presence
//		from='hag66@shakespeare.lit/pda'
//		to='darkcave@chat.shakespeare.lit/thirdwitch'
//		type='unavailable'/>
		
		NSXMLElement *presence = [NSXMLElement elementWithName:@"presence"];
		[presence addAttributeWithName:@"from" stringValue:[[stream myJID]full]];
		[presence addAttributeWithName:@"to" stringValue:[NSString stringWithFormat:@"%@/%@", roomName, nickName]];
		[presence addAttributeWithName:@"type" stringValue:@"unavailable"];
		[stream sendElement:presence];
		isJoined = NO;
	}
}
// Changes the nickname for room by joining room again with new nick.
- (void)chageNickForRoom:(NSString *)name {
	NSLog(@"[XMPPRoom] changeNick: %@", roomName);
	if (nickName) [nickName release];
	nickName = [name retain];
	[self joinRoom];
}
/////////////////////////////////////////////////
#pragma mark RoomInvite Methods
/////////////////////////////////////////////////
// Invites a user to room with Message.
- (void)inviteUser:(XMPPJID *)jid message:(NSString *)message {
	NSLog(@"[XMPPRoom] inviteUser:");
//	<message
//    from='crone1@shakespeare.lit/desktop'
//    to='darkcave@chat.shakespeare.lit'>
//		<x xmlns='http://jabber.org/protocol/muc#user'>
//			<invite to='hecate@shakespeare.lit'>
//				<reason>
//					Hey Hecate, this is the place for all good witches!
//				</reason>
//			</invite>
//		</x>
//	</message>
	if ([stream isConnected]) {
		NSXMLElement *imessage = [NSXMLElement elementWithName:@"message"];
		[imessage addAttributeWithName:@"from" stringValue:[[stream myJID]full]];
		[imessage addAttributeWithName:@"to" stringValue:roomName];
		
		NSXMLElement *xelem = [NSXMLElement elementWithName:@"x" xmlns:XMPPMUCUserNamespaceName];
		
		NSXMLElement *invite = [NSXMLElement elementWithName:@"invite"];
		[invite addAttributeWithName:@"to" stringValue:[jid full]];
		NSXMLElement *reason = [NSXMLElement elementWithName:@"reason"];
		[reason setStringValue:message];
		[invite addChild:reason];
		
		[xelem addChild:invite];
		
		[imessage addChild:xelem];
		
		[stream sendElement:imessage];
	}
}

- (void)acceptInvitation {
	NSLog(@"[XMPPRoom] acceptInvitation:");
	// just need to send presence to room to accept it. we are done.
	[self joinRoom];
}

- (void)rejectInvitation {
	NSLog(@"[XMPPRoom] rejectInvitation:");
//	<message
//    from='hecate@shakespeare.lit/broom'
//    to='darkcave@chat.shakespeare.lit'>
//		<x xmlns='http://jabber.org/protocol/muc#user'>
//			<decline to='crone1@shakespeare.lit'>
//				<reason>
//					Sorry, I'm too busy right now.
//				</reason>
//			</decline>
//		</x>
//	</message>
	
	if ([stream isConnected]) {
		NSXMLElement *imessage = [NSXMLElement elementWithName:@"message"];
		[imessage addAttributeWithName:@"from" stringValue:[[stream myJID]full]];
		[imessage addAttributeWithName:@"to" stringValue:roomName];
		
		NSXMLElement *xelem = [NSXMLElement elementWithName:@"x" xmlns:XMPPMUCUserNamespaceName];
		
		NSXMLElement *decline = [NSXMLElement elementWithName:@"decline"];
		[decline addAttributeWithName:@"to" stringValue:invitedUser];
		NSXMLElement *reason = [NSXMLElement elementWithName:@"reason"];
		[reason setStringValue:@"Sorry Dear, I can not join right now."];
		[decline addChild:reason];
		
		[xelem addChild:decline];
		
		[imessage addChild:xelem];
	}
}
/////////////////////////////////////////////////
#pragma mark Message Methods
/////////////////////////////////////////////////

- (void)sendMessage:(NSString *)msg {
	if (!(msg.length > 0)) return;
//	<message
//    from='wiccarocks@shakespeare.lit/laptop'
//    to='darkcave@chat.shakespeare.lit/firstwitch'
//    type='groupchat'>
//		<body>I'll give thee a wind.</body>
//	</message>
	if ([stream isConnected]) {
		NSXMLElement *body = [NSXMLElement elementWithName:@"body"];
		[body setStringValue:msg];
		
		NSXMLElement *message = [NSXMLElement elementWithName:@"message"];
		[message addAttributeWithName:@"to" stringValue:roomName];
		[message addAttributeWithName:@"type" stringValue:@"groupchat"];
		[message addChild:body];
		
		[stream sendElement:message];
	}
}

/////////////////////////////////////////////////
#pragma mark XMPPStreamDelegate Methods
/////////////////////////////////////////////////

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq {
	NSLog(@"[XMPPRoom] xmppStream:didReceiveIQ:");
	return NO;
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence {
	NSArray *roomNick = [[presence fromStr] componentsSeparatedByString:@"/"];
	NSString *aroomname = [roomNick objectAtIndex:0];
	NSString *anick = [roomNick objectAtIndex:1];
	if (![aroomname isEqualToString:roomName]) return;
	NSLog(@"[XMPPRoom] didReceivePresence: ROOM: %@", aroomname);
	NSXMLElement *priorityElement = [presence elementForName:@"priority"];
	NSXMLElement *xmucElement = [presence elementForName:@"x" xmlns:XMPPMUCUserNamespaceName];
	NSXMLElement *xmucItemElement = [xmucElement elementForName:@"item"];
	NSString *jid = [xmucItemElement attributeStringValueForName:@"jid"];
	NSString *role = [xmucItemElement attributeStringValueForName:@"role"];
	NSString *newnick = [xmucItemElement attributeStringValueForName:@"nick"];
	if (priorityElement)
	NSLog(@"[XMPPRoom] didReceivePresence: priority:%@",[priorityElement stringValue]);
	NSLog(@"[XMPPRoom] didReceivePresence: nick:%@ role:%@ newnick:%@ jid:%@", anick, role, newnick, jid);
	
	if (newnick) {
		isJoined = YES; // we are joined, getting presence for room
		// Handle nick Change having "nick" in <item> element.
		[occupants removeObjectForKey:anick];
		// add new room occupant
		XMPPRoomOccupant *aoccupant = [[XMPPRoomOccupant alloc] init];
		[aoccupant setNick:newnick];
		[aoccupant setRole:role];
		if (jid) [aoccupant setJid:[XMPPJID jidWithString:jid]];
		[occupants setObject:aoccupant forKey:newnick]; [aoccupant release];
		// oh its a change. let's notify delegate now..
		if ([delegate respondsToSelector:@selector(xmppRoom:didChangeOccupants:)])
			[delegate xmppRoom:self didChangeOccupants:occupants];	
		return;
	} else if (anick) {
		// Handle room leaving if with presence type "unavailable"
		// for my Nick name.
		if ([[presence type] isEqualToString:@"unavailable"] && [anick isEqualToString:nickName]) {
			// we got presence from our nick to us about leaving. Notify Delegate.
			[occupants removeAllObjects];
			isJoined = NO; // we left the room.
			if ([delegate respondsToSelector:@selector(xmppRoom:didLeave:)])
				[delegate xmppRoom:self didLeave:YES];
			// notify delegate about my leave as well. why not we can join back if we want.
			if ([delegate respondsToSelector:@selector(xmppRoom:didChangeOccupants:)])
				[delegate xmppRoom:self didChangeOccupants:occupants];
		} else if ([[presence type] isEqualToString:@"unavailable"]) {
			isJoined = YES; // we are joined, getting presence for room
			// this is about some one else leaving the Room. let's remove him
			[occupants removeObjectForKey:anick];
			if ([delegate respondsToSelector:@selector(xmppRoom:didChangeOccupants:)])
				[delegate xmppRoom:self didChangeOccupants:occupants];
		} else { 
			isJoined = YES; // we are joined, getting presence for room
			// this is about some sort of available presence. i don't mind even if they are busy.
			// if the user is there. no need to notify. let's check that.
			XMPPRoomOccupant *aoccupant = nil;
			aoccupant = (XMPPRoomOccupant *)[occupants objectForKey:anick];
			if (aoccupant) return;
			aoccupant = [[XMPPRoomOccupant alloc] init];
			[aoccupant setNick:anick];
			[aoccupant setRole:role];
			if (jid) [aoccupant setJid:[XMPPJID jidWithString:jid]];
			[occupants setObject:aoccupant forKey:anick]; [aoccupant release];
			// let's notify delegate now..
			if ([delegate respondsToSelector:@selector(xmppRoom:didChangeOccupants:)])
				[delegate xmppRoom:self didChangeOccupants:occupants];
		}

	}
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message {
	// check if its group chat. and make sure that's for this Room as well..
	if ([message isGroupChatMessageWithBody]) {
		NSArray *roomNick = [[message fromStr] componentsSeparatedByString:@"/"];
		NSString *aroomname = [roomNick objectAtIndex:0];
		if (![aroomname isEqualToString:roomName]) return;
		NSString *anick = nil;
		// get nick name and message body if available for room message.
		if(roomNick.count > 1) anick = [roomNick objectAtIndex:1];
		NSString *body = [[message elementForName:@"body"] stringValue];
		// this is a message from group.
		if (roomNick.count == 1) {
			// This room is locked from entry until configuration is confirmed.
			if ([body isEqualToString:@"This room is locked from entry until configuration is confirmed."]) {
				NSLog(@"[XMPPRoom] This room is locked from entry until configuration is confirmed.");
				[self sendInstantRoomConfig];
				return;
			}
			// This room is now unlocked.
			if ([body isEqualToString:@"This room is now unlocked."]) {
				NSLog(@"[XMPPRoom] This room is now unlocked.");
				// notify delegate about room creation success.
				if ([delegate respondsToSelector:@selector(xmppRoom:didEnter:)])
					[delegate xmppRoom:self didEnter:YES];
				return;
			}
		}
		NSLog(@"[XMPPRoom] didReceiveMessage: room:%@ nick:%@ body:%@", aroomname, anick, body);
		// let's notify delegate now..
		if ([delegate respondsToSelector:@selector(xmppRoom:didReceiveMessage:fromNick:)])
			[delegate xmppRoom:self didReceiveMessage:body fromNick:anick];
	}
}

/////////////////////////////////////////////////
#pragma mark Destructor Methods
/////////////////////////////////////////////////

- (void) dealloc
{
	if (isJoined)
	{
		[self leaveRoom];
	}
	[stream removeDelegate:self];
	
	[roomName release]; roomName = nil;
	[nickName release]; nickName = nil;
	[subject release]; subject = nil;
	[invitedUser release]; invitedUser = nil;
	[occupants release]; occupants = nil;
	[stream release]; stream = nil;
	[super dealloc];
}

@end
