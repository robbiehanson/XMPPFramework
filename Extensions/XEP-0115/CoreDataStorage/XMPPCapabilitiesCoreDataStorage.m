#import "XMPPCapabilitiesCoreDataStorage.h"
#import "XMPPCapsCoreDataStorageObject.h"
#import "XMPPCapsResourceCoreDataStorageObject.h"
#import "XMPP.h"
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


@implementation XMPPCapabilitiesCoreDataStorage

static NSMutableSet *databaseFileNames;
static XMPPCapabilitiesCoreDataStorage *sharedInstance;

+ (void)initialize
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		databaseFileNames = [[NSMutableSet alloc] init];
		sharedInstance = [[XMPPCapabilities alloc] initWithDatabaseFilename:nil];
	});
}

+ (XMPPCapabilitiesCoreDataStorage *)sharedInstance
{
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
			databaseFileName = @"XMPPCapabilities.sqlite";
		
		if (![[self class] registerDatabaseFileName:databaseFileName])
		{
			[self dealloc];
			return nil;
		}
		
		storageQueue = dispatch_queue_create(class_getName([self class]), NULL);
	}
	return self;
}

- (BOOL)configureWithParent:(XMPPCapabilities *)aParent queue:(dispatch_queue_t)queue
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
		
		NSString *path = [[NSBundle mainBundle] pathForResource:@"XMPPCapabilities" ofType:@"mom"];
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
				             @"=====================================================================================\n"
				             @"Error creating persistent store:\n%@\n"
				             @"Chaned core data model recently?\n"
				             @"Quick Fix: Delete the app from device and reinstall.\n"
				             @"=====================================================================================",
				             THIS_FILE, error);
			  #else
				XMPPLogError(@"%@:\n"
				             @"=====================================================================================\n"
				             @"Error creating persistent store:\n%@\n"
				             @"Chaned core data model recently?\n"
				             @"Quick Fix: Delete the database: %@\n"
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
		
		[self clearAllNonPersistentCapabilitiesForXMPPStream:nil];
	}
	
	return managedObjectContext;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (XMPPCapsResourceCoreDataStorageObject *)resourceForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
	NSAssert(dispatch_get_current_queue() == storageQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace2(@"%@: %@ %@", THIS_FILE, THIS_METHOD, jid);
	
	if (jid == nil) return nil;
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPCapsResourceCoreDataStorageObject"
	                                          inManagedObjectContext:[self managedObjectContext]];
	
	NSPredicate *predicate;
	if (stream == nil)
		predicate = [NSPredicate predicateWithFormat:@"jidStr == %@", [jid full]];
	else
		predicate = [NSPredicate predicateWithFormat:@"stream == %@ AND jidStr == %@",
					                [NSNumber numberWithPtr:stream],      [jid full]];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	[fetchRequest setPredicate:predicate];
	[fetchRequest setFetchLimit:1];
	
	NSArray *results = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
	
	XMPPCapsResourceCoreDataStorageObject *resource = [results lastObject];
	
	XMPPLogVerbose(@"%@: %@ - %@", THIS_FILE, THIS_METHOD, resource);
	return resource;
}

- (XMPPCapsCoreDataStorageObject *)capsForHash:(NSString *)hash algorithm:(NSString *)hashAlg
{
	NSAssert(dispatch_get_current_queue() == storageQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace2(@"%@: capsForHash:%@ algorithm:%@", THIS_FILE, hash, hashAlg);
	
	if (hash == nil) return nil;
	if (hashAlg == nil) return nil;
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPCapsCoreDataStorageObject"
	                                          inManagedObjectContext:[self managedObjectContext]];
	
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"hashStr == %@ AND hashAlgorithm == %@",
	                                                           hash, hashAlg];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	[fetchRequest setPredicate:predicate];
	[fetchRequest setFetchLimit:1];
	
	NSArray *results = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
	
	XMPPCapsCoreDataStorageObject *caps = [results lastObject];
	
	XMPPLogVerbose(@"%@: %@ - %@", THIS_FILE, THIS_METHOD, caps);
	return caps;
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

- (BOOL)areCapabilitiesKnownForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	__block BOOL result;
	
	[self executeBlock:^{
		
		XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid xmppStream:stream];
		result = (resource.caps != nil);
		
	}];
	
	return result;
}

- (NSXMLElement *)capabilitiesForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	__block NSXMLElement *result;
	
	[self executeBlock:^{
		
		result = [[self capabilitiesForJID:jid ext:nil xmppStream:stream] retain];
		
	}];
	
	return [result autorelease];
}

- (NSXMLElement *)capabilitiesForJID:(XMPPJID *)jid ext:(NSString **)extPtr xmppStream:(XMPPStream *)stream
{
	// By design this method should not be invoked from the storageQueue.
	NSAssert(dispatch_get_current_queue() != storageQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	__block NSXMLElement *result = nil;
	__block NSString *ext = nil;
	
	[self executeBlock:^{
		
		XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid xmppStream:stream];
		
		if (resource)
		{
			result = [[[resource caps] capabilities] retain];
			ext = [[resource ext] retain];
		}
		
	}];
	
	if (extPtr)
		*extPtr = [ext autorelease];
	else
		[ext release];
	
	return [result autorelease];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Protocol Private API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)setCapabilitiesNode:(NSString *)node
                        ver:(NSString *)ver
                        ext:(NSString *)ext
                       hash:(NSString *)hash
                  algorithm:(NSString *)hashAlg
                     forJID:(XMPPJID *)jid
                 xmppStream:(XMPPStream *)stream
      andGetNewCapabilities:(NSXMLElement **)newCapabilitiesPtr
{
	
	XMPPLogTrace();
	
	__block BOOL result;
	__block NSXMLElement *newCapabilities = nil;
	
	[self executeBlock:^{
		
		BOOL hashChange = NO;
		
		XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid xmppStream:stream];
		if (resource)
		{
			resource.node = node;
			resource.ver = ver;
			resource.ext = ext;
					
			if (![hash isEqual:[resource hashStr]])
			{
				hashChange = YES;
				resource.hashStr = hash;
			}
			
			if (![hashAlg isEqual:[resource hashAlgorithm]])
			{
				hashChange = YES;
				resource.hashAlgorithm = hashAlg;
			}
		}
		else
		{
			resource = [NSEntityDescription insertNewObjectForEntityForName:@"XMPPCapsResourceCoreDataStorageObject"
													 inManagedObjectContext:[self managedObjectContext]];
			
			resource.jidStr = [jid full];
			resource.stream = [NSNumber numberWithPtr:stream];
			
			resource.node = node;
			resource.ver = ver;
			resource.ext = ext;
			
			resource.hashStr = hash;
			resource.hashAlgorithm = hashAlg;
			
			hashChange = ((hash != nil) || (hashAlg != nil));
		}
		
		if (hashChange)
		{
			resource.caps = [self capsForHash:hash algorithm:hashAlg];
			
			newCapabilities = [resource.caps.capabilities retain];
		}
		
		// Return whether or not the capabilities are known for the given jid
		
		result = (resource.caps != nil);
		
		unsavedCount++;
		
	}];
	
	
	if (newCapabilitiesPtr)
		*newCapabilitiesPtr = [newCapabilities autorelease];
	else
		[newCapabilities release];
	
	return result;
}

- (BOOL)getCapabilitiesHash:(NSString **)hashPtr
                  algorithm:(NSString **)hashAlgPtr
                     forJID:(XMPPJID *)jid
                 xmppStream:(XMPPStream *)stream
{
	// By design this method should not be invoked from the storageQueue.
	NSAssert(dispatch_get_current_queue() != storageQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	__block BOOL result;
	__block NSString *hash;
	__block NSString *hashAlg;
	
	[self executeBlock:^{
	
		XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid xmppStream:stream];
		if (resource)
		{
			hash = [resource.hashStr retain];
			hashAlg = [resource.hashAlgorithm retain];
			
			result = (hash && hashAlg);
		}
		else
		{
			hash = nil;
			hashAlg = nil;
			
			result = NO;
		}
		
	}];
	
	
	if (hashPtr)
		*hashPtr = [hash autorelease];
	else
		[hash release];
	
	if (hashAlgPtr)
		*hashAlgPtr = [hashAlg autorelease];
	else
		[hashAlg release];
	
	return result;
}

- (void)clearCapabilitiesHashAndAlgorithmForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	[self scheduleBlock:^{
	
		XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid xmppStream:stream];
		if (resource)
		{
			BOOL clearCaps = NO;
			
			NSString *hash = resource.hashStr;
			NSString *hashAlg = resource.hashAlgorithm;
			
			if (hash && hashAlg)
			{
				clearCaps = YES;
			}
			
			resource.hashStr = nil;
			resource.hashAlgorithm = nil;
			
			if (clearCaps)
			{
				resource.caps = nil;
			}
			
			unsavedCount++;
		}
		
	}];
}

- (void)getCapabilitiesKnown:(BOOL *)areCapabilitiesKnownPtr
                      failed:(BOOL *)haveFailedFetchingBeforePtr
                        node:(NSString **)nodePtr
                         ver:(NSString **)verPtr
                         ext:(NSString **)extPtr
                        hash:(NSString **)hashPtr
                   algorithm:(NSString **)hashAlgPtr
                      forJID:(XMPPJID *)jid
                  xmppStream:(XMPPStream *)stream
{
	// By design this method should not be invoked from the storageQueue.
	NSAssert(dispatch_get_current_queue() != storageQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	__block BOOL areCapabilitiesKnown;
	__block BOOL haveFailedFetchingBefore;
	__block NSString *node;
	__block NSString *ver;
	__block NSString *ext;
	__block NSString *hash;
	__block NSString *hashAlg;
	
	[self executeBlock:^{
		
		XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid xmppStream:stream];
		
		if (resource == nil)
		{
			// We don't know anything about the given jid
			
			areCapabilitiesKnown = NO;
			haveFailedFetchingBefore = NO;
			
			node    = nil;
			ver     = nil;
			ext     = nil;
			hash    = nil;
			hashAlg = nil;
		}
		else
		{
			areCapabilitiesKnown = (resource.caps != nil);
			haveFailedFetchingBefore = resource.haveFailed;
			
			node    = [resource.node retain];
			ver     = [resource.ver retain];
			ext     = [resource.ext retain];
			hash    = [resource.hashStr retain];
			hashAlg = [resource.hashAlgorithm retain];
		}
		
	}];
	
	if (nodePtr)    *nodePtr    = [node    autorelease]; else [node    release];
	if (verPtr)     *verPtr     = [ver     autorelease]; else [ver     release];
	if (extPtr)     *extPtr     = [ext     autorelease]; else [ext     release];
	if (hashPtr)    *hashPtr    = [hash    autorelease]; else [hash    release];
	if (hashAlgPtr) *hashAlgPtr = [hashAlg autorelease]; else [hashAlg release];
}

- (void)setCapabilities:(NSXMLElement *)capabilities forHash:(NSString *)hash algorithm:(NSString *)hashAlg
{
	XMPPLogTrace();
	
	if (hash == nil) return;
	if (hashAlg == nil) return;
	
	[self scheduleBlock:^{
		
		XMPPCapsCoreDataStorageObject *caps = [self capsForHash:hash algorithm:hashAlg];
		if (caps)
		{
			caps.capabilities = capabilities;
		}
		else
		{
			caps = [NSEntityDescription insertNewObjectForEntityForName:@"XMPPCapsCoreDataStorageObject"
												 inManagedObjectContext:[self managedObjectContext]];
			caps.hashStr = hash;
			caps.hashAlgorithm = hashAlg;
			
			caps.capabilities = capabilities;
		}
		
		unsavedCount++;
		
		NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPCapsResourceCoreDataStorageObject"
		                                          inManagedObjectContext:[self managedObjectContext]];
		
		NSPredicate *predicate;
		predicate = [NSPredicate predicateWithFormat:@"hashStr == %@ AND hashAlgorithm == %@", hash, hashAlg];
		
		NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
		[fetchRequest setEntity:entity];
		[fetchRequest setPredicate:predicate];
		[fetchRequest setFetchBatchSize:MAX_UNSAVED_COUNT];
		
		NSArray *results = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
		
		[fetchRequest release];
		
		for (XMPPCapsResourceCoreDataStorageObject *resource in results)
		{
			resource.caps = caps;
			
			if (++unsavedCount >= MAX_UNSAVED_COUNT)
			{
				[self save];
			}
		}
		
	}];
}

- (void)setCapabilities:(NSXMLElement *)capabilities forJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
	// By design this method should not be invoked from the storageQueue.
	NSAssert(dispatch_get_current_queue() != storageQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	if (jid == nil) return;
	
	[self scheduleBlock:^{
	
		XMPPCapsCoreDataStorageObject *caps;
		caps = [NSEntityDescription insertNewObjectForEntityForName:@"XMPPCapsCoreDataStorageObject"
											 inManagedObjectContext:[self managedObjectContext]];
		caps.capabilities = capabilities;
		
		XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid xmppStream:stream];
		
		if (resource == nil)
		{
			resource = [NSEntityDescription insertNewObjectForEntityForName:@"XMPPCapsResourceCoreDataStorageObject"
													 inManagedObjectContext:[self managedObjectContext]];
			resource.jidStr = [jid full];
			resource.stream = [NSNumber numberWithPtr:stream];
			
			unsavedCount++;
		}
		
		resource.caps = caps;
		
		unsavedCount++;
		
	}];
}

- (void)setCapabilitiesFetchFailedForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	[self scheduleBlock:^{
		
		XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid xmppStream:stream];
		resource.haveFailed = YES;
		
		unsavedCount++;
		[self maybeSave:OSAtomicDecrement32(&pendingRequests)];
		
	}];
}

- (void)clearAllNonPersistentCapabilitiesForXMPPStream:(XMPPStream *)stream
{
	// This method is called for the protocol,
	// but is also called when we first load the database file from disk.
	
	XMPPLogTrace();
	
	OSAtomicIncrement32(&pendingRequests);
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPCapsResourceCoreDataStorageObject"
		                                          inManagedObjectContext:[self managedObjectContext]];
		
		NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
		[fetchRequest setEntity:entity];
		[fetchRequest setFetchBatchSize:MAX_UNSAVED_COUNT];
		
		if (stream)
		{
			NSPredicate *predicate;
			predicate = [NSPredicate predicateWithFormat:@"stream == %@", [NSNumber numberWithPtr:stream]];
			
			[fetchRequest setPredicate:predicate];
		}
		
		NSArray *results = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
		
		[fetchRequest release];
		
		for (XMPPCapsResourceCoreDataStorageObject *resource in results)
		{
			NSString *hash = resource.hashStr;
			NSString *hashAlg = resource.hashAlgorithm;
			
			BOOL nonPersistentCapabilities = ((hash == nil) || (hashAlg == nil));
			
			if (nonPersistentCapabilities)
			{
				XMPPCapsCoreDataStorageObject *caps = resource.caps;
				if (caps)
				{
					unsavedCount++;
					[[self managedObjectContext] deleteObject:caps];
				}
			}
			
			unsavedCount++;
			[[self managedObjectContext] deleteObject:resource];
			
			if (unsavedCount >= MAX_UNSAVED_COUNT)
			{
				[self save];
			}
		}
		
		[self maybeSave:OSAtomicDecrement32(&pendingRequests)];
		[pool drain];
	};
	
	if (dispatch_get_current_queue() == storageQueue)
		block();
	else
		dispatch_async(storageQueue, block);
}

- (void)clearNonPersistentCapabilitiesForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	[self scheduleBlock:^{
		
		XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid xmppStream:stream];
		
		if (resource != nil)
		{
			NSString *hash = resource.hashStr;
			NSString *hashAlg = resource.hashAlgorithm;
			
			if (hash && hashAlg)
			{
				// The associated capabilities are persistent
			}
			else
			{
				XMPPCapsCoreDataStorageObject *caps = resource.caps;
				if (caps)
				{
					[[self managedObjectContext] deleteObject:caps];
				}
			}
			
			unsavedCount++;
			[[self managedObjectContext] deleteObject:resource];
		}
		
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Memory Management
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)dealloc
{
	[[self class] unregisterDatabaseFileName:databaseFileName];
	
	[databaseFileName release];
	
	if (storageQueue)
	{
		dispatch_release(storageQueue);
	}
	
	[managedObjectContext release];
	[persistentStoreCoordinator release];
	[managedObjectModel release];
	
	[super dealloc];
}

@end
