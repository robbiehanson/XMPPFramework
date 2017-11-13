//
//  XMPPRoomLight.m
//  Mangosta
//
//  Created by Andres Canal on 5/27/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

#import "XMPPMessage+XEP0045.h"
#import "XMPPRoomLight.h"

static NSString *const XMPPRoomLightAffiliations = @"urn:xmpp:muclight:0#affiliations";
static NSString *const XMPPRoomLightConfiguration = @"urn:xmpp:muclight:0#configuration";
static NSString *const XMPPRoomLightDestroy = @"urn:xmpp:muclight:0#destroy";

@interface XMPPRoomLight() {
    BOOL shouldStoreAffiliationChangeMessages;
    BOOL shouldHandleMemberMessagesWithoutBody;
	NSString *roomname;
	NSString *subject;
    NSArray<NSXMLElement*> *knownMembersList;
	NSString *configVersion;
	NSString *memberListVersion;
}
@end

@implementation XMPPRoomLight

- (instancetype)init{
    NSAssert(NO, @"Cannot be instantiated with init!");
    return nil;
}

- (nonnull instancetype)initWithJID:(nonnull XMPPJID *)roomJID roomname:(nonnull NSString *)_roomname{
	return [self initWithRoomLightStorage:nil jid:roomJID roomname:_roomname dispatchQueue:nil];
}

- (nonnull instancetype)initWithRoomLightStorage:(nullable id <XMPPRoomLightStorage>)storage jid:(nonnull XMPPJID *)aRoomJID roomname:(nonnull NSString *)aRoomname dispatchQueue:(nullable dispatch_queue_t)queue{

	NSParameterAssert(aRoomJID != nil);

	if ((self = [super initWithDispatchQueue:queue])){
		xmppRoomLightStorage = storage;
		_domain = aRoomJID.domain;
		_roomJID = aRoomJID;
		roomname = aRoomname;
        knownMembersList = @[];
		configVersion = @"";
		memberListVersion = @"";
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

- (BOOL)shouldStoreAffiliationChangeMessages
{
    __block BOOL result;
    dispatch_block_t block = ^{ @autoreleasepool {
        result = shouldStoreAffiliationChangeMessages;
    }};
    
    if (dispatch_get_specific(moduleQueueTag))
        block();
    else
        dispatch_sync(moduleQueue, block);
    
    return result;
}

- (void)setShouldStoreAffiliationChangeMessages:(BOOL)newValue
{
    dispatch_block_t block = ^{ @autoreleasepool {
        shouldStoreAffiliationChangeMessages = newValue;
    }};
    
    if (dispatch_get_specific(moduleQueueTag))
        block();
    else
        dispatch_async(moduleQueue, block);
}

- (BOOL)shouldHandleMemberMessagesWithoutBody
{
    __block BOOL result;
    dispatch_block_t block = ^{ @autoreleasepool {
        result = shouldHandleMemberMessagesWithoutBody;
    }};
    
    if (dispatch_get_specific(moduleQueueTag))
        block();
    else
        dispatch_sync(moduleQueue, block);
    
    return result;
}

- (void)setShouldHandleMemberMessagesWithoutBody:(BOOL)newValue
{
    dispatch_block_t block = ^{ @autoreleasepool {
        shouldHandleMemberMessagesWithoutBody = newValue;
    }};
    
    if (dispatch_get_specific(moduleQueueTag))
        block();
    else
        dispatch_async(moduleQueue, block);
}

- (nonnull NSString *)roomname {
	@synchronized(roomname) {
		return [roomname copy];
	}
}

- (nonnull NSString *)subject {
	@synchronized(subject) {
		return [subject copy];
	}
}

- (NSArray<NSXMLElement *> *)knownMembersList {
    __block NSArray<NSXMLElement *> *result;
    dispatch_block_t block = ^{ @autoreleasepool {
        result = knownMembersList;
    }};
    
    if (dispatch_get_specific(moduleQueueTag))
        block();
    else
        dispatch_sync(moduleQueue, block);
    
    return result;
}

- (nonnull NSString *)configVersion {
	@synchronized(subject) {
		return [configVersion copy];
	}
}

- (nonnull NSString *)memberListVersion {
	@synchronized(subject) {
		return [memberListVersion copy];
	}
}

- (void)handleConfigElements:(NSArray<NSXMLElement*> *)configElements{
	for (NSXMLElement *element in configElements) {
		if([element.name isEqualToString:@"subject"]){
			[self setSubject:element.stringValue];
		} else if([element.name isEqualToString:@"roomname"]) {
			[self setRoomname:element.stringValue];
		}
	}
}

- (void)setRoomname:(NSString *)aRoomname{
	dispatch_block_t block = ^{ @autoreleasepool {
		roomname = aRoomname;
	}};

	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)setSubject:(NSString *)aSubject{
	dispatch_block_t block = ^{ @autoreleasepool {
		subject = aSubject;
	}};

	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)setKnownMembersList:(NSArray<NSXMLElement *> *)aMembersList {
    dispatch_block_t block = ^{ @autoreleasepool {
        knownMembersList = [aMembersList copy];
    }};
    
    if (dispatch_get_specific(moduleQueueTag))
        block();
    else
        dispatch_async(moduleQueue, block);
}

- (void)setMemberListVersion:(NSString *)aVersion{
	dispatch_block_t block = ^{ @autoreleasepool {
		memberListVersion = aVersion;
	}};

	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)setConfigVersion:(NSString *)aVersion{
	dispatch_block_t block = ^{ @autoreleasepool {
		configVersion = aVersion;
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)flushVersion{
	[self setConfigVersion:@""];
	[self setMemberListVersion:@""];
}

- (void)createRoomLightWithMembersJID:(nullable NSArray<XMPPJID *> *) members{
	
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
		[configuration addChild:[NSXMLElement elementWithName:@"roomname" stringValue:roomname]];
		
		NSXMLElement *occupants = [NSXMLElement elementWithName:@"occupants"];
		for (XMPPJID *jid in members){
			NSXMLElement *userElement = [NSXMLElement elementWithName:@"user" stringValue:jid.bare];
			[userElement addAttributeWithName:@"affiliation" stringValue:@"member"];
			[occupants addChild:userElement];
		}
		
		[query addChild:configuration];
		[query addChild:occupants];
		
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
		[multicastDelegate xmppRoomLight:self didCreateRoomLight:iq];
	}else{
		[multicastDelegate xmppRoomLight:self didFailToCreateRoomLight:iq];
	}
}

- (void)leaveRoomLight{
	
	//		<iq from='crone1@shakespeare.lit/desktop'
	//				id='member2'
	//				to='coven@chat.shakespeare.lit'
	//				type='set'>
	//			<query xmlns="urn:xmpp:muclight:0#affiliations">
	//				<item affiliation='none' jid='hag66@shakespeare.lit'/>
	//			</query>
	//		</iq>
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		NSString *iqID = [XMPPStream generateUUID];
		NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
		[iq addAttributeWithName:@"id" stringValue:iqID];
		[iq addAttributeWithName:@"to" stringValue:self.roomJID.full];
		[iq addAttributeWithName:@"type" stringValue:@"set"];
		
		NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:XMPPRoomLightAffiliations];
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
		[multicastDelegate xmppRoomLight:self didLeaveRoomLight:iq];
	}else{
		[multicastDelegate xmppRoomLight:self didFailToLeaveRoomLight:iq];
	}
}

- (void)addUsers:(nonnull NSArray<XMPPJID *> *)users{
	
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
		
		NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:XMPPRoomLightAffiliations];
		for (XMPPJID *userJID in users) {
			NSXMLElement *user = [NSXMLElement elementWithName:@"user"];
			[user addAttributeWithName:@"affiliation" stringValue:@"member"];
			user.stringValue = userJID.full;
			
			[query addChild:user];
		}
		[iq addChild:query];
		
		[responseTracker addID:iqID
						target:self
					  selector:@selector(handleAddUsers:withInfo:)
					   timeout:60.0];
		[xmppStream sendElement:iq];

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

		[query addChild:[NSXMLElement elementWithName:@"version" stringValue:self.memberListVersion]];
		[iq addChild:query];
		
		[responseTracker addID:iqID
						target:self
					  selector:@selector(handleFetchMembersListResponse:withInfo:)
					   timeout:60.0];

		[xmppStream sendElement:iq];
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

		NSXMLElement *inVersion = [query elementForName:@"version"];
		if(inVersion){
			[self setMemberListVersion:inVersion.stringValue];
		}
		
		NSArray *items = [query elementsForName:@"user"];
        if (items) {
            [self setKnownMembersList:items];
        }

		[multicastDelegate xmppRoomLight:self didFetchMembersList:iq];
	}else{
		[multicastDelegate xmppRoomLight:self didFailToFetchMembersList:iq];
	}
}

- (void)destroyRoom {
	dispatch_block_t block = ^{ @autoreleasepool {

		//  <iq from='crone1@shakespeare.lit/desktop'
		//	    id='destroy1'
		//	    to='coven@muclight.shakespeare.lit'
		//	  type='set'>
		//	  <query xmlns='urn:xmpp:muclight:0#destroy' />
		//  </iq>

		NSString *iqID = [XMPPStream generateUUID];
		XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:_roomJID elementID:iqID];
		NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:XMPPRoomLightDestroy];
		[iq addChild:query];

		[responseTracker addID:iqID
						target:self
					  selector:@selector(handleDestroyRoom:withInfo:)
					   timeout:60.0];

		[xmppStream sendElement:iq];
	}};

	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)handleDestroyRoom:(XMPPIQ *)iq withInfo:(id <XMPPTrackingInfo>)info{
	if ([[iq type] isEqualToString:@"result"]){
		[multicastDelegate xmppRoomLight:self didDestroyRoomLight:iq];
	} else {
		[multicastDelegate xmppRoomLight:self didFailToDestroyRoomLight:iq];
	}
}

- (void)sendMessage:(nonnull XMPPMessage *)message{

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

- (void)sendMessageWithBody:(nonnull NSString *)messageBody{
	if ([messageBody length] == 0) return;
	
	NSXMLElement *body = [NSXMLElement elementWithName:@"body" stringValue:messageBody];
	
	XMPPMessage *message = [XMPPMessage message];
	[message addChild:body];
	
	[self sendMessage:message];
}

- (void)changeRoomSubject:(nonnull NSString *)roomSubject{

	[self setConfiguration:@[[NSXMLElement elementWithName:@"subject" stringValue:roomSubject]]];

}

- (void)changeAffiliations:(nonnull NSArray<NSXMLElement *> *)members{
	dispatch_block_t block = ^{ @autoreleasepool {

		// <iq from='crone1@shakespeare.lit/desktop'
		//       id='member1'
		//       to='coven@muclight.shakespeare.lit'
		//     type='set'>
		// 	<query xmlns='urn:xmpp:muclight:0#affiliations'>
		// 		<user affiliation='member'>hag66@shakespeare.lit</user>
		// 		<user affiliation='owner'>hag77@shakespeare.lit</user>
		// 		<user affiliation='none'>hag88@shakespeare.lit</user>
		// 	</query>
		// </iq>

		NSString *iqID = [XMPPStream generateUUID];
		XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:_roomJID elementID:iqID];
		NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:XMPPRoomLightAffiliations];

		for (NSXMLElement *element in members){
			[query addChild:element];
		}

		[iq addChild:query];

		[responseTracker addID:iqID
						target:self
					  selector:@selector(handleChangeAffiliations:withInfo:)
					   timeout:60.0];

		[xmppStream sendElement:iq];
	}};

	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)handleChangeAffiliations:(XMPPIQ *)iq withInfo:(id <XMPPTrackingInfo>)info{
	if ([[iq type] isEqualToString:@"result"]) {
		[multicastDelegate xmppRoomLight:self didChangeAffiliations:iq];
	}else{
		[multicastDelegate xmppRoomLight:self didFailToChangeAffiliations:iq];
	}
}


- (void)getConfiguration {
	dispatch_block_t block = ^{ @autoreleasepool {

		// <iq from='crone1@shakespeare.lit/desktop' id='config0'
		// 		 to='coven@muclight.shakespeare.lit'
		// 	   type='get'>
		// 	   <query xmlns='urn:xmpp:muclight:0#configuration'>
		//			<version>abcdefg</version>
		// 	   </query>
		// </iq>

		NSString *iqID = [XMPPStream generateUUID];
		XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:_roomJID elementID:iqID];
		NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:XMPPRoomLightConfiguration];

		[query addChild:[NSXMLElement elementWithName:@"version" stringValue:self.configVersion]];
		[iq addChild:query];

		[responseTracker addID:iqID
						target:self
					  selector:@selector(handleGetConfiguration:withInfo:)
					   timeout:60.0];

		[xmppStream sendElement:iq];
	}};

	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)handleGetConfiguration:(XMPPIQ *)iq withInfo:(id <XMPPTrackingInfo>)info{
	if ([[iq type] isEqualToString:@"result"]) {

		NSXMLElement *query = [[iq elementsForLocalName:@"query" URI:XMPPRoomLightConfiguration] firstObject];
		NSXMLElement *inVersion = [query elementForName:@"version"];
		if(inVersion){
			[self setConfigVersion:inVersion.stringValue];
		}

		NSArray *configElements = [[iq elementsForLocalName:@"query" URI:XMPPRoomLightConfiguration] firstObject].children;
		[self handleConfigElements:configElements];

		[multicastDelegate xmppRoomLight:self didGetConfiguration:iq];
	}else{
		[multicastDelegate xmppRoomLight:self didFailToGetConfiguration:iq];
	}
}

- (void)setConfiguration:(nonnull NSArray<NSXMLElement *> *)configs{

	dispatch_block_t block = ^{ @autoreleasepool {

		// <iq from='crone1@shakespeare.lit/desktop' id='conf2' to='coven@muclight.shakespeare.lit' type='set'>
		//	 <query xmlns='urn:xmpp:muclight:0#configuration'>
		//		<roomname>A Darker Cave</roomname>
		//	 </query>
		// </iq>

		NSString *iqID = [XMPPStream generateUUID];
		XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:_roomJID elementID:iqID];
		NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:XMPPRoomLightConfiguration];

		for (NSXMLElement *element in configs){
			[query addChild:element];
		}

		[iq addChild:query];

		[responseTracker addID:iqID
						target:self
					  selector:@selector(handleSetConfiguration:withInfo:)
					   timeout:60.0];

		[xmppStream sendElement:iq];
	}};

	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)handleSetConfiguration:(XMPPIQ *)iq withInfo:(id <XMPPTrackingInfo>)info{
	if ([[iq type] isEqualToString:@"result"]) {
		[multicastDelegate xmppRoomLight:self didSetConfiguration:iq];
	}else{
		[multicastDelegate xmppRoomLight:self didFailToSetConfiguration:iq];
	}
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq{
	NSString *type = [iq type];
	if ([type isEqualToString:@"result"] || [type isEqualToString:@"error"]){
		return [responseTracker invokeForID:[iq elementID] withObject:iq];
	}

	return NO;
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message{

	XMPPJID *from = [message from];

	if (![self.roomJID isEqualToJID:from options:XMPPJIDCompareBare]){
		return; // Stanza isn't for our room
	}

    // note: do not use [message elementsForName:@"x"] as this will fail to find namespace-qualified elements in Apple's NSXML implementation (DDXML works fine)
	BOOL destroyRoom = [message elementsForLocalName:@"x" URI:XMPPRoomLightDestroy].count > 0;
	BOOL changeConfiguration = [message elementsForLocalName:@"x" URI:XMPPRoomLightConfiguration].count > 0;;
    BOOL changeAffiliantions = [message elementsForLocalName:@"x" URI:XMPPRoomLightAffiliations].count > 0;;
    
	// Is this a message we need to store (a chat message)?
	//
	// We store messages that from is full room-id@domain/user-who-sends-message
    // and that have something in the body (unless empty messages are allowed)

	if ([from isFull] && [message isGroupChatMessage] && (self.shouldHandleMemberMessagesWithoutBody || [message isMessageWithBody])) {
		[xmppRoomLightStorage handleIncomingMessage:message room:self];
		[multicastDelegate xmppRoomLight:self didReceiveMessage:message];
	}else if(destroyRoom){
		[multicastDelegate xmppRoomLight:self roomDestroyed:message];
	}else if(changeConfiguration){
		NSArray *configElements = [message elementForName:@"x"].children;
		[self handleConfigElements:configElements];

		[multicastDelegate xmppRoomLight:self configurationChanged:message];
    } else if (changeAffiliantions && self.shouldStoreAffiliationChangeMessages) {
        [xmppRoomLightStorage handleIncomingMessage:message room:self];
	}else{
		// Todo... Handle other types of messages.
	}
}

- (void)xmppStream:(XMPPStream *)sender didSendMessage:(XMPPMessage *)message
{
	XMPPJID *to = [message to];

	if (![self.roomJID isEqualToJID:to options:XMPPJIDCompareBare]){
		return; // Stanza isn't for our room
	}

	// Is this a message we need to store (a chat message)?
	//
	// A message to all recipients MUST be of type groupchat.
	// A message to an individual recipient would have a <body/>.

	if ([message isGroupChatMessage] && (self.shouldHandleMemberMessagesWithoutBody || [message isMessageWithBody])) {
		[xmppRoomLightStorage handleOutgoingMessage:message room:self];
	}
}

@end
