#import "XMPPRoomCoreDataStorage.h"
#import "XMPPCoreDataStorageProtected.h"
#import "XMPPElement+Delay.h"
#import "XMPPLogging.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_VERBOSE | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

#define AssertPrivateQueue() \
            NSAssert(dispatch_get_current_queue() == storageQueue, @"Private method: MUST run on storageQueue");

@interface XMPPRoomCoreDataStorage ()
{
	/* Inherited from XMPPCoreDataStorage
	
	NSString *databaseFileName;
	NSUInteger saveThreshold;
	
	dispatch_queue_t storageQueue;
	
	*/
	
	NSTimeInterval maxMessageAge;
	NSTimeInterval deleteInterval;
	
	NSMutableSet *pausedMessageDeletion;
}

- (void)_clearAllOccupantsFromRoom:(XMPPJID *)roomJID;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPRoomCoreDataStorage

static XMPPRoomCoreDataStorage *sharedInstance;

+ (XMPPRoomCoreDataStorage *)sharedInstance
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		sharedInstance = [[XMPPRoomCoreDataStorage alloc] initWithDatabaseFilename:nil];
	});
	
	return sharedInstance;
}

- (void)commonInit
{
	XMPPLogTrace();
	[super commonInit];
	
	// This method is invoked by all public init methods of the superclass
	
	maxMessageAge  = (60 * 60 * 24 * 7); // 7 days
	deleteInterval = (60 * 5);           // 5 days
	
	pausedMessageDeletion = [[NSMutableSet alloc] init];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Configuration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSTimeInterval)maxMessageAge
{
	__block NSTimeInterval result = 0;
	
	dispatch_block_t block = ^{
		result = maxMessageAge;
	};
	
	if (dispatch_get_current_queue() == storageQueue)
		block();
	else
		dispatch_sync(storageQueue, block);
	
	return result;
}

- (void)setMaxMessageAge:(NSTimeInterval)age
{
	dispatch_block_t block = ^{
		maxMessageAge = age;
	};
	
	if (dispatch_get_current_queue() == storageQueue)
		block();
	else
		dispatch_async(storageQueue, block);
}

- (NSTimeInterval)deleteInterval
{
	__block NSTimeInterval result = 0;
	
	dispatch_block_t block = ^{
		result = deleteInterval;
	};
	
	if (dispatch_get_current_queue() == storageQueue)
		block();
	else
		dispatch_sync(storageQueue, block);
	
	return result;
}

- (void)setDeleteInterval:(NSTimeInterval)interval
{
	dispatch_block_t block = ^{
		deleteInterval = interval;
	};
	
	if (dispatch_get_current_queue() == storageQueue)
		block();
	else
		dispatch_async(storageQueue, block);
}

- (void)pauseOldMessageDeletionForRoom:(XMPPJID *)roomJID
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		[pausedMessageDeletion addObject:[roomJID bareJID]];
	}};
	
	if (dispatch_get_current_queue() == storageQueue)
		block();
	else
		dispatch_async(storageQueue, block);
}

- (void)resumeOldMessageDeletionForRoom:(XMPPJID *)roomJID
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		[pausedMessageDeletion removeObject:[roomJID bareJID]];
	}};
	
	if (dispatch_get_current_queue() == storageQueue)
		block();
	else
		dispatch_async(storageQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Overrides
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)didCreateManagedObjectContext
{
	XMPPLogTrace();
	
	[self _clearAllOccupantsFromRoom:nil];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Private API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSEntityDescription *)messageEntity:(NSManagedObjectContext *)moc
{
	return [NSEntityDescription entityForName:@"XMPPRoomMessageCoreDataStorageObject" inManagedObjectContext:moc];
}

- (NSEntityDescription *)occupantEntity:(NSManagedObjectContext *)moc
{
	return [NSEntityDescription entityForName:@"XMPPRoomOccupantCoreDataStorageObject" inManagedObjectContext:moc];
}

- (void)_clearAllOccupantsFromRoom:(XMPPJID *)roomJID
{
	XMPPLogTrace();
	AssertPrivateQueue();
	
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSEntityDescription *entity = [self occupantEntity:moc];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	[fetchRequest setFetchBatchSize:saveThreshold];
	
	if (roomJID)
	{
		NSPredicate *predicate;
		predicate = [NSPredicate predicateWithFormat:@"roomJIDStr == %@", [roomJID bare]];
		
		[fetchRequest setPredicate:predicate];
	}
	
	NSArray *allOccupants = [moc executeFetchRequest:fetchRequest error:nil];
	
	NSUInteger unsavedCount = [self numberOfUnsavedChanges];
	
	for (XMPPRoomOccupantCoreDataStorageObject *occupant in allOccupants)
	{
		[moc deleteObject:occupant];
		
		if (++unsavedCount >= saveThreshold)
		{
			[self save];
			unsavedCount = 0;
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Public API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (XMPPRoomOccupantCoreDataStorageObject *)occupantForJID:(XMPPJID *)jid inContext:(NSManagedObjectContext *)moc
{
	if (jid == nil) return nil;
	
	NSEntityDescription *entity = [self occupantEntity:moc];
	
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"jidStr == %@", jid];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	[fetchRequest setPredicate:predicate];
	[fetchRequest setFetchBatchSize:1];
	
	return [[moc executeFetchRequest:fetchRequest error:nil] lastObject];
}

- (NSDate *)mostRecentMessageTimestampForRoom:(XMPPJID *)roomJID
{
	return [self mostRecentMessageTimestampForRoom:roomJID stream:nil];
}

- (NSDate *)mostRecentMessageTimestampForRoom:(XMPPJID *)roomJID stream:(XMPPStream *)stream
{
	// Todo...
	return nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPRoomStorage Protocol
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)handlePresence:(XMPPPresence *)presence room:(XMPPRoom *)room
{
	XMPPLogTrace();
	
	XMPPJID *roomJID = room.roomJID;
	XMPPJID *presenceJID = [presence from];
	XMPPStream *xmppStream = room.xmppStream;
	
	NSString *role = nil;
	NSString *affiliation = nil;
	XMPPJID *realJID = nil;
	
	NSXMLElement *x = [presence elementForName:@"x" xmlns:@"http://jabber.org/protocol/muc#user"];
	NSXMLElement *item = [x elementForName:@"item"];
	if (item)
	{
		role = [[item attributeStringValueForName:@"role"] lowercaseString];
		affiliation = [[item attributeStringValueForName:@"affiliation"] lowercaseString];
		
		NSString *realJIDStr = [item attributeStringValueForName:@"jid"];
		if (realJIDStr)
		{
			realJID = [XMPPJID jidWithString:realJIDStr];
		}
	}
	
	[self scheduleBlock:^{
		
		NSManagedObjectContext *moc = [self managedObjectContext];
		NSString *streamBareJidStr = [[self myJIDForXMPPStream:xmppStream] bare];
		
		// Is occupant already in database?
		
		NSEntityDescription *entity = [self occupantEntity:moc];
		
		NSString *predicateFormat = @"jidStr == %@ AND streamBareJidStr == %@";
		NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateFormat, presenceJID, streamBareJidStr];
		
		NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
		[fetchRequest setEntity:entity];
		[fetchRequest setPredicate:predicate];
		[fetchRequest setFetchLimit:1];
		
		NSError *error = nil;
		XMPPRoomOccupantCoreDataStorageObject *occupant;
		
		occupant = [[moc executeFetchRequest:fetchRequest error:&error] lastObject];
		
		if (error)
		{
			XMPPLogWarn(@"%@: %@ - fetch error: %@", THIS_FILE, THIS_METHOD, error);
			return;
		}
		
		// Is occupant available or unavailable?
		
		if ([[presence type] isEqualToString:@"unavailable"])
		{
			// Remove occupant record from database
			
			if (occupant)
			{
				[moc deleteObject:occupant];
			}
		}
		else
		{
			// Updated existing occupant, or add new occupant to database.
			
			if (occupant == nil)
			{
				occupant = [NSEntityDescription insertNewObjectForEntityForName:@"XMPPRoomOccupantCoreDataStorageObject"
														 inManagedObjectContext:moc];
			}
			
			occupant.presence = presence;
			occupant.roomJID = roomJID;
			occupant.jid = presenceJID;
			occupant.nickname = [presenceJID resource];
			occupant.role = role;
			occupant.affiliation = affiliation;
			occupant.realJID = realJID;
			occupant.streamBareJidStr = streamBareJidStr;
		}
	}];
}

- (void)handleOutgoingMessage:(XMPPMessage *)message room:(XMPPRoom *)room
{
	XMPPLogTrace();
	
	XMPPJID *roomJID = room.roomJID;
	XMPPJID *messageJID = room.myRoomJID;
	XMPPStream *xmppStream = room.xmppStream;
	
	NSDate *localTimestamp = [[NSDate alloc] init];
	
	NSString *messageBody = [[message elementForName:@"body"] stringValue];
	
	[self scheduleBlock:^{
		
		NSManagedObjectContext *moc = [self managedObjectContext];
		NSString *streamBareJidStr = [[self myJIDForXMPPStream:xmppStream] bare];
		
		XMPPRoomMessageCoreDataStorageObject *roomMessage;
		roomMessage = [NSEntityDescription insertNewObjectForEntityForName:@"XMPPRoomMessageCoreDataStorageObject"
		                                            inManagedObjectContext:moc];
		
		roomMessage.message = message;
		roomMessage.roomJID = roomJID;
		roomMessage.jid = messageJID;
		roomMessage.nickname = [messageJID resource];
		roomMessage.body = messageBody;
		roomMessage.localTimestamp = localTimestamp;
		roomMessage.isFromMe = YES;
		roomMessage.streamBareJidStr = streamBareJidStr;
	}];
}

- (void)handleIncomingMessage:(XMPPMessage *)message room:(XMPPRoom *)room
{
	XMPPLogTrace();
	
	XMPPJID *roomJID = room.roomJID;
	XMPPJID *messageJID = [message from];
	
	if ([roomJID isEqualToJID:messageJID])
	{
		// Ignore - we already stored message in handleOutgoingMessage:room:
		return;
	}
	
	XMPPStream *xmppStream = room.xmppStream;
	
	NSDate *localTimestamp = [[NSDate alloc] init];
	NSDate *remoteTimestamp = [message delayedDeliveryDate];
	
	NSString *messageBody = [[message elementForName:@"body"] stringValue];
	
	[self scheduleBlock:^{
		
		NSManagedObjectContext *moc = [self managedObjectContext];
		NSString *streamBareJidStr = [[self myJIDForXMPPStream:xmppStream] bare];
		
		if (remoteTimestamp)
		{
			// Does this message already exist in the database?
			// How can we tell if two XMPPRoomMessages are the same?
			// 
			// 1. Same streamBareJidStr
			// 2. Same jid
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
			
			NSEntityDescription *entity = [self messageEntity:moc];
			
			// Note: Predicate order matters. Most unique key should be first, least unique should be last.
			
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
			                             messageBody, messageJID, streamBareJidStr,
			                             remoteTimestamp, minLocalTimestamp, maxLocalTimestamp];
			
			NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
			[fetchRequest setEntity:entity];
			[fetchRequest setPredicate:predicate];
			[fetchRequest setFetchLimit:1];
			
			NSError *error = nil;
			NSArray *results = [moc executeFetchRequest:fetchRequest error:&error];
			
			if ([results count] > 0)
			{
				XMPPLogVerbose(@"%@: %@ - Duplicate message", THIS_FILE, THIS_METHOD);
				return;
			}
			else if (error)
			{
				XMPPLogError(@"%@: %@ - Fetch error: %@", THIS_FILE, THIS_METHOD, error);
				return;
			}
		}
		
		XMPPRoomMessageCoreDataStorageObject *roomMessage;
		roomMessage = [NSEntityDescription insertNewObjectForEntityForName:@"XMPPRoomMessageCoreDataStorageObject"
		                                            inManagedObjectContext:moc];
		
		roomMessage.message = message;
		roomMessage.roomJID = roomJID;
		roomMessage.jid = messageJID;
		roomMessage.nickname = [messageJID resource];
		roomMessage.body = messageBody;
		roomMessage.localTimestamp = localTimestamp;
		roomMessage.remoteTimestamp = remoteTimestamp;
		roomMessage.isFromMe = NO;
		roomMessage.streamBareJidStr = streamBareJidStr;
	}];
}

@end
