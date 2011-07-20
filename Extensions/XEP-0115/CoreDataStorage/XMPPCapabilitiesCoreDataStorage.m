#import "XMPPCapabilitiesCoreDataStorage.h"
#import "XMPPCapsCoreDataStorageObject.h"
#import "XMPPCapsResourceCoreDataStorageObject.h"
#import "XMPP.h"
#import "XMPPCoreDataStorageProtected.h"
#import "XMPPLogging.h"

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
	
	NSFetchRequest *fetchRequest = [[[NSFetchRequest alloc] init] autorelease];
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
	
	NSFetchRequest *fetchRequest = [[[NSFetchRequest alloc] init] autorelease];
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
	
	NSFetchRequest *fetchRequest = [[[NSFetchRequest alloc] init] autorelease];
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

- (BOOL)addPersistentStoreWithPath:(NSString *)storePath error:(NSError **)errorPtr
{    
    BOOL result = [super addPersistentStoreWithPath:storePath error:errorPtr];
    
    if (!result &&
        [*errorPtr code] == NSMigrationMissingSourceModelError &&
        [[*errorPtr domain] isEqualToString:NSCocoaErrorDomain]) {
        // If we get this error while trying to add the persistent store, it most likely means the model changed.
        // Since we are caching capabilities, it is safe to delete the persistent store and create a new one.
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:storePath])
        {
            [[NSFileManager defaultManager] removeItemAtPath:storePath error:nil];
            
            // Try creating the store again, without creating a deletion/creation loop.
            result = [super addPersistentStoreWithPath:storePath error:errorPtr];
        }
    }
    
    return result;
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
			
			newCapabilities = [resource.caps.capabilities retain];
		}
		
		// Return whether or not the capabilities are known for the given jid
		
		result = (resource.caps != nil);
		
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
		
		NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPCapsResourceCoreDataStorageObject"
		                                          inManagedObjectContext:[self managedObjectContext]];
		
		NSPredicate *predicate;
		predicate = [NSPredicate predicateWithFormat:@"hashStr == %@ AND hashAlgorithm == %@", hash, hashAlg];
		
		NSFetchRequest *fetchRequest = [[[NSFetchRequest alloc] init] autorelease];
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
