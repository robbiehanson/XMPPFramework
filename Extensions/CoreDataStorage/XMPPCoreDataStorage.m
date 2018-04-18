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

- (NSBundle *)managedObjectModelBundle
{
    return [NSBundle bundleForClass:[self class]];
}

- (NSString *)defaultDatabaseFileName
{
	// Override me, if needed, to provide customized behavior.
	// 
	// This method is queried if the initWithDatabaseFileName:storeOptions: method is invoked with a nil parameter for databaseFileName.
	// 
	// You are encouraged to use the sqlite file extension.
	
	return [NSString stringWithFormat:@"%@.sqlite", [self managedObjectModelName]];
}

- (NSDictionary *)defaultStoreOptions
{
    
    // Override me, if needed, to provide customized behavior.
	//
	// This method is queried if the initWithDatabaseFileName:storeOptions: method is invoked with a nil parameter for defaultStoreOptions.
    
    NSDictionary *defaultStoreOptions = nil;
    
    if(databaseFileName)
    {
        defaultStoreOptions = @{ NSMigratePersistentStoresAutomaticallyOption: @(YES),
                                 NSInferMappingModelAutomaticallyOption : @(YES) };
    }
    
    return defaultStoreOptions;
}

- (void)willCreatePersistentStoreWithPath:(NSString *)storePath options:(NSDictionary *)theStoreOptions
{
	// Override me, if needed, to provide customized behavior.
	// 
	// If you are using a database file with pure non-persistent data (e.g. for memory optimization purposes on iOS),
	// you may want to delete the database file if it already exists on disk.
	// 
	// If this instance was created via initWithDatabaseFilename, then the storePath parameter will be non-nil.
	// If this instance was created via initWithInMemoryStore, then the storePath parameter will be nil.
}

- (BOOL)addPersistentStoreWithPath:(NSString *)storePath options:(NSDictionary *)theStoreOptions error:(NSError **)errorPtr
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
		
		persistentStore = [persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
		                                                           configuration:nil
		                                                                     URL:storeUrl
		                                                                 options:storeOptions
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

- (void)didNotAddPersistentStoreWithPath:(NSString *)storePath options:(NSDictionary *)theStoreOptions error:(NSError *)error
{
    // Override me, if needed, to provide customized behavior.
	// 
	// For example, if you are using the database for non-persistent data and the model changes, 
	// you may want to delete the database file if it already exists on disk.
	// 
	// E.g:
	// 
	// [[NSFileManager defaultManager] removeItemAtPath:storePath error:NULL];
	// [self addPersistentStoreWithPath:storePath error:NULL];
	//
	// This method is invoked on the storageQueue.
    
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
	// For example, you may want to perform cleanup of any non-persistent data before you start using the database.
	// 
	// This method is invoked on the storageQueue.
}

- (void)willSaveManagedObjectContext
{
	// Override me if you need to do anything special just before changes are saved to disk.
	// 
	// This method is invoked on the storageQueue.
}

- (void)didSaveManagedObjectContext
{
	// Override me if you need to do anything special after changes have been saved to disk.
	// 
	// This method is invoked on the storageQueue.
}

- (void)mainThreadManagedObjectContextDidMergeChanges
{
	// Override me if you want to do anything special when changes get propogated to the main thread.
	// 
	// This method is invoked on the main thread.
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Setup
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@synthesize databaseFileName;
@synthesize storeOptions;

- (void)commonInit
{
	saveThreshold = 500;
	
	storageQueue = dispatch_queue_create(class_getName([self class]), NULL);
	
	storageQueueTag = &storageQueueTag;
	dispatch_queue_set_specific(storageQueue, storageQueueTag, storageQueueTag, NULL);
	
	myJidCache = [[NSMutableDictionary alloc] init];
    
    willSaveManagedObjectContextBlocks = [[NSMutableArray alloc] init];
    didSaveManagedObjectContextBlocks = [[NSMutableArray alloc] init];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(updateJidCache:)
	                                             name:XMPPStreamDidChangeMyJIDNotification
	                                           object:nil];
}

- (id)init
{
    return [self initWithDatabaseFilename:nil storeOptions:nil];
}

- (id)initWithDatabaseFilename:(NSString *)aDatabaseFileName storeOptions:(NSDictionary *)theStoreOptions
{
	if ((self = [super init]))
	{
		if (aDatabaseFileName)
			databaseFileName = [aDatabaseFileName copy];
		else
			databaseFileName = [[self defaultDatabaseFileName] copy];
        
        if(theStoreOptions)
            storeOptions = theStoreOptions;
        else
            storeOptions = [self defaultStoreOptions];
		
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
	if (dispatch_get_specific(storageQueueTag))
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
	
	if (dispatch_get_specific(storageQueueTag))
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
	if (stream == nil) return nil;
	
	__block XMPPJID *result = nil;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		NSNumber *key = [NSNumber xmpp_numberWithPtr:(__bridge void *)stream];
		
		result = (XMPPJID *) myJidCache[key];
		if (!result)
		{
			result = [stream myJID];
			if (result)
			{
				myJidCache[key] = result;
			}
		}
	}};
	
	if (dispatch_get_specific(storageQueueTag))
		block();
	else
		dispatch_sync(storageQueue, block);
	
	return result;
}

- (void)didChangeCachedMyJID:(XMPPJID *)cachedMyJID forXMPPStream:(XMPPStream *)stream
{
	// Override me if you'd like to do anything special when this happens.
	// 
	// For example, if your custom storage class prefetches data related to the current user.
}

- (void)updateJidCache:(NSNotification *)notification
{
	// Notifications are delivered on the thread/queue that posted them.
	// In this case, they are delivered on xmppStream's internal processing queue.
	
	XMPPStream *stream = (XMPPStream *)[notification object];
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		NSNumber *key = [NSNumber xmpp_numberWithPtr:(__bridge void *)stream];
		XMPPJID *cachedJID = myJidCache[key];
		
		if (cachedJID)
		{
			XMPPJID *newJID = [stream myJID];
			
			if (newJID)
			{
				if (![cachedJID isEqualToJID:newJID])
				{
					myJidCache[key] = newJID;
					[self didChangeCachedMyJID:newJID forXMPPStream:stream];
				}
			}
			else
			{
				[myJidCache removeObjectForKey:key];
				[self didChangeCachedMyJID:nil forXMPPStream:stream];
			}
		}
	}};
	
	if (dispatch_get_specific(storageQueueTag))
		block();
	else
		dispatch_async(storageQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Core Data Setup
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)persistentStoreDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? paths[0] : NSTemporaryDirectory();
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // Previously the Peristent Story Directory was based on the Bundle Display Name but this can be Localized
    // If Peristent Story Directory already exists we will use that
    NSString *bundleDisplayName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    if (bundleDisplayName) {
        NSString *legacyPersistentStoreDirectory  = [basePath stringByAppendingPathComponent:bundleDisplayName];
        if ([fileManager fileExistsAtPath:legacyPersistentStoreDirectory]) {
            return legacyPersistentStoreDirectory;
        }
    }
    
    // Peristent Story Directory now uses the Bundle Identifier
    NSString *bundleIdentifier = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
    NSString *persistentStoreDirectory  = [basePath stringByAppendingPathComponent:bundleIdentifier];
    if (![fileManager fileExistsAtPath:persistentStoreDirectory]) {
        [fileManager createDirectoryAtPath:persistentStoreDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return persistentStoreDirectory;
}

- (NSManagedObjectModel *)managedObjectModel
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	__block NSManagedObjectModel *result = nil;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if (managedObjectModel)
		{
			result = managedObjectModel;
			return;
		}
		        
		NSString *momName = [self managedObjectModelName];
		
		XMPPLogVerbose(@"%@: Creating managedObjectModel (%@)", [self class], momName);
		
		NSString *momPath = [[self managedObjectModelBundle] pathForResource:momName ofType:@"mom"];
		if (momPath == nil)
		{
			// The model may be versioned or created with Xcode 4, try momd as an extension.
			momPath = [[self managedObjectModelBundle] pathForResource:momName ofType:@"momd"];
		}
    
		if (momPath)
		{
			// If path is nil, then NSURL or NSManagedObjectModel will throw an exception
			
			NSURL *momUrl = [NSURL fileURLWithPath:momPath];
			
			managedObjectModel = [[[NSManagedObjectModel alloc] initWithContentsOfURL:momUrl] copy];
		}
		else
		{
			XMPPLogWarn(@"%@: Couldn't find managedObjectModel file - %@", [self class], momName);
		}
        
        if([NSAttributeDescription instancesRespondToSelector:@selector(setAllowsExternalBinaryDataStorage:)])
        {
            if(autoAllowExternalBinaryDataStorage)
            {
                NSArray *entities = [managedObjectModel entities];
                
                for(NSEntityDescription *entity in entities)
                {
                    NSDictionary *attributesByName = [entity attributesByName];
                    
                    [attributesByName enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                        
                        if([obj attributeType] == NSBinaryDataAttributeType)
                        {
                            [obj setAllowsExternalBinaryDataStorage:YES];
                        }
                        
                    }];			
                }
                
            }
            
        }
		
		result = managedObjectModel;
	}};
	
	if (dispatch_get_specific(storageQueueTag))
		block();
	else
		dispatch_sync(storageQueue, block);
	
	return result;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	__block NSPersistentStoreCoordinator *result = nil;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if (persistentStoreCoordinator)
		{
			result = persistentStoreCoordinator;
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
                
                if(autoRemovePreviousDatabaseFile)
                {
                    if ([[NSFileManager defaultManager] fileExistsAtPath:storePath])
                    {
                        [[NSFileManager defaultManager] removeItemAtPath:storePath error:nil];
                    }
                }
				
				[self willCreatePersistentStoreWithPath:storePath options:storeOptions];
				
				NSError *error = nil;
				
				BOOL didAddPersistentStore = [self addPersistentStoreWithPath:storePath options:storeOptions error:&error];
				
				if(autoRecreateDatabaseFile && !didAddPersistentStore)
				{
					[[NSFileManager defaultManager] removeItemAtPath:storePath error:NULL];
					
					didAddPersistentStore = [self addPersistentStoreWithPath:storePath options:storeOptions error:&error];
				}
				
				if (!didAddPersistentStore)
				{
					[self didNotAddPersistentStoreWithPath:storePath options:storeOptions error:error];
				}
			}
			else
			{
				XMPPLogWarn(@"%@: Error creating persistentStoreCoordinator - Nil persistentStoreDirectory",
							[self class]);
			}
		}
		else
		{
			// In-Memory persistent store
			
			[self willCreatePersistentStoreWithPath:nil options:storeOptions];
			
			NSError *error = nil;
			if (![self addPersistentStoreWithPath:nil options:storeOptions error:&error])
			{
				[self didNotAddPersistentStoreWithPath:nil options:storeOptions error:error];
			}
		}
		
		result = persistentStoreCoordinator;
		
	}};
	
	if (dispatch_get_specific(storageQueueTag))
		block();
	else
		dispatch_sync(storageQueue, block);

    return result;
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
	// you can use the mainThreadManagedObjectContext (below),
	// or you should create your own using the public persistentStoreCoordinator.
	// 
	// If you even comtemplate ignoring this warning,
	// then you need to go read the documentation for core data,
	// specifically the section entitled "Concurrency with Core Data".
	// 
	NSAssert(dispatch_get_specific(storageQueueTag), @"Invoked on incorrect queue");
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
		
		if ([NSManagedObjectContext instancesRespondToSelector:@selector(initWithConcurrencyType:)])
			managedObjectContext =
			    [[NSManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
		else
			managedObjectContext = [[NSManagedObjectContext alloc] init];
		
		managedObjectContext.persistentStoreCoordinator = coordinator;
		managedObjectContext.undoManager = nil;
		
		[self didCreateManagedObjectContext];
	}
	
	return managedObjectContext;
}

- (NSManagedObjectContext *)mainThreadManagedObjectContext
{
	// NSManagedObjectContext is NOT thread-safe.
	// Therefore it is VERY VERY BAD to use this managedObjectContext outside the main thread.
	// 
	// You should NOT remove the assert statement below!
	// 
	// When you want a managedObjectContext of your own for non-main-thread use,
	// you should create your own using the public persistentStoreCoordinator.
	// 
	// If you even comtemplate ignoring this warning,
	// then you need to go read the documentation for core data,
	// specifically the section entitled "Concurrency with Core Data".
	// 
	NSAssert([NSThread isMainThread], @"Context reserved for main thread only");
	// 
	// Do NOT remove the assert statment above!
	// Read the comments above!
	// 
	
	if (mainThreadManagedObjectContext)
	{
		return mainThreadManagedObjectContext;
	}
	
	NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
	if (coordinator)
	{
		XMPPLogVerbose(@"%@: Creating mainThreadManagedObjectContext", [self class]);
		
		if ([NSManagedObjectContext instancesRespondToSelector:@selector(initWithConcurrencyType:)])
			mainThreadManagedObjectContext =
			    [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
		else
			mainThreadManagedObjectContext = [[NSManagedObjectContext alloc] init];
		
		mainThreadManagedObjectContext.persistentStoreCoordinator = coordinator;
		mainThreadManagedObjectContext.undoManager = nil;
		
		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(managedObjectContextDidSave:)
		                                             name:NSManagedObjectContextDidSaveNotification
		                                           object:nil];
		
		// Todo: If we knew that our private managedObjectContext was going to be the only one writing to the database,
		// then a small optimization would be to use it as the object when registering above.
	}
	
	return mainThreadManagedObjectContext;
}

- (void)managedObjectContextDidSave:(NSNotification *)notification
{
	NSManagedObjectContext *sender = (NSManagedObjectContext *)[notification object];
	
	if ((sender != mainThreadManagedObjectContext) &&
	    (sender.persistentStoreCoordinator == mainThreadManagedObjectContext.persistentStoreCoordinator))
	{
		XMPPLogVerbose(@"%@: %@ - Merging changes into mainThreadManagedObjectContext", THIS_FILE, THIS_METHOD);
		
		dispatch_async(dispatch_get_main_queue(), ^{
            
            // http://stackoverflow.com/questions/3923826/nsfetchedresultscontroller-with-predicate-ignores-changes-merged-from-different
            for (NSManagedObject *object in [notification userInfo][NSUpdatedObjectsKey]) {
                [[mainThreadManagedObjectContext objectWithID:[object objectID]] willAccessValueForKey:nil];
            }
			
			[mainThreadManagedObjectContext mergeChangesFromContextDidSaveNotification:notification];
			[self mainThreadManagedObjectContextDidMergeChanges];
		});
    }
}

- (BOOL)autoRemovePreviousDatabaseFile
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		result = autoRemovePreviousDatabaseFile;
	}};
	
	if (dispatch_get_specific(storageQueueTag))
		block();
	else
		dispatch_sync(storageQueue, block);
	
	return result;
}

- (void)setAutoRemovePreviousDatabaseFile:(BOOL)flag
{
	dispatch_block_t block = ^{
		autoRemovePreviousDatabaseFile = flag;
	};
	
	if (dispatch_get_specific(storageQueueTag))
		block();
	else
		dispatch_sync(storageQueue, block);
}

- (BOOL)autoRecreateDatabaseFile
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		result = autoRecreateDatabaseFile;
	}};
	
	if (dispatch_get_specific(storageQueueTag))
		block();
	else
		dispatch_sync(storageQueue, block);
	
	return result;
}

- (void)setAutoRecreateDatabaseFile:(BOOL)flag
{
	dispatch_block_t block = ^{
		autoRecreateDatabaseFile = flag;
	};
	
	if (dispatch_get_specific(storageQueueTag))
		block();
	else
		dispatch_sync(storageQueue, block);
}

- (BOOL)autoAllowExternalBinaryDataStorage
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		result = autoAllowExternalBinaryDataStorage;
	}};
	
	if (dispatch_get_specific(storageQueueTag))
		block();
	else
		dispatch_sync(storageQueue, block);
	
	return result;
}

- (void)setAutoAllowExternalBinaryDataStorage:(BOOL)flag
{
	dispatch_block_t block = ^{
		autoAllowExternalBinaryDataStorage = flag;
	};
	
	if (dispatch_get_specific(storageQueueTag))
		block();
	else
		dispatch_sync(storageQueue, block);	
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
    
    for(void (^block)(void) in willSaveManagedObjectContextBlocks) {
        block();
    }
    
    [willSaveManagedObjectContextBlocks removeAllObjects];
    
	NSError *error = nil;
	if ([[self managedObjectContext] save:&error])
	{
		saveCount++;
        
        for(void (^block)(void) in didSaveManagedObjectContextBlocks) {
            block();
        }
        
        [didSaveManagedObjectContextBlocks removeAllObjects];
	}
	else
	{
		XMPPLogWarn(@"%@: Error saving - %@ %@", [self class], error, [error userInfo]);
		
		[[self managedObjectContext] rollback];
        
        [didSaveManagedObjectContextBlocks removeAllObjects];
	}
}

- (void)maybeSave:(int32_t)currentPendingRequests
{
	NSAssert(dispatch_get_specific(storageQueueTag), @"Invoked on incorrect queue");
	
	
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
	NSAssert(!dispatch_get_specific(storageQueueTag), @"Invoked on incorrect queue");
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
	NSAssert(!dispatch_get_specific(storageQueueTag), @"Invoked on incorrect queue");
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

- (void)addWillSaveManagedObjectContextBlock:(void (^)(void))willSaveBlock
{
    dispatch_block_t block = ^{
		[willSaveManagedObjectContextBlocks addObject:[willSaveBlock copy]];
	};
	
	if (dispatch_get_specific(storageQueueTag))
		block();
	else
		dispatch_sync(storageQueue, block);
}

- (void)addDidSaveManagedObjectContextBlock:(void (^)(void))didSaveBlock
{
    dispatch_block_t block = ^{
		[didSaveManagedObjectContextBlocks addObject:[didSaveBlock copy]];
	};
	
	if (dispatch_get_specific(storageQueueTag))
		block();
	else
		dispatch_sync(storageQueue, block);
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
	
	#if !OS_OBJECT_USE_OBJC
	if (storageQueue)
		dispatch_release(storageQueue);
	#endif
}

@end
