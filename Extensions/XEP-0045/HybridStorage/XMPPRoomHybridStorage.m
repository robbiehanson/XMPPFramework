#import "XMPPRoomHybridStorage.h"
#import "XMPPRoomPrivate.h"
#import "XMPPCoreDataStorageProtected.h"
#import "XMPPElement+Delay.h"
#import "XMPPLogging.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

/**
 * Does ARC support support GCD objects?
 * It does if the minimum deployment target is iOS 6+ or Mac OS X 10.8+
**/
#if TARGET_OS_IPHONE

  // Compiling for iOS

  #if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000 // iOS 6.0 or later
    #define NEEDS_DISPATCH_RETAIN_RELEASE 0
  #else                                         // iOS 5.X or earlier
    #define NEEDS_DISPATCH_RETAIN_RELEASE 1
  #endif

#else

  // Compiling for Mac OS X

  #if MAC_OS_X_VERSION_MIN_REQUIRED >= 1080     // Mac OS X 10.8 or later
    #define NEEDS_DISPATCH_RETAIN_RELEASE 0
  #else
    #define NEEDS_DISPATCH_RETAIN_RELEASE 1     // Mac OS X 10.7 or earlier
  #endif

#endif

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

#define AssertPrivateQueue() \
            NSAssert(dispatch_get_current_queue() == storageQueue, @"Private method: MUST run on storageQueue");


@interface XMPPRoomHybridStorage ()
{
	// Protected variables are listed in the header file.
	// These are the private variables.
	
	NSString *messageEntityName;
	Class occupantClass;
	
	NSTimeInterval maxMessageAge;
	NSTimeInterval deleteInterval;
	
	NSMutableSet *pausedMessageDeletion;
	
	dispatch_time_t lastDeleteTime;
	dispatch_source_t deleteTimer;
}

- (void)performDelete;
- (void)destroyDeleteTimer;
- (void)updateDeleteTimer;
- (void)createAndStartDeleteTimer;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPRoomHybridStorage

static XMPPRoomHybridStorage *sharedInstance;

+ (XMPPRoomHybridStorage *)sharedInstance
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		sharedInstance = [[XMPPRoomHybridStorage alloc] initWithDatabaseFilename:nil];
	});
	
	return sharedInstance;
}

- (void)commonInit
{
	XMPPLogTrace();
	[super commonInit];
	
	// This method is invoked by all public init methods of the superclass
	
	occupantsGlobalDict = [[NSMutableDictionary alloc] init];
	
	messageEntityName = NSStringFromClass([XMPPRoomMessageHybridCoreDataStorageObject class]);
	occupantClass = [XMPPRoomOccupantHybridMemoryStorageObject class];
	
	maxMessageAge  = (60 * 60 * 24 * 7); // 7 days
	deleteInterval = (60 * 5);           // 5 days
	
	pausedMessageDeletion = [[NSMutableSet alloc] init];
}

/**
 * Documentation from the superclass (XMPPCoreDataStorage):
 * 
 * Override me, if needed, to provide customized behavior.
 * 
 * This method is queried to get the name of the ManagedObjectModel within the app bundle.
 * It should return the name of the appropriate file (*.xdatamodel / *.mom / *.momd) sans file extension.
 * 
 * The default implementation returns the name of the subclass, stripping any suffix of "CoreDataStorage".
 * E.g., if your subclass was named "XMPPExtensionCoreDataStorage", then this method would return "XMPPExtension".
 * 
 * Note that a file extension should NOT be included.
**/
- (NSString *)managedObjectModelName
{
	// Optional hook
	// 
	// The default implementation would return "XMPPPRoomHybridStorage".
	// We prefer a slightly shorter version.
	
	return @"XMPPRoomHybrid";
}

/**
 * Documentation from the superclass (XMPPCoreDataStorage):
 * 
 * Override me, if needed, to provide customized behavior.
 *
 * For example, if you are using the database for non-persistent data and the model changes, you may want
 * to delete the database file if it already exists on disk and a core data migration is not worthwhile.
 *
 * If this instance was created via initWithDatabaseFilename, then the storePath parameter will be non-nil.
 * If this instance was created via initWithInMemoryStore, then the storePath parameter will be nil.
 *
 * The default implementation simply writes to the XMPP error log.
**/
- (void)didNotAddPersistentStoreWithPath:(NSString *)storePath error:(NSError *)error
{
	// Optional hook
	//
    // If we ever have problems opening the database file,
	// it's likely because the model changed or the file became corrupt.
	//
	// In this case we don't have to worry about migrating the data, because it's all stored on servers.
	// So we're just going to delete the sqlite file from disk, and create a new one.
	
	[[NSFileManager defaultManager] removeItemAtPath:storePath error:NULL];
	
	[self addPersistentStoreWithPath:storePath error:NULL];
}

- (void)dealloc
{
	[self destroyDeleteTimer];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Configuration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@synthesize messageEntityName;
@synthesize occupantClass;

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
		[self performDelete];
	}};
	
	if (dispatch_get_current_queue() == storageQueue)
		block();
	else
		dispatch_async(storageQueue, block);
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
		predicate = [NSPredicate predicateWithFormat:@"localTimestamp <= %@ AND roomJIDStr NOT IN %@",
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
	
	for (XMPPRoomMessageHybridCoreDataStorageObject *oldMessage in oldMessages)
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
		#if NEEDS_DISPATCH_RETAIN_RELEASE
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
		
		dispatch_resume(deleteTimer);
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
- (void)didInsertMessage:(XMPPRoomMessageHybridCoreDataStorageObject *)message
{
	// Override me if you're extending the XMPPRoomMessageHybridCoreDataStorageObject class
	// to add additional properties, which you can set here.
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
	
	XMPPRoomMessageHybridCoreDataStorageObject *roomMessage = (XMPPRoomMessageHybridCoreDataStorageObject *)
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
	
	[moc insertObject:roomMessage];      // Hook if subclassing XMPPRoomMessageHybridCDSO (awakeFromInsert)
	[self didInsertMessage:roomMessage]; // Hook if subclassing XMPPRoomHybridStorage
}

/**
 * Optional override hook for general extensions.
 * 
 * @see insertOccupantWithPresence:room:stream:
**/
- (void)didInsertOccupant:(XMPPRoomOccupantHybridMemoryStorageObject *)occupant
{
	// Override me if you're extending the XMPPRoomOccupantHybridMemoryStorageObject class
	// to add additional properties, which you can set here.
	// 
	// At this point the standard properties have already been set.
	// So you can, for example, access the XMPPPresence via occupant.presece.
}

/**
 * Optional override hook for general extensions.
 *
 * @see updateOccupant:withPresence:room:stream:
**/
- (void)didUpdateOccupant:(XMPPRoomOccupantHybridMemoryStorageObject *)occupant
{
	// Override me if you're extending the XMPPRoomOccupantHybridMemoryStorageObject class,
	// and you have additional properties that may need to be updated.
	// 
	// At this point the standard properties have already been updated.
}

/**
 * Optional override hook for general extensions.
**/
- (void)willRemoveOccupant:(XMPPRoomOccupantHybridMemoryStorageObject *)occupant
{
	// Override me if you have any custom work to do before an occupant leaves (is removed from storage).
}

/**
 * Optional override hook for general extensions.
**/
- (void)didRemoveOccupant:(XMPPRoomOccupantHybridMemoryStorageObject *)occupant
{
	// Override me if you have any custom work to do after an occupant leaves (is removed from storage).
}

/**
 * Optional override hook for complete customization.
 * Override me if you need to do custom work when inserting an occupant in a room.
**/ 
- (XMPPRoomOccupantHybridMemoryStorageObject *)insertOccupantWithPresence:(XMPPPresence *)presence
                                                                     room:(XMPPRoom *)room
                                                                   stream:(XMPPStream *)xmppStream
{
	XMPPJID *streamFullJid = [self myJIDForXMPPStream:xmppStream];
	XMPPJID *roomJid = room.roomJID;
	
	NSMutableDictionary *occupantsRoomsDict = [occupantsGlobalDict objectForKey:streamFullJid];
	if (occupantsRoomsDict == nil)
	{
		occupantsRoomsDict = [[NSMutableDictionary alloc] init];
		[occupantsGlobalDict setObject:occupantsRoomsDict forKey:streamFullJid];
	}
	
	NSMutableDictionary *occupantsRoomDict = [occupantsRoomsDict objectForKey:roomJid];
	if (occupantsRoomDict == nil)
	{
		occupantsRoomDict = [[NSMutableDictionary alloc] init];
		[occupantsRoomsDict setObject:occupantsRoomDict forKey:roomJid];
	}
	
	XMPPRoomOccupantHybridMemoryStorageObject *occupant = (XMPPRoomOccupantHybridMemoryStorageObject *)
	    [[self.occupantClass alloc] initWithPresence:presence streamFullJid:streamFullJid];
	
	[occupantsRoomDict setObject:occupant forKey:occupant.jid];
	
	return occupant;
}

/**
 * Optional override hook for complete customization.
 * Override me if you need to do custom work when updating an occupant in a room.
**/
- (void)updateOccupant:(XMPPRoomOccupantHybridMemoryStorageObject *)occupant
          withPresence:(XMPPPresence *)presence
                  room:(XMPPRoom *)room
                stream:(XMPPStream *)stream
{
	
	[occupant updateWithPresence:presence];
}

/**
 * Optional override hook for complete customization.
 * Override me if you need to do custom work when removing an occupant from a room.
**/
- (void)removeOccupant:(XMPPRoomOccupantHybridMemoryStorageObject *)occupant
          withPresence:(XMPPPresence *)presence
                  room:(XMPPRoom *)room
                stream:(XMPPStream *)stream
{
	// Remove from dictionary
	
	XMPPJID *streamFullJid = [self myJIDForXMPPStream:stream];
	XMPPJID *roomJid = occupant.roomJID;
	
	NSMutableDictionary *occupantsRoomsDict = [occupantsGlobalDict objectForKey:streamFullJid];
	NSMutableDictionary *occupantsRoomDict = [occupantsRoomsDict objectForKey:roomJid];
	
	[occupantsRoomDict removeObjectForKey:occupant.jid]; // Remove occupant
	if ([occupantsRoomDict count] == 0)
	{
		[occupantsRoomsDict removeObjectForKey:roomJid]; // Remove room if now empty
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Public API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSEntityDescription *)messageEntity:(NSManagedObjectContext *)moc
{
	// This method should be thread-safe.
	// So be sure to access the entity name through the property accessor.
	
	if (moc == nil)
	{
		XMPPLogWarn(@"%@: %@ - Invalid parameter, moc is nil", THIS_FILE, THIS_METHOD);
		return nil;
	}
	
	NSString *entityName = self.messageEntityName;
	return [NSEntityDescription entityForName:entityName inManagedObjectContext:moc];
}

- (NSDate *)mostRecentMessageTimestampForRoom:(XMPPJID *)roomJID
                                       stream:(XMPPStream *)xmppStream
                                    inContext:(NSManagedObjectContext *)inMoc
{
	if (roomJID == nil) return nil;
	
	// It's possible to use our internal managedObjectContext only because we're not returning a NSManagedObject.
	
	__block NSDate *result = nil;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		NSManagedObjectContext *moc = inMoc ? inMoc : [self managedObjectContext];
		
		NSEntityDescription *entity = [self messageEntity:moc];
		
		NSPredicate *predicate;
		if (xmppStream)
		{
			NSString *streamBareJidStr = [[self myJIDForXMPPStream:xmppStream] bare];
			
			NSString *predicateFormat = @"roomJIDStr == %@ AND streamBareJidStr == %@";
			predicate = [NSPredicate predicateWithFormat:predicateFormat, roomJID, streamBareJidStr];
		}
		else
		{
			predicate = [NSPredicate predicateWithFormat:@"roomJIDStr == %@", roomJID];
		}
		
		NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"localTimestamp" ascending:NO];
		NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
		
		NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
		[fetchRequest setEntity:entity];
		[fetchRequest setPredicate:predicate];
		[fetchRequest setSortDescriptors:sortDescriptors];
		[fetchRequest setFetchLimit:1];
		
		NSError *error = nil;
		XMPPRoomMessageHybridCoreDataStorageObject *message = (XMPPRoomMessageHybridCoreDataStorageObject *)
		    [[moc executeFetchRequest:fetchRequest error:&error] lastObject];

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

- (XMPPRoomOccupantHybridMemoryStorageObject *)occupantForJID:(XMPPJID *)occupantJid stream:(XMPPStream *)xmppStream
{
	if (occupantJid == nil) return nil;
	
	__block XMPPRoomOccupantHybridMemoryStorageObject *occupant = nil;
	
	void (^block)(BOOL) = ^(BOOL shouldCopy){ @autoreleasepool {
		
		XMPPJID *roomJid = [occupantJid bareJID];
		
		if (xmppStream)
		{
			XMPPJID *streamFullJid = [self myJIDForXMPPStream:xmppStream];
			
			NSDictionary *occupantsRoomsDict = [occupantsGlobalDict objectForKey:streamFullJid];
			NSDictionary *occupantsRoomDict = [occupantsRoomsDict objectForKey:roomJid];
			
			occupant = [occupantsRoomDict objectForKey:occupantJid];
		}
		else
		{
			for (XMPPJID *streamFullJid in occupantsGlobalDict)
			{
				NSDictionary *occupantsRoomsDict = [occupantsGlobalDict objectForKey:streamFullJid];
				NSDictionary *occupantsRoomDict = [occupantsRoomsDict objectForKey:roomJid];
								
				occupant = [occupantsRoomDict objectForKey:occupantJid];
				if (occupant) break;
			}
		}
		
		if (shouldCopy)
		{
			occupant = [occupant copy];
		}
	}};
	
	if (dispatch_get_current_queue() == storageQueue)
		block(NO);
	else
		dispatch_sync(storageQueue, ^{ block(YES); });
	
	return occupant;
}

- (NSArray *)occupantsForRoom:(XMPPJID *)roomJid stream:(XMPPStream *)xmppStream
{
	roomJid = [roomJid bareJID]; // Just in case a full jid is accidentally passed
	
	__block NSArray *results = nil;
	
	void (^block)(BOOL) = ^(BOOL shouldCopy){ @autoreleasepool {
		
		if (xmppStream)
		{
			XMPPJID *streamFullJid = [self myJIDForXMPPStream:xmppStream];
			
			NSDictionary *occupantsRoomsDict = [occupantsGlobalDict objectForKey:streamFullJid];
			NSDictionary *occupantsRoomDict = [occupantsRoomsDict objectForKey:roomJid];
			
			results = [occupantsRoomDict allValues];
		}
		else
		{
			for (XMPPJID *streamFullJid in occupantsGlobalDict)
			{
				NSDictionary *occupantsRoomsDict = [occupantsGlobalDict objectForKey:streamFullJid];
				NSDictionary *occupantsRoomDict = [occupantsRoomsDict objectForKey:roomJid];
				
				if (occupantsRoomDict)
				{
					results = [occupantsRoomDict allValues];
					break;
				}
			}
		}
		
		if (shouldCopy)
		{
			NSArray *temp = results;
			results = [[NSArray alloc] initWithArray:temp copyItems:YES];
		}
	}};
	
	if (dispatch_get_current_queue() == storageQueue)
		block(NO);
	else
		dispatch_sync(storageQueue, ^{ block(YES); });
	
	return results;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPRoomStorage Protocol
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)handlePresence:(XMPPPresence *)presence room:(XMPPRoom *)room
{
	XMPPLogTrace();
	
	dispatch_queue_t roomQueue = room.moduleQueue;
	XMPPStream *xmppStream = room.xmppStream;
	
	[self scheduleBlock:^{
		
		XMPPJID *from = [presence from];
		
		if ([[presence type] isEqualToString:@"unavailable"])
		{
			XMPPRoomOccupantHybridMemoryStorageObject *occupant = [self occupantForJID:from stream:xmppStream];
			if (occupant)
			{
				// Occupant did leave - remove
				
				[self willRemoveOccupant:occupant];
				[self removeOccupant:occupant withPresence:presence room:room stream:xmppStream];
				[self didRemoveOccupant:occupant];
				
				// Notify delegate(s)
				
				XMPPRoomOccupantHybridMemoryStorageObject *occupantCopy = [occupant copy];
				dispatch_async(roomQueue, ^{ @autoreleasepool {
					
					GCDMulticastDelegate <XMPPRoomHybridStorageDelegate> *roomMulticastDelegate =
					    (GCDMulticastDelegate <XMPPRoomHybridStorageDelegate> *)[room multicastDelegate];
					
					[roomMulticastDelegate xmppRoomHybridStorage:self
					                            occupantDidLeave:occupantCopy];
				}});
			}
		}
		else
		{
			XMPPRoomOccupantHybridMemoryStorageObject *occupant = [self occupantForJID:from stream:xmppStream];
			if (occupant == nil)
			{
				// Occupant did join - add
				
				occupant = [self insertOccupantWithPresence:presence room:room stream:xmppStream];
				if (occupant == nil)
				{
					// Subclasses may choose to ignore occupants for whatever reason.
					return;
				}
				
				[self didInsertOccupant:occupant];
				
				// Notify delegate(s)
				
				XMPPRoomOccupantHybridMemoryStorageObject *occupantCopy = [occupant copy];
				dispatch_async(roomQueue, ^{ @autoreleasepool {
				
					GCDMulticastDelegate <XMPPRoomHybridStorageDelegate> *roomMulticastDelegate =
					    (GCDMulticastDelegate <XMPPRoomHybridStorageDelegate> *)[room multicastDelegate];
					
					[roomMulticastDelegate xmppRoomHybridStorage:self
					                             occupantDidJoin:occupantCopy];
				}});
			}
			else
			{
				// Occupant did update - move
				
				[self updateOccupant:occupant withPresence:presence room:room stream:xmppStream];
				[self didUpdateOccupant:occupant];
				
				// Notify delegate(s)
				
				XMPPRoomOccupantHybridMemoryStorageObject *occupantCopy = [occupant copy];
				dispatch_async(roomQueue, ^{ @autoreleasepool {
					
					GCDMulticastDelegate <XMPPRoomHybridStorageDelegate> *roomMulticastDelegate =
					    (GCDMulticastDelegate <XMPPRoomHybridStorageDelegate> *)[room multicastDelegate];
					
					[roomMulticastDelegate xmppRoomHybridStorage:self
					                           occupantDidUpdate:occupantCopy];
				}});
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
	
	XMPPJID *roomJid = room.roomJID;
	XMPPStream *xmppStream = room.xmppStream;
	
	[self scheduleBlock:^{
		
		XMPPJID *streamFullJid = [self myJIDForXMPPStream:xmppStream];
		
		NSMutableDictionary *occupantsRoomsDict = [occupantsGlobalDict objectForKey:streamFullJid];
		
		[occupantsRoomsDict removeObjectForKey:roomJid]; // Remove room (and all associated occupants)
	}];
}

@end
