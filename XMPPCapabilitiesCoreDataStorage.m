#import "XMPPCapabilitiesCoreDataStorage.h"
#import "XMPPCapsCoreDataStorageObject.h"
#import "XMPPCapsResourceCoreDataStorageObject.h"
#import "XMPP.h"


@implementation XMPPCapabilitiesCoreDataStorage

@synthesize parent;

@dynamic managedObjectModel;
@dynamic persistentStoreCoordinator;
@dynamic managedObjectContext;

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
	if (managedObjectModel)
	{
		return managedObjectModel;
	}
	
	NSString *path = [[NSBundle mainBundle] pathForResource:@"XMPPCapabilities" ofType:@"mom"];
	if (path)
	{
		// If path is nil, then NSURL or NSManagedObjectModel will throw an exception
		
		NSURL *url = [NSURL fileURLWithPath:path];
		
		managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
	}
	
	return managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
	if (persistentStoreCoordinator)
	{
		return persistentStoreCoordinator;
	}
	
	NSManagedObjectModel *mom = [self managedObjectModel];
	
	persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
	
	NSString *docsPath = [self persistentStoreDirectory];
	NSString *storePath = [docsPath stringByAppendingPathComponent:@"Locations.sqlite"];
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
		if(!persistentStore)
		{
			NSLog(@"=====================================================================================");
			NSLog(@"Error creating persistent store:\n%@", error);
			NSLog(@"Chaned core data model recently?");
		#if TARGET_OS_IPHONE
			NSLog(@"Quick Fix: Delete the app from device and reinstall.");
		#else
			NSLog(@"Quick Fix: Delete the database: %@", storePath);
		#endif
			NSLog(@"=====================================================================================");
		}
	}

    return persistentStoreCoordinator;
}

- (NSManagedObjectContext *)managedObjectContext
{
	if (managedObjectContext)
	{
		return managedObjectContext;
	}
	
	NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
	if (coordinator)
	{
		managedObjectContext = [[NSManagedObjectContext alloc] init];
		[managedObjectContext setPersistentStoreCoordinator:coordinator];
		
		[self clearAllNonPersistentCapabilities];
	}
	
	return managedObjectContext;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (XMPPCapsResourceCoreDataStorageObject *)resourceForJID:(XMPPJID *)jid
{
	if (jid == nil) return nil;
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPCapsResourceCoreDataStorageObject"
	                                          inManagedObjectContext:[self managedObjectContext]];
	
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"jidStr == %@", [jid full]];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	[fetchRequest setPredicate:predicate];
	[fetchRequest setFetchLimit:1];
	
	NSArray *results = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
	
	[fetchRequest release];
	
	if ([results count] > 0)
	{
		XMPPCapsResourceCoreDataStorageObject *resource = [results lastObject];
		
		return resource;
	}
	
	return nil;
}

- (XMPPCapsCoreDataStorageObject *)capsForHash:(NSString *)hash algorithm:(NSString *)hashAlg
{
	if (hash == nil) return nil;
	if (hashAlg == nil) return nil;
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPCapsCoreDataStorageObject"
	                                          inManagedObjectContext:[self managedObjectContext]];
	
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"hashStr == %@ AND hashAlgorithm == %@", hash, hashAlg];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	[fetchRequest setPredicate:predicate];
	[fetchRequest setFetchLimit:1];
	
	NSArray *results = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
	
	[fetchRequest release];
	
	if ([results count] > 0)
	{
		XMPPCapsCoreDataStorageObject *caps = [results lastObject];
		
		return caps;
	}
	
	return nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPCapabilities Protocol
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)areCapabilitiesKnownForJID:(XMPPJID *)jid
{
	XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid];
	
	return (resource.caps != nil);
}

- (BOOL)setCapabilitiesNode:(NSString *)node
                        ver:(NSString *)ver
                        ext:(NSString *)ext
                       hash:(NSString *)hash
                  algorithm:(NSString *)hashAlg
                     forJID:(XMPPJID *)jid
      andGetNewCapabilities:(NSXMLElement **)newCapabilitiesPtr
{
	BOOL hashChange = NO;
	
	XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid];
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
	
	return (resource.caps != nil);
}

- (BOOL)getCapabilitiesHash:(NSString **)hashPtr algorithm:(NSString **)hashAlgPtr forJID:(XMPPJID *)jid
{
	XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid];
	if (resource)
	{
		NSString *hash = resource.hashStr;
		NSString *hashAlg = resource.hashAlgorithm;
		
		if (hash && hashAlg)
		{
			if (hashPtr) *hashPtr = [[hash copy] autorelease];
			if (hashAlgPtr) *hashAlgPtr = [[hashAlg copy] autorelease];
			
			return YES;
		}
	}
	
	return NO;
}

- (void)clearCapabilitiesHashAndAlgorithmForJID:(XMPPJID *)jid
{
	XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid];
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
}

- (void)getCapabilitiesKnown:(BOOL *)areCapabilitiesKnownPtr
                      failed:(BOOL *)haveFailedFetchingBeforePtr
                        node:(NSString **)nodePtr
                         ver:(NSString **)verPtr
                         ext:(NSString **)extPtr
                        hash:(NSString **)hashPtr
                   algorithm:(NSString **)hashAlgPtr
                      forJID:(XMPPJID *)jid
{
	XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid];
	
	if (resource == nil)
	{
		// We don't know anything about the given jid
		
		if (areCapabilitiesKnownPtr)     *areCapabilitiesKnownPtr = NO;
		if (haveFailedFetchingBeforePtr) *haveFailedFetchingBeforePtr = NO;
		
		if (nodePtr)    *nodePtr    = nil;
		if (verPtr)     *verPtr     = nil;
		if (extPtr)     *extPtr     = nil;
		if (hashPtr)    *hashPtr    = nil;
		if (hashAlgPtr) *hashAlgPtr = nil;
		
		return;
	}
	
	if (areCapabilitiesKnownPtr) *areCapabilitiesKnownPtr = (resource.caps != nil);
	
	if (haveFailedFetchingBeforePtr) *haveFailedFetchingBeforePtr = resource.haveFailed;
	
	if (nodePtr)    *nodePtr    = resource.node;
	if (verPtr)     *verPtr     = resource.ver;
	if (extPtr)     *extPtr     = resource.ext;
	if (hashPtr)    *hashPtr    = resource.hashStr;
	if (hashAlgPtr) *hashAlgPtr = resource.hashAlgorithm;
}

- (void)setCapabilities:(NSXMLElement *)capabilities forHash:(NSString *)hash algorithm:(NSString *)hashAlg
{
	if (hash == nil) return;
	if (hashAlg == nil) return;
	
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
}

- (void)setCapabilities:(NSXMLElement *)capabilities forJID:(XMPPJID *)jid
{
	if (jid == nil) return;
	
	XMPPCapsCoreDataStorageObject *caps;
	caps = [NSEntityDescription insertNewObjectForEntityForName:@"XMPPCapsCoreDataStorageObject"
	                                     inManagedObjectContext:[self managedObjectContext]];
	caps.capabilities = capabilities;
	
	XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid];
	
	if (resource == nil)
	{
		resource = [NSEntityDescription insertNewObjectForEntityForName:@"XMPPCapsResourceCoreDataStorageObject"
		                                         inManagedObjectContext:[self managedObjectContext]];
		resource.jidStr = [jid full];
	}
	
	resource.caps = caps;
	
	[[self managedObjectContext] save:nil];
}

- (NSXMLElement *)capabilitiesForJID:(XMPPJID *)jid
{
	return [self capabilitiesForJID:jid ext:nil];
}

- (NSXMLElement *)capabilitiesForJID:(XMPPJID *)jid ext:(NSString **)extPtr
{
	XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid];
	
	if (resource == nil)
	{
		if (extPtr) *extPtr = nil;
		return nil;
	}
	
	if (extPtr) *extPtr = resource.ext;
	
	XMPPCapsCoreDataStorageObject *caps = resource.caps;
	
	return caps.capabilities;
}

- (void)setCapabilitiesFetchFailedForJID:(XMPPJID *)jid
{
	XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid];
	resource.haveFailed = YES;
}

- (void)clearAllNonPersistentCapabilities
{
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPCapsResourceCoreDataStorageObject"
	                                          inManagedObjectContext:[self managedObjectContext]];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	
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
}

- (void)clearNonPersistentCapabilitiesForJID:(XMPPJID *)jid
{
	XMPPCapsResourceCoreDataStorageObject *resource = [self resourceForJID:jid];
	
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
}

@end
