#import "XMPPRosterCoreDataStorage.h"
#import "XMPPRosterPrivate.h"
#import "XMPPUserCoreDataStorage.h"
#import "XMPPResourceCoreDataStorage.h"
#import "XMPP.h"
#import "XMPPInternal.h"
#import "XMPPLogging.h"
#import "DDNumber.h"

#import <objc/runtime.h>
#import <libkern/OSAtomic.h>

// Log levels: off, error, warn, info, verbose
static const int xmppLogLevel = XMPP_LOG_LEVEL_VERBOSE | XMPP_LOG_FLAG_TRACE;

// Defines how big the unsavedCount can get before triggering a database save operation.
// This has to do with the number of unsaved NSManagedObject's.
// 
// Note: A save will automatically get triggered when there are no outstanding requests.
// This simply serves to restrict memory usage, as unsaved NSManagedObject's remain in memory until saved.
// 
// Note: This also acts as a fetchBatchSize for NSFetchRequests.
// 
#define MAX_UNSAVED_COUNT 500

#define AUTORELEASED_BLOCK(block) ^{                            \
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; \
    block();                                                    \
    [pool drain];                                               \
}


@implementation XMPPRosterCoreDataStorage

static NSMutableSet *databaseFileNames;
static XMPPRosterCoreDataStorage *sharedInstance;

+ (void)initialize
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		databaseFileNames = [[NSMutableSet alloc] init];
	});
}

+ (XMPPRosterCoreDataStorage *)sharedInstance
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		sharedInstance = [[XMPPRosterCoreDataStorage alloc] initWithDatabaseFilename:nil];
	});
	
	return sharedInstance;
}

+ (BOOL)registerDatabaseFileName:(NSString *)dbFileName
{
	BOOL result = NO;
	
	@synchronized(databaseFileNames)
	{
		if (![databaseFileNames containsObject:dbFileName])
		{
			[databaseFileNames addObject:dbFileName];
			result = YES;
		}
	}
	
	return result;
}

+ (void)unregisterDatabaseFileName:(NSString *)dbFileName
{
	@synchronized(databaseFileNames)
	{
		[databaseFileNames removeObject:dbFileName];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Module Setup
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@synthesize databaseFileName;

- (id)initWithDatabaseFilename:(NSString *)aDatabaseFileName
{
	if ((self = [super init]))
	{
		if (aDatabaseFileName)
			databaseFileName = [aDatabaseFileName copy];
		else
			databaseFileName = @"XMPPRoster.sqlite";
		
		if (![[self class] registerDatabaseFileName:databaseFileName])
		{
			[self dealloc];
			return nil;
		}
		
		myJidCache = [[NSMutableDictionary alloc] init];
		
		storageQueue = dispatch_queue_create(class_getName([self class]), NULL);
		
		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(updateJidCache:)
		                                             name:XMPPStreamDidChangeMyJIDNotification
		                                           object:nil];
	}
	return self;
}

- (BOOL)configureWithParent:(XMPPRoster *)aParent queue:(dispatch_queue_t)queue
{
	NSParameterAssert(aParent != nil);
	NSParameterAssert(queue != NULL);
	
	if (queue == storageQueue)
	{
		// This class is designed to be run on a separate dispatch queue from its parent.
		// This allows us to optimize the database save operations by buffering them,
		// and executing them when demand on the storage instance is low.
		
		return NO;
	}
	
	return YES;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Stream JID Caching
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// We cache a stream's myJID to avoid constantly querying the xmppStream for it.
// 
// The motivation behind this is the fact that to query the xmppStream for its myJID
// requires going through the xmppStream's internal dispatch queue. (A dispatch_sync).
// It's not necessarily that this is an expensive operation,
// but the storage classes require this information for just about every operation it performs.
// In addition, if we can stay out of xmppStream's internal dispatch queue,
// we free it to perform more xmpp processing tasks.

- (NSString *)streamBareJidStrForXMPPStream:(XMPPStream *)stream
{
	NSNumber *key = [[NSNumber alloc] initWithPtr:stream];
	
	NSString *result = (NSString *)[myJidCache objectForKey:key];
	if (!result)
	{
		result = [[stream myJID] bare];
		
		if (result)
			[myJidCache setObject:result forKey:key];
		else
			[myJidCache removeObjectForKey:key];
	}
	
	[key release];
	return result;
}

- (void)updateJidCache:(NSNotification *)notification
{
	// Notifications are delivered on the thread/queue that posted them.
	// In this case, they are delivered on xmppStream's internal processing queue.
	
	XMPPStream *stream = (XMPPStream *)[notification object];
	
	dispatch_async(storageQueue, ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		NSNumber *key = [NSNumber numberWithPtr:stream];
		if ([myJidCache objectForKey:key])
		{
			NSString *newBareJidStr = [[stream myJID] bare];
			
			if (newBareJidStr)
				[myJidCache setObject:newBareJidStr forKey:key];
			else
				[myJidCache removeObjectForKey:key];
		}
		
		[pool drain];
	});
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Core Data Setup
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)persistentStoreDirectory
{
#if TARGET_OS_IPHONE
	
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *result = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
	
#else
	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
	
	NSString *result = [basePath stringByAppendingPathComponent:@"XMPPStream"];
	
#endif
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	if(![fileManager fileExistsAtPath:result])
	{
		[fileManager createDirectoryAtPath:result withIntermediateDirectories:YES attributes:nil error:nil];
	}
	
    return result;
}

- (NSManagedObjectModel *)managedObjectModel
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	if (storageQueue == NULL)
	{
		XMPPLogWarn(@"%@: Method(%@) invoked before storage configured by parent.", THIS_FILE, THIS_METHOD);
		return nil;
	}
	
	dispatch_block_t block = ^{
		
		if (managedObjectModel)
		{
			return;
		}
		
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		XMPPLogVerbose(@"%@: Creating managedObjectModel", THIS_FILE);
		
		NSString *path = [[NSBundle mainBundle] pathForResource:@"XMPPRoster" ofType:@"mom"];
		if (path)
		{
			// If path is nil, then NSURL or NSManagedObjectModel will throw an exception
			
			NSURL *url = [NSURL fileURLWithPath:path];
			
			managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
		}
		
		[pool drain];
	};
	
	if (dispatch_get_current_queue() == storageQueue)
		block();
	else
		dispatch_sync(storageQueue, block);
	
	return managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	if (storageQueue == NULL)
	{
		XMPPLogWarn(@"%@: Method(%@) invoked before storage configured by parent.", THIS_FILE, THIS_METHOD);
		return nil;
	}
	
	dispatch_block_t block = ^{
		
		if (persistentStoreCoordinator)
		{
			return;
		}
		
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		NSManagedObjectModel *mom = [self managedObjectModel];
		
		XMPPLogVerbose(@"%@: Creating persistentStoreCoordinator", THIS_FILE);
		
		persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
		
		NSString *docsPath = [self persistentStoreDirectory];
		NSString *storePath = [docsPath stringByAppendingPathComponent:databaseFileName];
		if (storePath)
		{
			if ([[NSFileManager defaultManager] fileExistsAtPath:storePath])
			{
				[[NSFileManager defaultManager] removeItemAtPath:storePath error:nil];
			}
			
			// If storePath is nil, then NSURL will throw an exception
			
			NSURL *storeUrl = [NSURL fileURLWithPath:storePath];
			
			NSError *error = nil;
			NSPersistentStore *persistentStore;
			persistentStore = [persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
																	   configuration:nil
																			  URL:storeUrl
																		  options:nil
																			error:&error];
			if (!persistentStore)
			{
			  #if TARGET_OS_IPHONE
				XMPPLogError(@"%@:\n"
							 @"====================================================================================="
							 @"Error creating persistent store:\n%@"
							 @"Chaned core data model recently?"
							 @"Quick Fix: Delete the app from device and reinstall."
							 @"=====================================================================================",
							 THIS_FILE, error);
			  #else
				XMPPLogError(@"%@:\n"
							 @"====================================================================================="
							 @"Error creating persistent store:\n%@"
							 @"Chaned core data model recently?"
							 @"Quick Fix: Delete the database: %@"
							 @"=====================================================================================",
							 THIS_FILE, error, storePath);
			  #endif
			}
		}
		
		[pool drain];
	};
	
	if (dispatch_get_current_queue() == storageQueue)
		block();
	else
		dispatch_sync(storageQueue, block);
	
    return persistentStoreCoordinator;
}

- (NSManagedObjectContext *)managedObjectContext
{
	// This is a private method.
	
	if (managedObjectContext)
	{
		return managedObjectContext;
	}
	
	NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
	if (coordinator)
	{
		XMPPLogVerbose(@"%@: Creating managedObjectContext", THIS_FILE);
		
		managedObjectContext = [[NSManagedObjectContext alloc] init];
		[managedObjectContext setPersistentStoreCoordinator:coordinator];
	}
	
	return managedObjectContext;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * For some bizarre reason (in my opinion), when you request your roster,
 * the server will return JID's NOT in your roster.
 * These are the JID's of users who have requested to be alerted to our presence.
 * After we sign in, we'll again be notified, via the normal presence request objects.
 * It's redundant, and annoying, and just plain incorrect to include these JID's when we request our personal roster.
 * So now, we have to go to the extra effort to filter out these JID's, which is exactly what this method does.
**/
- (BOOL)isRosterItem:(NSXMLElement *)item
{
	NSString *subscription = [item attributeStringValueForName:@"subscription"];
	if ([subscription isEqualToString:@"none"])
	{
		NSString *ask = [item attributeStringValueForName:@"ask"];
		if ([ask isEqualToString:@"subscribe"])
		{
			return YES;
		}
		else
		{
			return NO;
		}
	}
	
	return YES;
}

- (void)save
{
	if ([[self managedObjectContext] hasChanges])
	{
		NSError *error = nil;
		if (![[self managedObjectContext] save:&error])
		{
			XMPPLogWarn(@"%@: Error saving - %@ %@", [self class], error, [error userInfo]);
			
			[[self managedObjectContext] rollback];
		}
	}
	
	unsavedCount = 0;
}

- (void)maybeSave:(int32_t)currentPendingRequests
{
	NSAssert(dispatch_get_current_queue() == storageQueue, @"Invoked on incorrect queue");
	
	if (unsavedCount > 0)
	{
		if ((currentPendingRequests == 0) || (unsavedCount >= MAX_UNSAVED_COUNT))
		{
			XMPPLogVerbose(@"%@: Triggering save (pendingRequests=%i, unsavedCount=%i)",
							  [self class], currentPendingRequests, unsavedCount);
			
			[self save];
		}
	}
}

- (void)executeBlock:(dispatch_block_t)block
{
	// By design this method should not be invoked from the storageQueue.
	NSAssert(dispatch_get_current_queue() != storageQueue, @"Invoked on incorrect queue");
	
	// dispatch_Sync
	//          ^
	
	OSAtomicIncrement32(&pendingRequests);
	dispatch_sync(storageQueue, ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		block();
		
		[self maybeSave:OSAtomicDecrement32(&pendingRequests)];
		[pool drain];
	});
}

- (void)scheduleBlock:(dispatch_block_t)block
{
	// By design this method should not be invoked from the storageQueue.
	NSAssert(dispatch_get_current_queue() != storageQueue, @"Invoked on incorrect queue");
	
	// dispatch_Async
	//          ^
	
	OSAtomicIncrement32(&pendingRequests);
	dispatch_async(storageQueue, ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		block();
		
		[self maybeSave:OSAtomicDecrement32(&pendingRequests)];
		[pool drain];
	});
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Protocol Public API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id <XMPPUser>)myUserForXMPPStream:(XMPPStream *)stream
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	XMPPJID *myJID = stream.myJID;
	if (myJID == nil)
	{
		return nil;
	}
	
	__block XMPPUserCoreDataStorage *result;
	
	[self executeBlock:^{
	
		result = [[self userForJID:myJID xmppStream:stream] retain];
	}];
	
	return [result autorelease];
}

- (id <XMPPResource>)myResourceForXMPPStream:(XMPPStream *)stream
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	XMPPJID *myJID = stream.myJID;
	if (myJID == nil)
	{
		return nil;
	}
	
	__block XMPPResourceCoreDataStorage *result;
	
	[self executeBlock:^{
		
		result = [[self resourceForJID:myJID xmppStream:stream] retain];
	}];
	
	return [result autorelease];
}

- (id <XMPPUser>)userForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	// 
	// This method is also called internally.
	
	XMPPLogTrace();
	
	if (jid == nil) return nil;
	
	NSString *bareJIDStr = [jid bare];
	
	__block XMPPUserCoreDataStorage *result;
	
	dispatch_block_t block = ^{
		
		NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPUserCoreDataStorage"
		                                          inManagedObjectContext:[self managedObjectContext]];
		
		NSPredicate *predicate;
		if (stream == nil)
			predicate = [NSPredicate predicateWithFormat:@"jidStr == %@", bareJIDStr];
		else
			predicate = [NSPredicate predicateWithFormat:@"jidStr == %@ AND streamBareJidStr == %@",
			                                                 bareJIDStr, [self streamBareJidStrForXMPPStream:stream]];
		
		NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
		[fetchRequest setEntity:entity];
		[fetchRequest setPredicate:predicate];
		[fetchRequest setIncludesPendingChanges:YES];
		[fetchRequest setFetchLimit:1];
		
		NSArray *results = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
		
		[fetchRequest release];
		
		result = (XMPPUserCoreDataStorage *)[results lastObject];
	};
	
	if (dispatch_get_current_queue() == storageQueue)
	{
		block();
		return result;
	}
	else
	{
		[self executeBlock:^{
			
			block();
			[result retain];
		}];
		
		return [result autorelease];
	}
}

- (id <XMPPResource>)resourceForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	// 
	// This method is also called internally.
	
	XMPPLogTrace();
	
	if (jid == nil) return nil;
	
	NSString *fullJIDStr = [jid full];
	
	__block XMPPResourceCoreDataStorage *result;
	
	dispatch_block_t block = ^{
		
		NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPResourceCoreDataStorage"
		                                          inManagedObjectContext:[self managedObjectContext]];
		
		NSPredicate *predicate;
		if (stream == nil)
			predicate = [NSPredicate predicateWithFormat:@"jidStr == %@", fullJIDStr];
		else
			predicate = [NSPredicate predicateWithFormat:@"jidStr == %@ AND streamBareJidStr == %@",
			                                                 fullJIDStr, [self streamBareJidStrForXMPPStream:stream]];
		
		NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
		[fetchRequest setEntity:entity];
		[fetchRequest setPredicate:predicate];
		[fetchRequest setIncludesPendingChanges:YES];
		[fetchRequest setFetchLimit:1];
		
		NSArray *results = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
		
		[fetchRequest release];
		
		result = (XMPPResourceCoreDataStorage *)[results lastObject];
	};
	
	if (dispatch_get_current_queue() == storageQueue)
	{
		block();
		return result;
	}
	else
	{
		[self executeBlock:^{
			
			block();
			[result retain];
		}];
		
		return [result autorelease];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Protocol Private API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)beginRosterPopulationForXMPPStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	[self scheduleBlock:^{
		
		[rosterPopulationSet addObject:[NSNumber numberWithPtr:stream]];
	}];
}

- (void)endRosterPopulationForXMPPStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	[self scheduleBlock:^{
		
		[rosterPopulationSet removeObject:[NSNumber numberWithPtr:stream]];
	}];
}

- (void)handleRosterItem:(NSXMLElement *)item xmppStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	[self scheduleBlock:^{
		
		if ([self isRosterItem:item])
		{
			if ([rosterPopulationSet containsObject:[NSNumber numberWithPtr:stream]])
			{
				NSString *streamBareJidStr = [self streamBareJidStrForXMPPStream:stream];
				
				unsavedCount++;
				[XMPPUserCoreDataStorage insertInManagedObjectContext:[self managedObjectContext]
				                                             withItem:item
				                                     streamBareJidStr:streamBareJidStr];
			}
			else
			{
				NSString *jidStr = [item attributeStringValueForName:@"jid"];
				XMPPJID *jid = [[XMPPJID jidWithString:jidStr] bareJID];
				
				XMPPUserCoreDataStorage *user = (XMPPUserCoreDataStorage *)[self userForJID:jid xmppStream:stream];
				
				NSString *subscription = [item attributeStringValueForName:@"subscription"];
				if ([subscription isEqualToString:@"remove"])
				{
					if (user)
					{
						unsavedCount++;
						[[self managedObjectContext] deleteObject:user];
					}
				}
				else
				{
					if (user)
					{
						unsavedCount++;
						[user updateWithItem:item];
					}
					else
					{
						NSString *streamBareJidStr = [self streamBareJidStrForXMPPStream:stream];
						
						unsavedCount++;
						[XMPPUserCoreDataStorage insertInManagedObjectContext:[self managedObjectContext]
						                                             withItem:item
						                                     streamBareJidStr:streamBareJidStr];
					}
				}
			}
		}
	}];
}

- (void)handlePresence:(XMPPPresence *)presence xmppStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	[self scheduleBlock:^{
		
		XMPPJID *jid = [presence from];
		XMPPUserCoreDataStorage *user = (XMPPUserCoreDataStorage *)[self userForJID:jid xmppStream:stream];
		
		if (user)
		{
			unsavedCount++;
			[user updateWithPresence:presence streamBareJidStr:[self streamBareJidStrForXMPPStream:stream]];
		}
	}];
}

- (void)clearAllResourcesForXMPPStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	[self scheduleBlock:^{
		
		NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPResourceCoreDataStorage"
		                                          inManagedObjectContext:[self managedObjectContext]];
		
		NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
		[fetchRequest setEntity:entity];
		[fetchRequest setFetchBatchSize:MAX_UNSAVED_COUNT];
		
		if (stream)
		{
			NSPredicate *predicate;
			predicate = [NSPredicate predicateWithFormat:@"streamBareJidStr == %@",
			                                    [self streamBareJidStrForXMPPStream:stream]];
			
			[fetchRequest setPredicate:predicate];
		}
		
		NSArray *allResources = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
		
		[fetchRequest release];
		
		for (XMPPResourceCoreDataStorage *resource in allResources)
		{
			[[self managedObjectContext] deleteObject:resource];
			
			if (++unsavedCount >= MAX_UNSAVED_COUNT)
			{
				[self save];
			}
		}
	}];
}

- (void)clearAllUsersAndResourcesForXMPPStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	[self scheduleBlock:^{
		
		// Note: Deleting a user will delete all associated resources because of the cascade rule in our core data model.
		
		NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPUserCoreDataStorage"
												  inManagedObjectContext:[self managedObjectContext]];
		
		NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
		[fetchRequest setEntity:entity];
		[fetchRequest setFetchBatchSize:MAX_UNSAVED_COUNT];
		
		if (stream)
		{
			NSPredicate *predicate;
			predicate = [NSPredicate predicateWithFormat:@"streamBareJidStr == %@",
			                            [self streamBareJidStrForXMPPStream:stream]];
			
			[fetchRequest setPredicate:predicate];
		}
		
		NSArray *allUsers = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
		
		[fetchRequest release];
		
		for (XMPPUserCoreDataStorage *user in allUsers)
		{
			[[self managedObjectContext] deleteObject:user];
			
			if (++unsavedCount >= MAX_UNSAVED_COUNT)
			{
				[self save];
			}
		}
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Memory Management
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[[self class] unregisterDatabaseFileName:databaseFileName];
	
	[databaseFileName release];
	[myJidCache release];
	
	if (storageQueue)
	{
		dispatch_release(storageQueue);
	}
	
	[rosterPopulationSet release];
	
	[managedObjectContext release];
	[persistentStoreCoordinator release];
	[managedObjectModel release];
	
	[super dealloc];
}

@end
