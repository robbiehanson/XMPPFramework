//
//  XMPPRoomLightCoreDataStorage.m
//  Mangosta
//
//  Created by Andres Canal on 6/8/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

#import "XMPPRoomLightCoreDataStorage.h"
#import "XMPPCoreDataStorageProtected.h"
#import "NSXMLElement+XEP_0203.h"
#import "XMPPRoomLightMessageCoreDataStorageObject.h"

@implementation XMPPRoomLightCoreDataStorage{
	NSString *messageEntityName;
}

- (void)commonInit{

	[super commonInit];

	messageEntityName = NSStringFromClass([XMPPRoomLightMessageCoreDataStorageObject class]);

}

- (void)handleIncomingMessage:(XMPPMessage *)message room:(XMPPRoomLight *)room{
	XMPPStream *xmppStream = room.xmppStream;
	
	XMPPJID *roomFromUser = [XMPPJID jidWithString:[message from].resource];
	XMPPJID *myUser = [room.xmppStream myJID];
	
	// Ignore - if message is mine and it was not delayed then ignore
	// becuase we handled it in handleOutgoingMessage:room:
	if([roomFromUser isEqualToJID:myUser options:XMPPJIDCompareBare] && ![message wasDelayed]) {
		return;
	}

	[self scheduleBlock:^{
		[self insertMessageIfNeeded:message outgoing:NO forRoom:room stream:xmppStream];
	}];
}

- (void)handleOutgoingMessage:(XMPPMessage *)message room:(XMPPRoomLight *)room{
	XMPPStream *xmppStream = room.xmppStream;

	[self scheduleBlock:^{
		[self insertMessageIfNeeded:message outgoing:YES forRoom:room stream:xmppStream];
	}];
}

- (BOOL)containsMessageWithBody:(NSString *)body farEndJID:(XMPPJID *)farEndJID nearEndJID:(XMPPJID *)nearEndJID remoteTimestamp:(NSDate *)remoteTimestamp {
	
	// Does this message already exist in the database?
	// How can we tell if two XMPPRoomMessages are the same?
	//
	// 1. Same bare nearEndJID
	// 2. Same farEndJID
	// 3. Same text
	// 4. Approximately the same timestamps
	//
	// This is actually a rather difficult question.
	// What if the same user sends the exact same message multiple times?
	//
	// If we first received the message while already in the room, it won't contain a remoteTimestamp.
	// Returning to the room later and downloading the discussion history will return the same message,
	// this time with a remote timestamp.
	//
	// So if the message doesn't have a remoteTimestamp,
	// but it's localTimestamp is approximately the same as the remoteTimestamp,
	// then this is enough evidence to consider the messages the same.
	//
	// Note: Predicate order matters. Most unique key should be first, least unique should be last.
	
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSEntityDescription *messageEntity = [self messageEntity:moc];
	
	NSDate *minLocalTimestamp = [remoteTimestamp dateByAddingTimeInterval:-60];
	NSDate *maxLocalTimestamp = [remoteTimestamp dateByAddingTimeInterval: 60];
	
	NSString *predicateFormat = @"    body == %@ "
	@"AND jidStr == %@ "
	@"AND streamBareJidStr == %@ "
	@"AND "
	@"("
	@"     (remoteTimestamp == %@) "
	@"  OR (remoteTimestamp == NIL && localTimestamp BETWEEN {%@, %@})"
	@")";
	
	NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateFormat,
							  body, farEndJID, nearEndJID,
							  remoteTimestamp, minLocalTimestamp, maxLocalTimestamp];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:messageEntity];
	[fetchRequest setPredicate:predicate];
	[fetchRequest setFetchLimit:1];
	
	NSError *error = nil;
	NSArray *results = [moc executeFetchRequest:fetchRequest error:&error];
	
	return ([results count] > 0);
}

- (void)insertMessageIfNeeded:(XMPPMessage *)message
					 outgoing:(BOOL)isOutgoing
					  forRoom:(XMPPRoomLight *)room
					   stream:(XMPPStream *)xmppStream {
	// Extract needed information
	
	XMPPJID *myRoomJID = [XMPPJID jidWithUser:room.roomJID.user
									   domain:room.roomJID.domain
									 resource:[self myJIDForXMPPStream:xmppStream].bare];
	
	XMPPJID *roomJID = room.roomJID;
	XMPPJID *messageJID = isOutgoing ? myRoomJID : [message from];
	
	NSDate *remoteTimestamp = [message delayedDeliveryDate];
    NSDate *localTimestamp = remoteTimestamp ?: [[NSDate alloc] init];
	
	NSString *messageBody = [[message elementForName:@"body"] stringValue];
	
	NSManagedObjectContext *moc = [self managedObjectContext];
	XMPPJID *streamJID = [self myJIDForXMPPStream:xmppStream];
	
	if (remoteTimestamp && [self containsMessageWithBody:messageBody farEndJID:messageJID nearEndJID:[streamJID bareJID] remoteTimestamp:remoteTimestamp]) {
		// When the xmpp server sends us a room message, it will always timestamp delayed messages.
		// For example, when retrieving the discussion history, all messages will include the original timestamp.
		// If a message doesn't include such timestamp, then we know we're getting it in "real time".
		// Otherwise, the message needs to be tested for uniqueness.
		return;
	}
	
	NSEntityDescription *messageEntity = [self messageEntity:moc];

	XMPPRoomLightMessageCoreDataStorageObject *roomMessage = (XMPPRoomLightMessageCoreDataStorageObject *)
	[[NSManagedObject alloc] initWithEntity:messageEntity insertIntoManagedObjectContext:nil];
	
	roomMessage.message = message;
	roomMessage.roomJID = roomJID;
	roomMessage.jid = messageJID;
	roomMessage.nickname = [messageJID resource];
	roomMessage.body = messageBody;
	roomMessage.localTimestamp = localTimestamp;
	roomMessage.remoteTimestamp = remoteTimestamp;
	roomMessage.isFromMe = isOutgoing;
	roomMessage.streamBareJidStr = [streamJID bare];
	
	[moc insertObject:roomMessage];
	[self didInsertMessage:roomMessage];
}

- (void)didInsertMessage:(XMPPRoomLightMessageCoreDataStorageObject *)message{
	// Override me if you're extending the XMPPRoomLightMessageCoreDataStorageObject class to add additional properties.
	// You can update your additional properties here.
	//
	// At this point the standard properties have already been set.
	// So you can, for example, access the XMPPMessage via message.message.
}

- (NSEntityDescription *)messageEntity:(NSManagedObjectContext *)moc{

	// This method should be thread-safe.
	// So be sure to access the entity name through the property accessor.
	
	return [NSEntityDescription entityForName:[self messageEntityName] inManagedObjectContext:moc];
}

- (NSString *)messageEntityName{

	__block NSString *result = nil;
	
	dispatch_block_t block = ^{
		result = messageEntityName;
	};
	
	if (dispatch_get_specific(storageQueueTag))
		block();
	else
		dispatch_sync(storageQueue, block);
	
	return result;
}

@end
