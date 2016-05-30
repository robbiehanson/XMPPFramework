//
//  XMPPRoomLight.m
//  Mangosta
//
//  Created by Andres Canal on 5/27/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

#import "XMPPRoomLight.h"
static NSString *const XMPPRoomLightAffiliations = @"urn:xmpp:muclight:0#affiliations";

enum XMPPRoomLightState
{
	kXMPPRoomLightStateNone        = 0,
	kXMPPRoomLightStateCreated     = 1 << 1,
	kXMPPRoomStateLeaving          = 1 << 2,
	kXMPPRoomStateLeft             = 1 << 3
};

@implementation XMPPRoomLight

- (id)initWithJID:(XMPPJID *)jid roomname:(NSString *) roomname {
	if ((self = [super initWithDispatchQueue:nil]))
	{
		_domain = jid.domain;
		_roomname = roomname;
		_roomJID = jid;
		state = kXMPPRoomLightStateNone;
	}
	return self;
}

- (id)initWithDomain:(NSString *)domain {

	if ((self = [super initWithDispatchQueue:nil]))
	{
		_domain = domain;
		state = kXMPPRoomLightStateNone;
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
	dispatch_block_t block = ^{ @autoreleasepool {
		[responseTracker removeAllIDs];
		responseTracker = nil;
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	[super deactivate];
}

- (void)createRoomLight:(NSString *)roomName members:(NSArray *) members {
	
	//		<iq from='crone1@shakespeare.lit/desktop'
	//			      id='create1'
	//			      to='coven@muclight.shakespeare.lit'
	//			    type='set'>
	//			<query xmlns='urn:xmpp:muclight:0#create'>
	//				<configuration>
	//					<roomname>A Dark Cave</roomname>
	//				</configuration>
	//				<occupants>
	//					<user affiliation='member'>user1@shakespeare.lit</user>
	//					<user affiliation='member'>user2@shakespeare.lit</user>
	//				</occupants>
	//			</query>
	//		</iq>
	
	dispatch_block_t block = ^{ @autoreleasepool {
		_roomJID = [XMPPJID jidWithUser:[XMPPStream generateUUID]
									 domain:self.domain
								   resource:nil];
		
		NSString *iqID = [XMPPStream generateUUID];
		NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
		[iq addAttributeWithName:@"id" stringValue:iqID];
		[iq addAttributeWithName:@"to" stringValue:self.roomJID.full];
		[iq addAttributeWithName:@"type" stringValue:@"set"];
		
		NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"urn:xmpp:muclight:0#create"];
		NSXMLElement *configuration = [NSXMLElement elementWithName:@"configuration"];
		[configuration addChild:[NSXMLElement elementWithName:@"roomname" stringValue:roomName]];
		
		NSXMLElement *ocupants = [NSXMLElement elementWithName:@"ocupants"];
		for (XMPPJID *jid in members){
			NSXMLElement *userElement = [NSXMLElement elementWithName:@"user" stringValue:jid.bare];
			[userElement addAttributeWithName:@"affiliation" stringValue:@"member"];
			[ocupants addChild:userElement];
		}
		
		[query addChild:configuration];
		[query addChild:ocupants];
		
		[iq addChild:query];
		
		[responseTracker addID:iqID
						target:self
					  selector:@selector(handleCreateRoomLight:withInfo:)
					   timeout:60.0];
		
		[xmppStream sendElement:iq];
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)handleCreateRoomLight:(XMPPIQ *)iq withInfo:(id <XMPPTrackingInfo>)info{
	if ([[iq type] isEqualToString:@"result"]){
		state = kXMPPRoomLightStateCreated;
		[multicastDelegate xmppRoomLight:self didCreatRoomLight:iq];
	}else{
		[multicastDelegate xmppRoomLight:self didFailToCreateRoomLight:iq];
	}
}

- (void)leaveRoomLight{
	
	//		<iq from='crone1@shakespeare.lit/desktop'
	//				id='member2'
	//				to='coven@chat.shakespeare.lit'
	//				type='set'>
	//			<query xmlns='http://jabber.org/protocol/muc#admin'>
	//				<item affiliation='none' jid='hag66@shakespeare.lit'/>
	//			</query>
	//		</iq>
	
	dispatch_block_t block = ^{ @autoreleasepool {
		state = kXMPPRoomStateLeaving;
		
		NSString *iqID = [XMPPStream generateUUID];
		NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
		[iq addAttributeWithName:@"id" stringValue:iqID];
		[iq addAttributeWithName:@"to" stringValue:self.roomJID.full];
		[iq addAttributeWithName:@"type" stringValue:@"set"];
		
		NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"urn:xmpp:muclight:0#affiliations"];
		NSXMLElement *user = [NSXMLElement elementWithName:@"user"];
		[user addAttributeWithName:@"affiliation" stringValue:@"none"];
		user.stringValue = xmppStream.myJID.bare;
		
		[query addChild:user];
		[iq addChild:query];
		
		[responseTracker addID:iqID
						target:self
					  selector:@selector(handleLeaveRoomLight:withInfo:)
					   timeout:60.0];
		
		[xmppStream sendElement:iq];
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)handleLeaveRoomLight:(XMPPIQ *)iq withInfo:(id <XMPPTrackingInfo>)info{
	if ([[iq type] isEqualToString:@"result"]){
		state = kXMPPRoomStateLeft;
		[multicastDelegate xmppRoomLight:self didLeaveRoomLight:iq];
	}else{
		[multicastDelegate xmppRoomLight:self didFailToLeaveRoomLight:iq];
	}
}


- (void)addUsers:(NSArray *)users{
	
	//    <iq from="crone1@shakespeare.lit/desktop"
	//          id="member1"
	//          to="coven@chat.shakespeare.lit"
	//        type="set">
	//       <query xmlns="http://jabber.org/protocol/muc#admin">
	//          <item affiliation="member" jid="hag66@shakespeare.lit" />
	//       </query>
	//    </iq>
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		NSString *iqID = [XMPPStream generateUUID];
		NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
		[iq addAttributeWithName:@"id" stringValue:iqID];
		[iq addAttributeWithName:@"to" stringValue:self.roomJID.full];
		[iq addAttributeWithName:@"type" stringValue:@"set"];
		
		
		for (XMPPJID *userJID in users) {
			NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"urn:xmpp:muclight:0#affiliations"];
			NSXMLElement *user = [NSXMLElement elementWithName:@"user"];
			[user addAttributeWithName:@"affiliation" stringValue:@"member"];
			user.stringValue = userJID.full;
			
			[query addChild:user];
			[iq addChild:query];
		}
		
		[xmppStream sendElement:iq];
		[responseTracker addID:iqID
						target:self
					  selector:@selector(handleAddUsers:withInfo:)
					   timeout:60.0];
	}};
	
	if (dispatch_get_specific(moduleQueueTag)){
		block();
	}else{
		dispatch_async(moduleQueue, block);
	}
}

- (void)handleAddUsers:(XMPPIQ *)iq withInfo:(id <XMPPTrackingInfo>)info{
	if ([[iq type] isEqualToString:@"result"]){
		[multicastDelegate xmppRoomLight:self didAddUsers:iq];
	} else {
		[multicastDelegate xmppRoomLight:self didFailToAddUsers:iq];
	}
}

- (void)fetchMembersList{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		//  <iq from='crone1@shakespeare.lit/desktop' id='getmembers'
		//  	  to='coven@muclight.shakespeare.lit'
		//  	type='get'>
		//  	<query xmlns='urn:xmpp:muclight:0#affiliations'>
		//  		<version>abcdefg</version>
		//  	</query>
		//  </iq>
		
		NSString *iqID = [XMPPStream generateUUID];
		XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:_roomJID elementID:iqID];
		NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:XMPPRoomLightAffiliations];
		[iq addChild:query];
		
		[xmppStream sendElement:iq];
		[responseTracker addID:iqID
						target:self
					  selector:@selector(handleFetchMembersListResponse:withInfo:)
					   timeout:60.0];
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)handleFetchMembersListResponse:(XMPPIQ *)iq withInfo:(id <XMPPTrackingInfo>)info{
	if ([[iq type] isEqualToString:@"result"]){
		NSXMLElement *query = [iq elementForName:@"query"
										   xmlns:XMPPRoomLightAffiliations];
		NSArray *items = [query elementsForName:@"user"];
		
		[multicastDelegate xmppRoomLight:self didFetchMembersList:items];
	}else{
		[multicastDelegate xmppRoomLight:self didFailToFetchMembersList:iq];
	}
}

- (void)sendMessage:(XMPPMessage *)message
{
	dispatch_block_t block = ^{ @autoreleasepool {

		[message addAttributeWithName:@"to" stringValue:[_roomJID full]];
		[message addAttributeWithName:@"type" stringValue:@"groupchat"];

		[xmppStream sendElement:message];
		
	}};

	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)sendMessageWithBody:(NSString *)messageBody{
	if ([messageBody length] == 0) return;
	
	NSXMLElement *body = [NSXMLElement elementWithName:@"body" stringValue:messageBody];
	
	XMPPMessage *message = [XMPPMessage message];
	[message addChild:body];
	
	[self sendMessage:message];
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq{
	NSString *type = [iq type];
	
	if ([type isEqualToString:@"result"] || [type isEqualToString:@"error"])
	{
		return [responseTracker invokeForID:[iq elementID] withObject:iq];
	}
	
	return NO;
}

@end
