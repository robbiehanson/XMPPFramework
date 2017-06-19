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
	
	if([roomFromUser isEqualToJID:myUser options:XMPPJIDCompareBare]) {
		// room is broadcasting back a message that has already been handled as outgoing
        return;
	}

	[self scheduleBlock:^{
        [self insertMessage:message outgoing:NO remoteTimestamp:nil forRoom:room stream:xmppStream];
	}];
}

- (void)handleOutgoingMessage:(XMPPMessage *)message room:(XMPPRoomLight *)room{
	XMPPStream *xmppStream = room.xmppStream;

	[self scheduleBlock:^{
        [self insertMessage:message outgoing:YES remoteTimestamp:nil forRoom:room stream:xmppStream];
	}];
}

- (void)insertMessage:(XMPPMessage *)message
			 outgoing:(BOOL)isOutgoing
      remoteTimestamp:(NSDate *)remoteTimestamp
			  forRoom:(XMPPRoomLight *)room
			   stream:(XMPPStream *)xmppStream{
	// Extract needed information
	
	XMPPJID *myRoomJID = [XMPPJID jidWithUser:room.roomJID.user
									   domain:room.roomJID.domain
									 resource:xmppStream.myJID.bare];
	
	XMPPJID *roomJID = room.roomJID;
	XMPPJID *messageJID = isOutgoing ? myRoomJID : [message from];
	
	NSDate *localTimestamp = remoteTimestamp ?: [[NSDate alloc] init];
	
	NSString *messageBody = [[message elementForName:@"body"] stringValue];
	
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSString *streamBareJidStr = [[self myJIDForXMPPStream:xmppStream] bare];
	
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
	roomMessage.streamBareJidStr = streamBareJidStr;
	
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
