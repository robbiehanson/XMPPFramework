#import "XMPPCoreDataStorage.h"
#import "XMPPStream.h"
#import "XMPPInternal.h"
#import "XMPPJID.h"
#import "XMPPLogging.h"
#import "NSNumber+XMPP.h"

#import <objc/runtime.h>
#import <libkern/OSAtomic.h>

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif


@implementation XMPPCoreDataStorage

static NSMutableSet *databaseFileNames;

+ (void)initialize
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		databaseFileNames = [[NSMutableSet alloc] init];
	});
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
#pragma mark Override Me
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)managedObjectModelName
{
	// Override me, if needed, to provide customized behavior.
	// 
	// This method is queried to get the name of the ManagedObjectModel within the app bundle.
	// It should return the name of the appropriate file (*.xdatamodel / *.mom / *.momd) sans file extension.
	// 
	// The default implementation returns the name of the subclass, stripping any suffix of "CoreDataStorage".
	// E.g., if your subclass was named "XMPPExtensionCoreDataStorage", then this method would return "XMPPExtension".
	// 
	// Note that a file extension should NOT be included.
	
	NSString *className = NSStringFromClass([self class]);
	NSString *suffix = @"CoreDataStorage";
	
	if ([className hasSuffix:suffix] && ([className length] > [suffix length]))
	{
		return [className substringToIndex:([className length] - [suffix length])];
	}
	else
	{
		return className;
	}
}

- (NSString *)defaultDatabaseFileName
{
	// Override me, if needed, to provide customized behavior.
	// 
	// This method is queried if the initWithDatabaseFileName method is invoked with a nil parameter.
	// 
	// You are encouraged to use the sqlite file extension.
	
	return [NSString stringWithFormat:@"%@.sqlite", [self managedObjectModelName]];
}

- (void)willCreatePersistentStoreWithPath:(NSString *)storePath
{
	// Override me, if needed, to provide customized behavior.
	// 
	// If you are using a database file with pure non-persistent data (e.g. for memory optimization purposes on iOS),
	// you may want to delete the database file if it already exists on disk.
	// 
	// If this instance was created via initWithDatabaseFilename, then the storePath parameter will be non-nil.
	// If this instance was created via initWithInMemoryStore, then the storePath parameter will be nil.
}

- (BOOL)addPersistentStoreWithPath:(NSString *)storePath error:(NSError **)errorPtr
{
	// Override me, if needed, to completely customize the persistent store.
	// 
	// Adds the persistent store path to the persistent store coordinator.
	// Returns true if the persistent store is created.
	// 
	// If this instance was created via initWithDatabaseFilename, then the storePath parameter will be non-nil.
	// If this instance was created via initWithInMemoryStore, then the storePath parameter will be nil.
			
    NSPersistentStore *persistentStore;
	
	if (storePath)
	{
		// SQLite persistent store
		
		NSURL *storeUrl = [NSURL fileURLWithPath:storePath];
		
		// Default support for automatic lightweight migrations
		NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
		                         [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
		                         [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, 
		                         nil];
		
		persistentStore = [persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
		                                                           configuration:nil
		                                                                     URL:storeUrl
		                                                                 options:options
		                                                                   error:errorPtr];
	}
	else
	{
		// In-Memory persistent store
		
		persistentStore = [persistentStoreCoordinator addPersistentStoreWithType:NSInMemoryStoreType
		                                                           configuration:nil
		                                                                     URL:nil
		                                                                 options:nil
		                                                                   error:errorPtr];
	}
	
    return persistentStore != nil;
}

- (void)didNotAddPersistentStoreWithPath:(NSString *)storePath error:(NSError *)error
{
    // Override me, if needed, to provide customized behavior.
	// 
	// For example, if you are using the database for non-persistent data and the model changes, 
    // you may want to delete the database file if it already exists on disk.
    
#if TARGET_OS_IPHONE
    XMPPLogError(@"%@:\n"
                 @"=====================================================================================\n"
                 @"Error creating persistent store:\n%@\n"
                 @"Chaned core data model recently?\n"
                 @"Quick Fix: Delete the app from device and reinstall.\n"
                 @"=====================================================================================",
                 [self class], error);
#else
    XMPPLogError(@"%@:\n"
                 @"=====================================================================================\n"
                 @"Error creating persistent store:\n%@\n"
                 @"Chaned core data model recently?\n"
                 @"Quick Fix: Delete the database: %@\n"
                 @"=====================================================================================",
                 [self class], error, storePath);
#endif

}

- (void)didCreateManagedObjectContext
{
	// Override me to provide customized behavior.
	// 
	// For example, you may want to perform cleanup of any non-persistent data before you start using the database.
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Setup
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@synthesize databaseFileName;

- (void)commonInit
{
	saveThreshold = 500;
	storageQueue = dispatch_queue_create(class_getName([self class]), NULL);
	
	myJidCache = [[NSMutableDictionary alloc] init];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(updateJidCache:)
	                                             name:XMPPStreamDidChangeMyJIDNotification
	                                           object:nil];
}

- (id)init
{
    return [self initWithDatabaseFilename:nil];
}

- (id)initWithDatabaseFilename:(NSString *)aDatabaseFileName
{
	if ((self = [super init]))
	{
		if (aDatabaseFileName)
			databaseFileName = [aDatabaseFileName copy];
		else
			databaseFileName = [[self defaultDatabaseFileName] copy];
		
		if (![[self class] registerDatabaseFileName:databaseFileName])
		{
			return nil;
		}
		
		[self commonInit];
		NSAssert(storageQueue != NULL, @"Subclass forgot to invoke [super commonInit]");
	}
	return self;
}

- (id)initWithInMemoryStore
{
	if ((self = [super init]))
	{
		[self commonInit];
		NSAssert(storageQueue != NULL, @"Subclass forgot to invoke [super commonInit]");
	}
	return self;
}

- (BOOL)configureWithParent:(id)aParent queue:(dispatch_queue_t)queue
{
	// This is the standard configure method used by xmpp extensions to configure a storage class.
	// 
	// Feel free to override this method if needed,
	// and just invoke super at some point to make sure everything is kosher at this level as well.
	
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

- (NSUInteger)saveThreshold
{
	if (dispatch_get_current_queue() == storageQueue)
	{
		return saveThreshold;
	}
	else
	{
		__block NSUInteger result;
		
		dispatch_sync(storageQueue, ^{
			result = saveThreshold;
		});
		
		return result;
	}
}

- (void)setSaveThreshold:(NSUInteger)newSaveThreshold
{
	dispatch_block_t block = ^{
		saveThreshold = newSaveThreshold;
	};
	
	if (dispatch_get_current_queue() == storageQueue)
		block();
	else
		dispatch_async(storageQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Stream JID Caching
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// We cache a stream's myJID to avoid constantly querying the xmppStream for it.
// 
// The motivation behind this is the fact that to query the xmppStream for its myJID
// requires going through the xmppStream's internal dispatch queue. (A dispatch_sync).
// It's not necessarily that this is an expensive operation,
// but the storage classes sometimes require this information for just about every operation they perform.
// For a variable that changes infrequently, caching the value can reduce some overhead.
// In addition, if we can stay out of xmppStream's internal dispatch queue,
// we free it to perform more xmpp processing tasks.

- (XMPPJID *)myJIDForXMPPStream:(XMPPStream *)stream
{
	__block XMPPJID *result = nil;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		NSNumber *key = [NSNumber numberWithPtr:(__bridge void *)stream];
		
		result = (XMPPJID *)[myJidCache objectForKey:key];
		if (!result)
		{
			result = [stream myJID];
			
			if (result)
			{
				[myJidCache setObject:result forKey:key];
			}
		}
	}};
	
	if (dispatch_get_current_queue() == storageQueue)
		block();
	else
		dispatch_sync(storageQueue, block);
	
	return result;
}

- (void)updateJidCache:(NSNotification *)notification
{
	// Notifications are delivered on the thread/queue that posted them.
	// In this case, they are delivered on xmppStream's internal processing queue.
	
	XMPPStream *stream = (XMPPStream *)[notification object];
	
	dispatch_async(storageQueue, ^{ @autoreleasepool {
		
		NSNumber *key = [NSNumber numberWithPtr:(__bridge void *)stream];
		if ([myJidCache objectForKey:key])
		{
			XMPPJID *newMyJID = [stream myJID];
			
			if (newMyJID)
				[myJidCache setObject:newMyJID forKey:key];
			else
				[myJidCache removeObjectForKey:key];
		}
		
	}});
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Core Data Setup
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)persistentStoreDirectory
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
	
	// Attempt to find a name for this application
	NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
	if (appName == nil) {
		appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];	
	}
	
	if (appName == nil) {
		appName = @"xmppframework";
	}
	
	
	NSString *result = [basePath stringByAppendingPathComponent:appName];
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	if (![fileManager fileExistsAtPath:result])
	{
		[fileManager createDirectoryAtPath:result withIntermediateDirectories:YES attributes:nil error:nil];
	}
	
    return result;
}

- (NSManagedObjectModel *)managedObjectModel
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if (managedObjectModel)
		{
			return;
		}
		
		XMPPLogVerbose(@"%@: Creating managedObjectModel", [self class]);
		
		NSString *momName = [self managedObjectModelName];
		
		NSString *momPath = [[NSBundle mainBundle] pathForResource:momName ofType:@"mom"];
		if (momPath == nil)
		{
			// The model may be versioned or created with Xcode 4, try momd as an extension.
			momPath = [[NSBundle mainBundle] pathForResource:momName ofType:@"momd"];
		}
    
		if (momPath)
		{
			// If path is nil, then NSURL or NSManagedObjectModel will throw an exception
			
			NSURL *momUrl = [NSURL fileURLWithPath:momPath];
			
			managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:momUrl];
		}
		else
		{
			XMPPLogWarn(@"%@: Couldn't find managedObjectModel file - %@", [self class], momName);
		}
		
	}};
	
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
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if (persistentStoreCoordinator)
		{
			return;
		}
		
		NSManagedObjectModel *mom = [self managedObjectModel];
		if (mom == nil)
		{
			return;
		}
		
		XMPPLogVerbose(@"%@: Creating persistentStoreCoordinator", [self class]);
		
		persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
		
		if (databaseFileName)
		{
			// SQLite persistent store
			
			NSString *docsPath = [self persistentStoreDirectory];
			NSString *storePath = [docsPath stringByAppendingPathComponent:databaseFileName];
			if (storePath)
			{
				// If storePath is nil, then NSURL will throw an exception
				
				[self willCreatePersistentStoreWithPath:storePath];
				
				NSError *error = nil;
				if (![self addPersistentStoreWithPath:storePath error:&error])
				{
					[self didNotAddPersistentStoreWithPath:storePath error:error];
				}
			}
			else
			{
				XMPPLogWarn(@"%@: Error creating persistentStoreCoordinator - Nil persistentStoreDirectory", [self class]);
			}
		}
		else
		{
			// In-Memory persistent store
			
			[self willCreatePersistentStoreWithPath:nil];
			
			NSError *error = nil;
			if (![self addPersistentStoreWithPath:nil error:&error])
			{
				[self didNotAddPersistentStoreWithPath:nil error:error];
			}
		}
		
	}};
	
	if (dispatch_get_current_queue() == storageQueue)
		block();
	else
		dispatch_sync(storageQueue, block);

    return persistentStoreCoordinator;
}

- (NSManagedObjectContext *)managedObjectContext
{
	// This is a private method.
	// 
	// NSManagedObjectContext is NOT thread-safe.
	// Therefore it is VERY VERY BAD to use our private managedObjectContext outside our private storageQueue.
	// 
	// You should NOT remove the assert statement below!
	// You should NOT give external classes access to the storageQueue! (Excluding subclasses obviously.)
	// 
	// When you want a managedObjectContext of your own (again, excluding subclasses),
	// you should create your own using the public persistentStoreCoordinator.
	// 
	// If you even comtemplate ignoring this warning,
	// then you need to go read the documentation for core data,
	// specifically the section entitled "Concurrency with Core Data".
	// 
	NSAssert(dispatch_get_current_queue() == storageQueue, @"Invoked on incorrect queue");
	// 
	// Do NOT remove the assert statment above!
	// Read the comments above!
	// 
	
	if (managedObjectContext)
	{
		return managedObjectContext;
	}
	
	NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
	if (coordinator)
	{
		XMPPLogVerbose(@"%@: Creating managedObjectContext", [self class]);
		
		managedObjectContext = [[NSManagedObjectContext alloc] init];
		[managedObjectContext setPersistentStoreCoordinator:coordinator];
		
		[self didCreateManagedObjectContext];
	}
	
	return managedObjectContext;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSUInteger)numberOfUnsavedChanges
{
	NSManagedObjectContext *moc = [self managedObjectContext];
	
	NSUInteger unsavedCount = 0;
	unsavedCount += [[moc updatedObjects] count];
	unsavedCount += [[moc insertedObjects] count];
	unsavedCount += [[moc deletedObjects] count];
	
	return unsavedCount;
}

- (void)save
{
	// I'm fairly confident that the implementation of [NSManagedObjectContext save:]
	// internally checks to see if it has anything to save before it actually does anthing.
	// So there's no need for us to do it here, especially since this method is usually
	// called from maybeSave below, which already does this check.
	
	NSError *error = nil;
	if (![[self managedObjectContext] save:&error])
	{
		XMPPLogWarn(@"%@: Error saving - %@ %@", [self class], error, [error userInfo]);
		
		[[self managedObjectContext] rollback];
	}
}

- (void)maybeSave:(int32_t)currentPendingRequests
{
	NSAssert(dispatch_get_current_queue() == storageQueue, @"Invoked on incorrect queue");
	
	
	if ([[self managedObjectContext] hasChanges])
	{
		if (currentPendingRequests == 0)
		{
			XMPPLogVerbose(@"%@: Triggering save (pendingRequests=%i)", [self class], currentPendingRequests);
			
			[self save];
		}
		else
		{
			NSUInteger unsavedCount = [self numberOfUnsavedChanges];
			if (unsavedCount >= saveThreshold)
			{
				XMPPLogVerbose(@"%@: Triggering save (unsavedCount=%lu)", [self class], (unsigned long)unsavedCount);
				
				[self save];
			}
		}
	}
}

- (void)maybeSave
{
	// Convenience method in the very rare case that a subclass would need to invoke maybeSave manually.
	
	[self maybeSave:OSAtomicAdd32(0, &pendingRequests)];
}

- (void)executeBlock:(dispatch_block_t)block
{
	// By design this method should not be invoked from the storageQueue.
	// 
	// If you remove the assert statement below, you are destroying the sole purpose for this class,
	// which is to optimize the disk IO by buffering save operations.
	// 
	NSAssert(dispatch_get_current_queue() != storageQueue, @"Invoked on incorrect queue");
	// 
	// For a full discussion of this method, please see XMPPCoreDataStorageProtocol.h
	//
	// dispatch_Sync
	//          ^
	
	OSAtomicIncrement32(&pendingRequests);
	dispatch_sync(storageQueue, ^{ @autoreleasepool {
		
		block();
		
		// Since this is a synchronous request, we want to return as quickly as possible.
		// So we delay the maybeSave operation til later.
		
		dispatch_async(storageQueue, ^{ @autoreleasepool {
			
			[self maybeSave:OSAtomicDecrement32(&pendingRequests)];
		}});
		
	}});
}

- (void)scheduleBlock:(dispatch_block_t)block
{
	// By design this method should not be invoked from the storageQueue.
	// 
	// If you remove the assert statement below, you are destroying the sole purpose for this class,
	// which is to optimize the disk IO by buffering save operations.
	// 
	NSAssert(dispatch_get_current_queue() != storageQueue, @"Invoked on incorrect queue");
	// 
	// For a full discussion of this method, please see XMPPCoreDataStorageProtocol.h
	// 
	// dispatch_Async
	//          ^
	
	OSAtomicIncrement32(&pendingRequests);
	dispatch_async(storageQueue, ^{ @autoreleasepool {
		
		block();
		[self maybeSave:OSAtomicDecrement32(&pendingRequests)];
	}});
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Memory Management
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	if (databaseFileName)
	{
		[[self class] unregisterDatabaseFileName:databaseFileName];
	}
	
	
	if (storageQueue)
	{
		dispatch_release(storageQueue);
	}
	
	
}

@end
