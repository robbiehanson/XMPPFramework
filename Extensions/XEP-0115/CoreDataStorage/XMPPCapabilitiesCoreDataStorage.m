#import "XMPPCapabilitiesCoreDataStorage.h"
#import "XMPPCapsCoreDataStorageObject.h"
#import "XMPPCapsResourceCoreDataStorageObject.h"
#import "XMPP.h"
#import "XMPPLogging.h"
#import "DDNumber.h"

// Log levels: off, error, warn, info, verbose
static const int xmppLogLevel = XMPP_LOG_LEVEL_VERBOSE | XMPP_LOG_FLAG_TRACE;

#define AUTORELEASED_BLOCK(block) ^{                            \
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; \
    block();                                                    \
    [pool drain];                                               \
}

@implementation XMPPCapabilitiesCoreDataStorage

- (id)init
{
	return [self initForSingleUsage];
}

- (id)initForSingleUsage
{
	if ((self = [super init]))
	{
		singleUsage = YES;
	}
	return self;
}

- (id)initForMultipleUsage
{
	return [self initForMultipleUsageWithDispatchQueue:NULL];
}

- (id)initForMultipleUsageWithDispatchQueue:(dispatch_queue_t)queue
{
	if ((self = [super init]))
	{
		singleUsage = NO;
		
		if (queue)
		{
			storageQueue = queue;
			dispatch_retain(storageQueue);
		}
		else
		{
			storageQueue = dispatch_queue_create("XMPPCapabilitiesCoreDataStorage", NULL);
		}
	}
	return self;
}

- (BOOL)configureWithParent:(XMPPCapabilities *)aParent queue:(dispatch_queue_t)queue
{
	NSParameterAssert(aParent != nil);
	NSParameterAssert(queue != NULL);
	
	if (singleUsage)
	{
		BOOL result = NO;
		
		@synchronized(self)
		{
			if (storageQueue == NULL)
			{
				storageQueue = queue;
				dispatch_retain(storageQueue);
				
				result = YES;
			}
		}
		
		return result;
	}
	else
	{
		return YES;
	}
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
		NSString *storePath = [docsPath stringByAppendingPathComponent:@"XMPPCapabilities.sqlite"];
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
		
		[self clearAllNonPersistentCapabilitiesInStream:nil];
	}
	
	return managedObjectContext;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (XMPPCapsResourceCoreDataStorageObject *)resourceForJID:(XMPPJID *)jid inStream:(XMPPStream *)stream
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
		predicate = [NSPredicate predicateWithFormat:@"stream == %p AND jidStr == %@", stream, [jid full]];
	
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Protocol Public API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)areCapabilitiesKnownForJID:(XMPPJID *)jid inStream:(XMPPStream *)stream
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	if (storageQueue == NULL)
	{
		XMPPLogWarn(@"%@: Method(%@) invoked before storage configured by parent.", THIS_FILE, THIS_METHOD);
		return NO;
	}
	
	__block BOOL result;
	
	dispatch_block_t block = ^{
		
		XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid inStream:stream];
		result = (resource.caps != nil);
	};
	
	if (dispatch_get_current_queue() == storageQueue) {
		block();
	}
	else {
		dispatch_sync(storageQueue, AUTORELEASED_BLOCK(block));
	}
	
	return result;
}

- (NSXMLElement *)capabilitiesForJID:(XMPPJID *)jid inStream:(XMPPStream *)stream
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	if (storageQueue == NULL)
	{
		XMPPLogWarn(@"%@: Method(%@) invoked before storage configured by parent.", THIS_FILE, THIS_METHOD);
		return nil;
	}
	
	if (dispatch_get_current_queue() == storageQueue)
	{
		return [self capabilitiesForJID:jid ext:nil inStream:stream];
	}
	else
	{
		__block NSXMLElement *result;
		
		dispatch_sync(storageQueue, AUTORELEASED_BLOCK(^{
			
			result = [[self capabilitiesForJID:jid ext:nil inStream:stream] retain];
		}));
		
		return [result autorelease];
	}
}

- (NSXMLElement *)capabilitiesForJID:(XMPPJID *)jid ext:(NSString **)extPtr inStream:(XMPPStream *)stream
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	if (storageQueue == NULL)
	{
		XMPPLogWarn(@"%@: Method(%@) invoked before storage configured by parent.", THIS_FILE, THIS_METHOD);
		return nil;
	}
	
	if (dispatch_get_current_queue() == storageQueue)
	{
		XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid inStream:stream];
		
		if (extPtr) *extPtr = [resource ext];
		
		return [[resource caps] capabilities];
	}
	else
	{
		__block NSXMLElement *result = nil;
		__block NSString *ext = nil;
		
		dispatch_sync(storageQueue, AUTORELEASED_BLOCK(^{
			
			XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid inStream:stream];
			
			if (resource)
			{
				result = [[[resource caps] capabilities] retain];
				ext = [[resource ext] retain];
			}
		}));
		
		if (extPtr)
			*extPtr = [ext autorelease];
		else
			[ext release];
		
		return [result autorelease];
	}
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
                   inStream:(XMPPStream *)stream
      andGetNewCapabilities:(NSXMLElement **)newCapabilitiesPtr
{
	// This is a private protocol method,
	// but may be invoked on any thread/queue if this is a multi-usage storage instance.
	
	XMPPLogTrace();
	
	__block BOOL result;
	__block NSXMLElement *newCapabilities = nil;
	
	dispatch_block_t block = ^{
		
		BOOL hashChange = NO;
		
		XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid inStream:stream];
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
			
			if (newCapabilitiesPtr)
			{
				*newCapabilitiesPtr = resource.caps.capabilities;
			}
		}
		
		if ([[self managedObjectContext] hasChanges])
		{
			[[self managedObjectContext] save:nil];
		}
		
		// Return whether or not the capabilities are known for the given jid
		
		result = (resource.caps != nil);
	};
	
	
	if (dispatch_get_current_queue() == storageQueue)
	{
		block();
		
		if (newCapabilitiesPtr)
			*newCapabilitiesPtr = newCapabilities;
	}
	else
	{
		dispatch_sync(storageQueue, AUTORELEASED_BLOCK(^{
			
			block();
			[newCapabilities retain];
		}));
		
		if (newCapabilitiesPtr)
			*newCapabilitiesPtr = [newCapabilities autorelease];
		else
			[newCapabilities release];
	}
	
	return result;
}

- (BOOL)getCapabilitiesHash:(NSString **)hashPtr
                  algorithm:(NSString **)hashAlgPtr
                     forJID:(XMPPJID *)jid
                   inStream:(XMPPStream *)stream
{
	// This is a private protocol method,
	// but may be invoked on any thread/queue if this is a multi-usage storage instance.
	
	XMPPLogTrace();
	
	__block BOOL result;
	__block NSString *hash;
	__block NSString *hashAlg;
	
	dispatch_block_t block = ^{
	
		XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid inStream:stream];
		if (resource)
		{
			hash = resource.hashStr;
			hashAlg = resource.hashAlgorithm;
			
			result = (hash && hashAlg);
		}
		else
		{
			hash = hashAlg = nil;
			
			result = NO;
		}
	};
	
	if (dispatch_get_current_queue() == storageQueue)
	{
		block();
		
		if (hashPtr) *hashPtr = hash;
		if (hashAlgPtr) *hashAlgPtr = hashAlg;
	}
	else
	{
		dispatch_sync(storageQueue, AUTORELEASED_BLOCK(^{
			
			block();
			
			[hash retain];
			[hashAlg retain];
		}));
		
		if (hashPtr)
			*hashPtr = [hash autorelease];
		else
			[hash release];
		
		if (hashAlgPtr)
			*hashAlgPtr = [hashAlg autorelease];
		else
			[hashAlg release];
	}
	
	return result;
}

- (void)clearCapabilitiesHashAndAlgorithmForJID:(XMPPJID *)jid inStream:(XMPPStream *)stream
{
	// This is a private protocol method,
	// but may be invoked on any thread/queue if this is a multi-usage storage instance.
	
	XMPPLogTrace();
	
	dispatch_block_t block = ^{
	
		XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid inStream:stream];
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
		}
	};
	
	if (dispatch_get_current_queue() == storageQueue)
		block();
	else
		dispatch_async(storageQueue, AUTORELEASED_BLOCK(block));
}

- (void)getCapabilitiesKnown:(BOOL *)areCapabilitiesKnownPtr
                      failed:(BOOL *)haveFailedFetchingBeforePtr
                        node:(NSString **)nodePtr
                         ver:(NSString **)verPtr
                         ext:(NSString **)extPtr
                        hash:(NSString **)hashPtr
                   algorithm:(NSString **)hashAlgPtr
                      forJID:(XMPPJID *)jid
                    inStream:(XMPPStream *)stream
{
	// This is a private protocol method,
	// but may be invoked on any thread/queue if this is a multi-usage storage instance.
	
	XMPPLogTrace();
	
	__block BOOL areCapabilitiesKnown;
	__block BOOL haveFailedFetchingBefore;
	__block NSString *node;
	__block NSString *ver;
	__block NSString *ext;
	__block NSString *hash;
	__block NSString *hashAlg;
	
	dispatch_block_t block = ^{
		
		XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid inStream:stream];
		
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
			
			node    = resource.node;
			ver     = resource.ver;
			ext     = resource.ext;
			hash    = resource.hashStr;
			hashAlg = resource.hashAlgorithm;
		}
	};
	
	if (dispatch_get_current_queue() == storageQueue)
	{
		block();
		
		if (nodePtr)    *nodePtr    = node;
		if (verPtr)     *verPtr     = ver;
		if (extPtr)     *extPtr     = ext;
		if (hashPtr)    *hashPtr    = hash;
		if (hashAlgPtr) *hashAlgPtr = hashAlg;
	}
	else
	{
		dispatch_sync(storageQueue, AUTORELEASED_BLOCK(^{
			
			block();
			
			[node    retain];
			[ver     retain];
			[ext     retain];
			[hash    retain];
			[hashAlg retain];
		}));
		
		if (nodePtr)    *nodePtr    = [node    autorelease]; else [node    release];
		if (verPtr)     *verPtr     = [ver     autorelease]; else [ver     release];
		if (extPtr)     *extPtr     = [ext     autorelease]; else [ext     release];
		if (hashPtr)    *hashPtr    = [hash    autorelease]; else [hash    release];
		if (hashAlgPtr) *hashAlgPtr = [hashAlg autorelease]; else [hashAlg release];
	}
}

- (void)setCapabilities:(NSXMLElement *)capabilities forHash:(NSString *)hash algorithm:(NSString *)hashAlg
{
	// This is a private protocol method,
	// but may be invoked on any thread/queue if this is a multi-usage storage instance.
	
	XMPPLogTrace();
	
	if (hash == nil) return;
	if (hashAlg == nil) return;
	
	dispatch_block_t block = ^{
		
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
		
		NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPCapsResourceCoreDataStorageObject"
												  inManagedObjectContext:[self managedObjectContext]];
		
		NSPredicate *predicate = [NSPredicate predicateWithFormat:@"hashStr == %@ AND hashAlgorithm == %@", hash, hashAlg];
		
		NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
		[fetchRequest setEntity:entity];
		[fetchRequest setPredicate:predicate];
		
		NSArray *results = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
		
		[fetchRequest release];
		
		for (XMPPCapsResourceCoreDataStorageObject *resource in results)
		{
			resource.caps = caps;
		}
		
		[[self managedObjectContext] save:nil];
	};
	
	if (dispatch_get_current_queue() == storageQueue)
		block();
	else
		dispatch_async(storageQueue, AUTORELEASED_BLOCK(block));
}

- (void)setCapabilities:(NSXMLElement *)capabilities forJID:(XMPPJID *)jid inStream:(XMPPStream *)stream
{
	// This is a private protocol method,
	// but may be invoked on any thread/queue if this is a multi-usage storage instance.
	
	XMPPLogTrace();
	
	if (jid == nil) return;
	
	dispatch_block_t block = ^{
	
		XMPPCapsCoreDataStorageObject *caps;
		caps = [NSEntityDescription insertNewObjectForEntityForName:@"XMPPCapsCoreDataStorageObject"
											 inManagedObjectContext:[self managedObjectContext]];
		caps.capabilities = capabilities;
		
		XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid inStream:stream];
		
		if (resource == nil)
		{
			resource = [NSEntityDescription insertNewObjectForEntityForName:@"XMPPCapsResourceCoreDataStorageObject"
													 inManagedObjectContext:[self managedObjectContext]];
			resource.jidStr = [jid full];
			resource.stream = [NSNumber numberWithPtr:stream];
		}
		
		resource.caps = caps;
		
		[[self managedObjectContext] save:nil];
	};
	
	if (dispatch_get_current_queue() == storageQueue)
		block();
	else
		dispatch_async(storageQueue, AUTORELEASED_BLOCK(block));
}

- (void)setCapabilitiesFetchFailedForJID:(XMPPJID *)jid inStream:(XMPPStream *)stream
{
	// This is a private protocol method,
	// but may be invoked on any thread/queue if this is a multi-usage storage instance.
	
	XMPPLogTrace();
	
	dispatch_block_t block = ^{
		
		XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid inStream:stream];
		resource.haveFailed = YES;
	};
	
	if (dispatch_get_current_queue() == storageQueue)
		block();
	else
		dispatch_async(storageQueue, AUTORELEASED_BLOCK(block));
}

- (void)clearAllNonPersistentCapabilitiesInStream:(XMPPStream *)stream
{
	// This is a private protocol method,
	// but may be invoked on any thread/queue if this is a multi-usage storage instance.
	
	XMPPLogTrace();
	
	dispatch_block_t block = ^{
		
		NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPCapsResourceCoreDataStorageObject"
		                                          inManagedObjectContext:[self managedObjectContext]];
		
		NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
		[fetchRequest setEntity:entity];
		
		if (stream)
		{
			[fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"stream == %p", stream]];
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
					[[self managedObjectContext] deleteObject:caps];
				}
			}
			
			[[self managedObjectContext] deleteObject:resource];
		}
		
		if ([[self managedObjectContext] hasChanges])
		{
			[[self managedObjectContext] save:nil];
		}
	};
	
	if (dispatch_get_current_queue() == storageQueue)
		block();
	else
		dispatch_async(storageQueue, AUTORELEASED_BLOCK(block));
}

- (void)clearNonPersistentCapabilitiesForJID:(XMPPJID *)jid inStream:(XMPPStream *)stream
{
	// This is a private protocol method,
	// but may be invoked on any thread/queue if this is a multi-usage storage instance.
	
	XMPPLogTrace();
	
	dispatch_block_t block = ^{
		
		XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid inStream:stream];
		
		if (resource == nil)
		{
			return;
		}
		
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
		
		[[self managedObjectContext] deleteObject:resource];
		[[self managedObjectContext] save:nil];
	};
	
	if (dispatch_get_current_queue() == storageQueue)
		block();
	else
		dispatch_async(storageQueue, AUTORELEASED_BLOCK(block));
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Memory Management
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)dealloc
{
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
