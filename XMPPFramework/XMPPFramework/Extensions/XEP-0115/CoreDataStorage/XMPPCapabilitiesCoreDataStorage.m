#import "XMPPCapabilitiesCoreDataStorage.h"
#import "XMPPCapsCoreDataStorageObject.h"
#import "XMPPCapsResourceCoreDataStorageObject.h"
#import "XMPP.h"
#import "XMPPCoreDataStorageProtected.h"
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

@implementation XMPPCapabilitiesCoreDataStorage

static XMPPCapabilitiesCoreDataStorage *sharedInstance;

+ (XMPPCapabilitiesCoreDataStorage *)sharedInstance
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		sharedInstance = [[XMPPCapabilitiesCoreDataStorage alloc] initWithDatabaseFilename:nil];
	});
	
	return sharedInstance;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Setup
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)configureWithParent:(XMPPCapabilities *)aParent queue:(dispatch_queue_t)queue
{
	return [super configureWithParent:aParent queue:queue];
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
		predicate = [NSPredicate predicateWithFormat:@"jidStr == %@ AND streamBareJidStr == %@",
					                                     [jid full], [[self myJIDForXMPPStream:stream] bare]];
	
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

- (void)_clearAllNonPersistentCapabilitiesForXMPPStream:(XMPPStream *)stream
{
	NSAssert(dispatch_get_current_queue() == storageQueue, @"Invoked on incorrect queue");
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPCapsResourceCoreDataStorageObject"
	                                          inManagedObjectContext:[self managedObjectContext]];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	[fetchRequest setFetchBatchSize:saveThreshold];
	
	if (stream)
	{
		NSPredicate *predicate = [NSPredicate predicateWithFormat:@"streamBareJidStr == %@",
								  [[self myJIDForXMPPStream:stream] bare]];
		
		[fetchRequest setPredicate:predicate];
	}
	
	NSArray *results = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
	
	NSUInteger unsavedCount = [self numberOfUnsavedChanges];
	
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
		
		if (++unsavedCount >= saveThreshold)
		{
			[self save];
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Overrides
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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

- (void)didCreateManagedObjectContext
{
	// This method is overriden from the XMPPCoreDataStore superclass.
	
	[self _clearAllNonPersistentCapabilitiesForXMPPStream:nil];
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
    
    return [self capabilitiesForJID:jid ext:nil xmppStream:stream];	
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
			result = [[resource caps] capabilities];
			ext = [resource ext];
		}
		
	}];
	
	if (extPtr)
		*extPtr = ext;
	
	return result;
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
	
	__block BOOL result = NO;
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
			resource.streamBareJidStr = [[self myJIDForXMPPStream:stream] bare];
			
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
			
			newCapabilities = resource.caps.capabilities;
		}
		
		// Return whether or not the capabilities are known for the given jid
		
		result = (resource.caps != nil);
		
	}];
	
	
	if (newCapabilitiesPtr)
		*newCapabilitiesPtr = newCapabilities;
	
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
	
	__block BOOL result = NO;
	__block NSString *hash = nil;
	__block NSString *hashAlg = nil;
	
	[self executeBlock:^{
	
		XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid xmppStream:stream];
		if (resource)
		{
			hash = resource.hashStr;
			hashAlg = resource.hashAlgorithm;
			
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
		*hashPtr = hash;
	
	if (hashAlgPtr)
		*hashAlgPtr = hashAlg;
	
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
	
	__block BOOL areCapabilitiesKnown = NO;
	__block BOOL haveFailedFetchingBefore = NO;
	__block NSString *node    = nil;
	__block NSString *ver     = nil;
	__block NSString *ext     = nil;
	__block NSString *hash    = nil;
	__block NSString *hashAlg = nil;
	
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
			
			node    = resource.node;
			ver     = resource.ver;
			ext     = resource.ext;
			hash    = resource.hashStr;
			hashAlg = resource.hashAlgorithm;
		}
		
	}];
	
	if (areCapabilitiesKnownPtr)     *areCapabilitiesKnownPtr     = areCapabilitiesKnown;
	if (haveFailedFetchingBeforePtr) *haveFailedFetchingBeforePtr = haveFailedFetchingBefore;
	
	if (nodePtr)    *nodePtr    = node;
	if (verPtr)     *verPtr     = ver;
	if (extPtr)     *extPtr     = ext;
	if (hashPtr)    *hashPtr    = hash;
	if (hashAlgPtr) *hashAlgPtr = hashAlg;
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
		
		NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPCapsResourceCoreDataStorageObject"
		                                          inManagedObjectContext:[self managedObjectContext]];
		
		NSPredicate *predicate;
		predicate = [NSPredicate predicateWithFormat:@"hashStr == %@ AND hashAlgorithm == %@", hash, hashAlg];
		
		NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
		[fetchRequest setEntity:entity];
		[fetchRequest setPredicate:predicate];
		[fetchRequest setFetchBatchSize:saveThreshold];
		
		NSArray *results = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
		
		NSUInteger unsavedCount = [self numberOfUnsavedChanges];
		
		for (XMPPCapsResourceCoreDataStorageObject *resource in results)
		{
			resource.caps = caps;
			
			if (++unsavedCount >= saveThreshold)
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
			resource.streamBareJidStr = [[self myJIDForXMPPStream:stream] bare];
		}
		
		resource.caps = caps;
		
	}];
}

- (void)setCapabilitiesFetchFailedForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	[self scheduleBlock:^{
		
		XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid xmppStream:stream];
		resource.haveFailed = YES;
		
	}];
}

- (void)clearAllNonPersistentCapabilitiesForXMPPStream:(XMPPStream *)stream
{
	// This method is called for the protocol,
	// but is also called when we first load the database file from disk.
	
	XMPPLogTrace();
	
	[self scheduleBlock:^{
		
		[self _clearAllNonPersistentCapabilitiesForXMPPStream:stream];
		
	}];
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
			
			[[self managedObjectContext] deleteObject:resource];
		}
		
	}];
}

@end
