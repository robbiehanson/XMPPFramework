#import "XMPPRoomCoreDataStorage.h"
#import "XMPPCoreDataStorageProtected.h"
#import "NSXMLElement+XEP_0203.h"
#import "XMPPLogging.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

#define AssertPrivateQueue() \
            NSAssert(dispatch_get_specific(storageQueueTag), @"Private method: MUST run on storageQueue");

@interface XMPPRoomCoreDataStorage ()
{
	/* Inherited from XMPPCoreDataStorage
	
	NSString *databaseFileName;
	NSUInteger saveThreshold;
	
	dispatch_queue_t storageQueue;
	
	*/
	
	NSString *messageEntityName;
	NSString *occupantEntityName;
	
	NSTimeInterval maxMessageAge;
	NSTimeInterval deleteInterval;
	
	NSMutableSet *pausedMessageDeletion;
	
	dispatch_time_t lastDeleteTime;
	dispatch_source_t deleteTimer;
}

- (NSEntityDescription *)messageEntity:(NSManagedObjectContext *)moc;
- (NSEntityDescription *)occupantEntity:(NSManagedObjectContext *)moc;

- (void)performDelete;
- (void)destroyDeleteTimer;
- (void)updateDeleteTimer;
- (void)createAndStartDeleteTimer;

- (void)clearAllOccupantsFromRoom:(XMPPJID *)roomJID;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPRoomCoreDataStorage

static XMPPRoomCoreDataStorage *sharedInstance;

+ (instancetype)sharedInstance
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		sharedInstance = [[XMPPRoomCoreDataStorage alloc] initWithDatabaseFilename:nil storeOptions:nil];
	});
	
	return sharedInstance;
}

- (void)commonInit
{
	XMPPLogTrace();
	[super commonInit];
	
	// This method is invoked by all public init methods of the superclass
	
	messageEntityName = NSStringFromClass([XMPPRoomMessageCoreDataStorageObject class]);
	occupantEntityName = NSStringFromClass([XMPPRoomOccupantCoreDataStorageObject class]);
	
	maxMessageAge  = (60 * 60 * 24 * 7); // 7 days
	deleteInterval = (60 * 5);           // 5 days
	
	pausedMessageDeletion = [[NSMutableSet alloc] init];
}

- (void)dealloc
{
	[self destroyDeleteTimer];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Configuration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)messageEntityName
{
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

- (void)setMessageEntityName:(NSString *)newMessageEntityName
{
	dispatch_block_t block = ^{
		messageEntityName = newMessageEntityName;
	};
	
	if (dispatch_get_specific(storageQueueTag))
		block();
	else
		dispatch_async(storageQueue, block);
}

- (NSString *)occupantEntityName
{
	__block NSString *result = nil;
	
	dispatch_block_t block = ^{
		result = occupantEntityName;
	};
	
	if (dispatch_get_specific(storageQueueTag))
		block();
	else
		dispatch_sync(storageQueue, block);
	
	return result;
}

- (void)setOccupantEntityName:(NSString *)newOccupantEntityName
{
	dispatch_block_t block = ^{
		occupantEntityName = newOccupantEntityName;
	};
	
	if (dispatch_get_specific(storageQueueTag))
		block();
	else
		dispatch_async(storageQueue, block);
}

- (NSTimeInterval)maxMessageAge
{
	__block NSTimeInterval result = 0;
	
	dispatch_block_t block = ^{
		result = maxMessageAge;
	};
	
	if (dispatch_get_specific(storageQueueTag))
		block();
	else
		dispatch_sync(storageQueue, block);
	
	return result;
}

- (void)setMaxMessageAge:(NSTimeInterval)age
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		NSTimeInterval oldMaxMessageAge = maxMessageAge;
		NSTimeInterval newMaxMessageAge = age;
		
		maxMessageAge = age;
		
		// There are several cases we need to handle here.
		// 
		// 1. If the maxAge was previously enabled and it just got disabled,
		//    then we need to stop the deleteTimer. (And we might as well release it.)
		// 
		// 2. If the maxAge was previously disabled and it just got enabled,
		//    then we need to setup the deleteTimer. (Plus we might need to do an immediate delete.)
		// 
		// 3. If the maxAge was increased,
		//    then we don't need to do anything.
		// 
		// 4. If the maxAge was decreased,
		//    then we should do an immediate delete.
		
		BOOL shouldDeleteNow = NO;
		
		if (oldMaxMessageAge > 0.0)
		{
			if (newMaxMessageAge <= 0.0)
			{
				// Handles #1
				[self destroyDeleteTimer];
			}
			else if (oldMaxMessageAge > newMaxMessageAge)
			{
				// Handles #4
				shouldDeleteNow = YES;
			}
			else
			{
				// Handles #3
				// Nothing to do now
			}
		}
		else if (newMaxMessageAge > 0.0)
		{
			// Handles #2
			shouldDeleteNow = YES;
		}
		
		if (shouldDeleteNow)
		{
			[self performDelete];
			
			if (deleteTimer)
				[self updateDeleteTimer];
			else
				[self createAndStartDeleteTimer];
		}
	}};
	
	if (dispatch_get_specific(storageQueueTag))
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
	
	if (dispatch_get_specific(storageQueueTag))
		block();
	else
		dispatch_sync(storageQueue, block);
	
	return result;
}

- (void)setDeleteInterval:(NSTimeInterval)interval
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		deleteInterval = interval;
		
		// There are several cases we need to handle here.
		// 
		// 1. If the deleteInterval was previously enabled and it just got disabled,
		//    then we need to stop the deleteTimer. (And we might as well release it.)
		// 
		// 2. If the deleteInterval was previously disabled and it just got enabled,
		//    then we need to setup the deleteTimer. (Plus we might need to do an immediate delete.)
		// 
		// 3. If the deleteInterval increased, then we need to reset the timer so that it fires at the later date.
		// 
		// 4. If the deleteInterval decreased, then we need to reset the timer so that it fires at an earlier date.
		//    (Plus we might need to do an immediate delete.)
		
		if (deleteInterval > 0.0)
		{
			if (deleteTimer == NULL)
			{
				// Handles #2
				// 
				// Since the deleteTimer uses the lastDeleteTime to calculate it's first fireDate,
				// if a delete is needed the timer will fire immediately.
				
				[self createAndStartDeleteTimer];
			}
			else
			{
				// Handles #3
				// Handles #4
				// 
				// Since the deleteTimer uses the lastDeleteTime to calculate it's first fireDate,
				// if a save is needed the timer will fire immediately.
				
				[self updateDeleteTimer];
			}
		}
		else if (deleteTimer)
		{
			// Handles #1
			
			[self destroyDeleteTimer];
		}
	}};
	
	if (dispatch_get_specific(storageQueueTag))
		block();
	else
		dispatch_async(storageQueue, block);
}

- (void)pauseOldMessageDeletionForRoom:(XMPPJID *)roomJID
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		[pausedMessageDeletion addObject:[roomJID bareJID]];
	}};
	
	if (dispatch_get_specific(storageQueueTag))
		block();
	else
		dispatch_async(storageQueue, block);
}

- (void)resumeOldMessageDeletionForRoom:(XMPPJID *)roomJID
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		[pausedMessageDeletion removeObject:[roomJID bareJID]];
		[self performDelete];
	}};
	
	if (dispatch_get_specific(storageQueueTag))
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
	
	[self clearAllOccupantsFromRoom:nil];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Internal API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)performDelete
{
	if (maxMessageAge <= 0.0) return;
	
	NSDate *minLocalTimestamp = [NSDate dateWithTimeIntervalSinceNow:(maxMessageAge * -1.0)];
	
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSEntityDescription *messageEntity = [self messageEntity:moc];
	
	NSPredicate *predicate;
	if ([pausedMessageDeletion count] > 0)
	{
		predicate = [NSPredicate predicateWithFormat:@"localTimestamp <= %@ AND NOT roomJIDStr IN %@",
		                                                  minLocalTimestamp, pausedMessageDeletion];
	}
	else
	{
		predicate = [NSPredicate predicateWithFormat:@"localTimestamp <= %@", minLocalTimestamp];
	}
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:messageEntity];
	[fetchRequest setPredicate:predicate];
	[fetchRequest setFetchBatchSize:saveThreshold];
	
	NSError *error = nil;
	NSArray *oldMessages = [moc executeFetchRequest:fetchRequest error:&error];
	
	if (error)
	{
		XMPPLogWarn(@"%@: %@ - fetch error: %@", THIS_FILE, THIS_METHOD, error);
	}
	
	NSUInteger unsavedCount = [self numberOfUnsavedChanges];
	
	for (XMPPRoomMessageCoreDataStorageObject *oldMessage in oldMessages)
	{
		[moc deleteObject:oldMessage];
		
		if (++unsavedCount >= saveThreshold)
		{
			[self save];
			unsavedCount = 0;
		}
	}
	
	lastDeleteTime = dispatch_time(DISPATCH_TIME_NOW, 0);
}

- (void)destroyDeleteTimer
{
	if (deleteTimer)
	{
		dispatch_source_cancel(deleteTimer);
		#if !OS_OBJECT_USE_OBJC
		dispatch_release(deleteTimer);
		#endif
		deleteTimer = NULL;
	}
}

- (void)updateDeleteTimer
{
	if ((deleteTimer != NULL) && (deleteInterval > 0.0) && (maxMessageAge > 0.0))
	{
		uint64_t interval = deleteInterval * NSEC_PER_SEC;
		dispatch_time_t startTime;
		
		if (lastDeleteTime > 0)
			startTime = dispatch_time(lastDeleteTime, interval);
		else
			startTime = dispatch_time(DISPATCH_TIME_NOW, interval);
		
		dispatch_source_set_timer(deleteTimer, startTime, interval, 1.0);
	}
}

- (void)createAndStartDeleteTimer
{
	if ((deleteTimer == NULL) && (deleteInterval > 0.0) && (maxMessageAge > 0.0))
	{
		deleteTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, storageQueue);
		
		dispatch_source_set_event_handler(deleteTimer, ^{ @autoreleasepool {
			
			[self performDelete];
			
		}});
		
		[self updateDeleteTimer];
		
		if(deleteTimer != NULL)
		{
			dispatch_resume(deleteTimer);
		}
	}
}

- (void)clearAllOccupantsFromRoom:(XMPPJID *)roomJID
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
#pragma mark Protected API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Optional override hook.
**/
- (BOOL)existsMessage:(XMPPMessage *)message forRoom:(XMPPRoom *)room stream:(XMPPStream *)xmppStream
{
	NSDate *remoteTimestamp = [message delayedDeliveryDate];
	
	if (remoteTimestamp == nil)
	{
		// When the xmpp server sends us a room message, it will always timestamp delayed messages.
		// For example, when retrieving the discussion history, all messages will include the original timestamp.
		// If a message doesn't include such timestamp, then we know we're getting it in "real time".
		
		return NO;
	}
	
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
	// 
	// Note: Predicate order matters. Most unique key should be first, least unique should be last.
	
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSEntityDescription *messageEntity = [self messageEntity:moc];
	
	NSString *streamBareJidStr = [[self myJIDForXMPPStream:xmppStream] bare];
	
	XMPPJID *messageJID = [message from];
	NSString *messageBody = [[message elementForName:@"body"] stringValue];
	
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
	[fetchRequest setEntity:messageEntity];
	[fetchRequest setPredicate:predicate];
	[fetchRequest setFetchLimit:1];
		
	NSError *error = nil;
	NSArray *results = [moc executeFetchRequest:fetchRequest error:&error];
	
	if (error)
	{
		XMPPLogError(@"%@: %@ - Fetch error: %@", THIS_FILE, THIS_METHOD, error);
	}
	
	return ([results count] > 0);
}

/**
 * Optional override hook for general extensions.
 * 
 * @see insertMessage:outgoing:forRoom:stream:
**/
- (void)didInsertMessage:(XMPPRoomMessageCoreDataStorageObject *)message
{
	// Override me if you're extending the XMPPRoomMessageCoreDataStorageObject class to add additional properties.
	// You can update your additional properties here.
	// 
	// At this point the standard properties have already been set.
	// So you can, for example, access the XMPPMessage via message.message.
}

/**
 * Optional override hook for complete customization.
 * Override me if you need to do specific custom work when inserting a message in a room.
 * 
 * @see didInsertMessage:
**/
- (void)insertMessage:(XMPPMessage *)message
             outgoing:(BOOL)isOutgoing
              forRoom:(XMPPRoom *)room
               stream:(XMPPStream *)xmppStream
{
	// Extract needed information
	
	XMPPJID *roomJID = room.roomJID;
	XMPPJID *messageJID = isOutgoing ? room.myRoomJID : [message from];
	
	NSDate *localTimestamp;
	NSDate *remoteTimestamp;
	
	if (isOutgoing)
	{
		localTimestamp = [[NSDate alloc] init];
		remoteTimestamp = nil;
	}
	else
	{
		remoteTimestamp = [message delayedDeliveryDate];
		if (remoteTimestamp) {
			localTimestamp = remoteTimestamp;
		}
		else {
			localTimestamp = [[NSDate alloc] init];
		}
	}
	
	NSString *messageBody = [[message elementForName:@"body"] stringValue];
	
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSString *streamBareJidStr = [[self myJIDForXMPPStream:xmppStream] bare];
	
	NSEntityDescription *messageEntity = [self messageEntity:moc];
	
	// Add to database
	
	XMPPRoomMessageCoreDataStorageObject *roomMessage = (XMPPRoomMessageCoreDataStorageObject *)
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
	
	[moc insertObject:roomMessage];      // Hook if subclassing XMPPRoomMessageCoreDataStorageObject (awakeFromInsert)
	[self didInsertMessage:roomMessage]; // Hook if subclassing XMPPRoomCoreDataStorage
}

/**
 * Optional override hook for general extensions.
 * 
 * @see insertOccupantWithPresence:room:stream:
**/
- (void)didInsertOccupant:(XMPPRoomOccupantCoreDataStorageObject *)occupant
{
	// Override me if you're extending the XMPPRoomOccupantCoreDataStorageObject class to add additional properties.
	// You can update your additional properties here.
	// 
	// At this point the standard XMPPRoomOccupantCDSO properties have already been set.
	// So you can, for example, access the XMPPPresence via occupant.presence.
}

/**
 * Optional override hook for general extensions.
 * 
 * @see updateOccupant:withPresence:room:stream:
**/
- (void)didUpdateOccupant:(XMPPRoomOccupantCoreDataStorageObject *)occupant
{
	// Override me if you're extending the XMPPRoomOccupantCoreDataStorageObject class to add additional properties.
	// You can update your additional properties here.
	// 
	// At this point the standard XMPPRoomOccupantCDSO properties have already been updated.
	// So you can, for example, access the XMPPPresence via occupant.presence.
}

/**
 * Optional override hook for complete customization.
 * Override me if you need to do specific custom work when inserting an occupant in a room.
 * 
 * @see didInsertOccupant:
**/ 
- (void)insertOccupantWithPresence:(XMPPPresence *)presence
                              room:(XMPPRoom *)room
                            stream:(XMPPStream *)xmppStream
{
	// Extract needed information
	
	XMPPJID *roomJID = room.roomJID;
	XMPPJID *presenceJID = [presence from];
	
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
	
	// Add to database
	
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSString *streamBareJidStr = [[self myJIDForXMPPStream:xmppStream] bare];
	
	NSEntityDescription *occupantEntity = [self occupantEntity:moc];
	
	XMPPRoomOccupantCoreDataStorageObject *occupant = (XMPPRoomOccupantCoreDataStorageObject *)
	    [[NSManagedObject alloc] initWithEntity:occupantEntity insertIntoManagedObjectContext:nil];
	
	occupant.presence = presence;
	occupant.roomJID = roomJID;
	occupant.jid = presenceJID;
	occupant.nickname = [presenceJID resource];
	occupant.role = role;
	occupant.affiliation = affiliation;
	occupant.realJID = realJID;
	occupant.createdAt = [NSDate date];
	occupant.streamBareJidStr = streamBareJidStr;
	
	[moc insertObject:occupant];       // Hook if subclassing XMPPRoomOccupantCoreDataStorageObject (awakeFromInsert)
	[self didInsertOccupant:occupant]; // Hook if subclassing XMPPRoomCoreDataStorage
}

/**
 * Optional override hook for complete customization.
 * Override me if you need to do specific custom work when updating an occupant in a room.
 * 
 * @see didUpdateOccupant:
**/
- (void)updateOccupant:(XMPPRoomOccupantCoreDataStorageObject *)occupant
          withPresence:(XMPPPresence *)presence
                  room:(XMPPRoom *)room
                stream:(XMPPStream *)stream
{
	// Extract needed information
	
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
	
	// Update database
	
	occupant.presence = presence;
	occupant.role = role;
	occupant.affiliation = affiliation;
	occupant.realJID = realJID;
	
	[self didUpdateOccupant:occupant]; // Hook if subclassing XMPPRoomCoreDataStorage
}

/**
 * Optional override hook.
**/
- (void)removeOccupant:(XMPPRoomOccupantCoreDataStorageObject *)occupant
          withPresence:(XMPPPresence *)presence
                  room:(XMPPRoom *)room
                stream:(XMPPStream *)stream
{
	// Delete from database
	
	[[occupant managedObjectContext] deleteObject:occupant];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Public API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSEntityDescription *)messageEntity:(NSManagedObjectContext *)moc
{
	// This method should be thread-safe.
	// So be sure to access the entity name through the property accessor.
	
	return [NSEntityDescription entityForName:[self messageEntityName] inManagedObjectContext:moc];
}

- (NSEntityDescription *)occupantEntity:(NSManagedObjectContext *)moc
{
	// This method should be thread-safe.
	// So be sure to access the entity name through the property accessor.
	
	return [NSEntityDescription entityForName:[self occupantEntityName] inManagedObjectContext:moc];
}

- (NSDate *)mostRecentMessageTimestampForRoom:(XMPPJID *)roomJID
                                       stream:(XMPPStream *)xmppStream
                                    inContext:(NSManagedObjectContext *)inMoc
{
	if (roomJID == nil) return nil;
	
	// It's possible to use our internal managedObjectContext only because we're not returning a NSManagedObject.
	
	__block NSDate *result = nil;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		NSManagedObjectContext *moc = inMoc ? : [self managedObjectContext];
		
		NSEntityDescription *entity = [self messageEntity:moc];
		
		NSPredicate *predicate;
		if (xmppStream)
		{
			NSString *streamBareJidStr = [[self myJIDForXMPPStream:xmppStream] bare];
			
			NSString *predicateFormat = @"roomJIDStr == %@ AND streamBareJidStr == %@";
			predicate = [NSPredicate predicateWithFormat:predicateFormat, roomJID.bare, streamBareJidStr];
		}
		else
		{
			predicate = [NSPredicate predicateWithFormat:@"roomJIDStr == %@", roomJID.bare];
		}
		
		NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"localTimestamp" ascending:NO];
		NSArray *sortDescriptors = @[sortDescriptor];
		
		NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
		[fetchRequest setEntity:entity];
		[fetchRequest setPredicate:predicate];
		[fetchRequest setSortDescriptors:sortDescriptors];
		[fetchRequest setFetchLimit:1];
		
		NSError *error = nil;
		XMPPRoomMessageCoreDataStorageObject *message = [[moc executeFetchRequest:fetchRequest error:&error] lastObject];

		if (error)
		{
			XMPPLogError(@"%@: %@ - fetchRequest error: %@", THIS_FILE, THIS_METHOD, error);
		}
		else
		{
			result = [message.localTimestamp copy];
		}
	}};
	
	if (inMoc == nil)
		dispatch_sync(storageQueue, block);
	else
		block();
	
	return result;
}

- (XMPPRoomOccupantCoreDataStorageObject *)occupantForJID:(XMPPJID *)jid
                                                   stream:(XMPPStream *)xmppStream
                                                inContext:(NSManagedObjectContext *)moc
{
	if (jid == nil) return nil;
	if (moc == nil) return nil;
	
	NSEntityDescription *entity = [self occupantEntity:moc];
	
	NSPredicate *predicate;
	if (xmppStream)
	{
		NSString *streamBareJidStr = [[self myJIDForXMPPStream:xmppStream] bare];
		
		NSString *predicateFormat = @"jidStr == %@ AND streamBareJidStr == %@";
		predicate = [NSPredicate predicateWithFormat:predicateFormat, jid, streamBareJidStr];
	}
	else
	{
		predicate = [NSPredicate predicateWithFormat:@"jidStr == %@", jid];
	}
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	[fetchRequest setPredicate:predicate];
	[fetchRequest setFetchBatchSize:1];
	
	NSError *error = nil;
	NSArray *results = [moc executeFetchRequest:fetchRequest error:&error];
	
	if (error)
	{
		XMPPLogWarn(@"%@: %@ - fetch error: %@", THIS_FILE, THIS_METHOD, error);
	}
	
	return (XMPPRoomOccupantCoreDataStorageObject *)[results lastObject];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPRoomStorage Protocol
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)handlePresence:(XMPPPresence *)presence room:(XMPPRoom *)room
{
	XMPPLogTrace();
	
	
	XMPPJID *presenceJID = [presence from];
	XMPPStream *xmppStream = room.xmppStream;
	
	[self scheduleBlock:^{
		
		NSManagedObjectContext *moc = [self managedObjectContext];
		
		// Is occupant already in database?
		
		XMPPRoomOccupantCoreDataStorageObject *occupant = 
		    [self occupantForJID:presenceJID stream:xmppStream inContext:moc];
		
		// Is occupant available or unavailable?
		
		if ([[presence type] isEqualToString:@"unavailable"])
		{
			// Remove occupant record from database
			
			if (occupant)
			{
				[self removeOccupant:occupant withPresence:presence room:room stream:xmppStream];
			}
		}
		else
		{
			// Insert or update occupant in database
			
			if (occupant)
			{
				[self updateOccupant:occupant withPresence:presence room:room stream:xmppStream];
			}
			else
			{
				[self insertOccupantWithPresence:presence room:room stream:xmppStream];
			}
		}
	}];
}

- (void)handleOutgoingMessage:(XMPPMessage *)message room:(XMPPRoom *)room
{
	XMPPLogTrace();
	
	XMPPStream *xmppStream = room.xmppStream;
	
	[self scheduleBlock:^{
		
		[self insertMessage:message outgoing:YES forRoom:room stream:xmppStream];
	}];
}

- (void)handleIncomingMessage:(XMPPMessage *)message room:(XMPPRoom *)room
{
	XMPPLogTrace();
	
	XMPPJID *myRoomJID = room.myRoomJID;
	XMPPJID *messageJID = [message from];
	
	if ([myRoomJID isEqualToJID:messageJID])
	{
		if (![message wasDelayed])
		{
			// Ignore - we already stored message in handleOutgoingMessage:room:
			return;
		}
	}
	
	XMPPStream *xmppStream = room.xmppStream;
	
	[self scheduleBlock:^{
		
		if ([self existsMessage:message forRoom:room stream:xmppStream])
		{
			XMPPLogVerbose(@"%@: %@ - Duplicate message", THIS_FILE, THIS_METHOD);
		}
		else
		{
			[self insertMessage:message outgoing:NO forRoom:room stream:xmppStream];
		}
	}];
}

- (void)handleDidLeaveRoom:(XMPPRoom *)room
{
	XMPPLogTrace();
	
	XMPPJID *roomJID = room.roomJID;
	
	[self scheduleBlock:^{
		
		[self clearAllOccupantsFromRoom:roomJID];
	}];
}

@end
