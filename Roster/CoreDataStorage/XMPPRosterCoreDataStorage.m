#import "XMPPRosterCoreDataStorage.h"
#import "XMPPRosterPrivate.h"
#import "XMPPUserCoreDataStorage.h"
#import "XMPPResourceCoreDataStorage.h"
#import "XMPP.h"
#import "XMPPLogging.h"
#import "DDNumber.h"

#import <objc/runtime.h>

// Log levels: off, error, warn, info, verbose
static const int xmppLogLevel = XMPP_LOG_LEVEL_VERBOSE | XMPP_LOG_FLAG_TRACE;

#define AUTORELEASED_BLOCK(block) ^{                            \
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; \
    block();                                                    \
    [pool drain];                                               \
}


@implementation XMPPRosterCoreDataStorage

- (id)init
{
	return [self initForSingleUsage];
}

- (id)initForSingleUsage
{
	if ((self = [super init]))
	{
		singleUsage = YES;
		rosterPopulationSet = [[NSMutableSet alloc] init];
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
		rosterPopulationSet = [[NSMutableSet alloc] init];
		
		if (queue)
		{
			storageQueue = queue;
			dispatch_retain(storageQueue);
		}
		else
		{
			storageQueue = dispatch_queue_create(class_getName([self class]), NULL);
		}
	}
	return self;
}

- (BOOL)configureWithParent:(XMPPRoster *)aParent queue:(dispatch_queue_t)queue
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
		NSString *storePath = [docsPath stringByAppendingPathComponent:@"XMPPRoster.sqlite"];
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
#pragma mark Utility Methods
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Protocol Public API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id <XMPPUser>)myUserForXMPPStream:(XMPPStream *)stream
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	if (storageQueue == NULL)
	{
		XMPPLogWarn(@"%@: Method(%@) invoked before storage configured by parent.", THIS_FILE, THIS_METHOD);
		return nil;
	}
	
	XMPPJID *myJID = stream.myJID;
	if (myJID == nil)
	{
		return nil;
	}
	
	if (dispatch_get_current_queue() == storageQueue)
	{
		return [self userForJID:myJID xmppStream:stream];
	}
	else
	{
		__block XMPPUserCoreDataStorage *result;
		
		dispatch_sync(storageQueue, AUTORELEASED_BLOCK(^{
			
			result = [[self userForJID:myJID xmppStream:stream] retain];
		}));
		
		return [result autorelease];
	}
}

- (id <XMPPResource>)myResourceForXMPPStream:(XMPPStream *)stream
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	if (storageQueue == NULL)
	{
		XMPPLogWarn(@"%@: Method(%@) invoked before storage configured by parent.", THIS_FILE, THIS_METHOD);
		return nil;
	}
	
	XMPPJID *myJID = stream.myJID;
	if (myJID == nil)
	{
		return nil;
	}
	
	if (dispatch_get_current_queue() == storageQueue)
	{
		return [self resourceForJID:myJID xmppStream:stream];
	}
	else
	{
		__block XMPPResourceCoreDataStorage *result;
		
		dispatch_sync(storageQueue, AUTORELEASED_BLOCK(^{
			
			result = [[self resourceForJID:myJID xmppStream:stream] retain];
		}));
		
		return [result autorelease];
	}
}

- (id <XMPPUser>)userForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	if (storageQueue == NULL)
	{
		XMPPLogWarn(@"%@: Method(%@) invoked before storage configured by parent.", THIS_FILE, THIS_METHOD);
		return nil;
	}
	
	if (jid == nil) return nil;
	
	NSString *bareJIDStr = [jid bare];
	
	__block XMPPUserCoreDataStorage *result;
	
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPUserCoreDataStorage"
		                                          inManagedObjectContext:[self managedObjectContext]];
		
		NSPredicate *predicate;
		if (stream == nil)
			predicate = [NSPredicate predicateWithFormat:@"jidStr == %@", bareJIDStr];
		else
			predicate = [NSPredicate predicateWithFormat:@"stream == %@ AND jidStr == %@", [NSNumber numberWithPtr:stream], bareJIDStr];
		
		NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
		[fetchRequest setEntity:entity];
		[fetchRequest setPredicate:predicate];
		[fetchRequest setIncludesPendingChanges:YES];
		[fetchRequest setFetchLimit:1];
		
		NSArray *results = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
		
		[fetchRequest release];
		
		result = (XMPPUserCoreDataStorage *)[[results lastObject] retain];
		
		[pool drain];
	};
	
	if (dispatch_get_current_queue() == storageQueue)
		block();
	else
		dispatch_sync(storageQueue, block);
	
	return [result autorelease];
}

- (id <XMPPResource>)resourceForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	if (storageQueue == NULL)
	{
		XMPPLogWarn(@"%@: Method(%@) invoked before storage configured by parent.", THIS_FILE, THIS_METHOD);
		return nil;
	}
	
	if (jid == nil) return nil;
	
	NSString *fullJIDStr = [jid full];
	
	__block XMPPResourceCoreDataStorage *result;
	
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPResourceCoreDataStorage"
		                                          inManagedObjectContext:[self managedObjectContext]];
		
		NSPredicate *predicate;
		if (stream == nil)
			predicate = [NSPredicate predicateWithFormat:@"jidStr == %@", fullJIDStr];
		else
			predicate = [NSPredicate predicateWithFormat:@"stream == %p AND jidStr == %@", stream, fullJIDStr];
		
		NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
		[fetchRequest setEntity:entity];
		[fetchRequest setPredicate:predicate];
		[fetchRequest setIncludesPendingChanges:YES];
		[fetchRequest setFetchLimit:1];
		
		NSArray *results = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
		
		[fetchRequest release];
		
		result = (XMPPResourceCoreDataStorage *)[[results lastObject] retain];
		
		[pool drain];
	};
	
	if (dispatch_get_current_queue() == storageQueue)
		block();
	else
		dispatch_sync(storageQueue, block);
	
	return [result autorelease];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Protocol Private API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)beginRosterPopulationForXMPPStream:(XMPPStream *)stream
{
	NSAssert(dispatch_get_current_queue() == storageQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	[rosterPopulationSet addObject:[NSNumber numberWithPtr:stream]];
}

- (void)endRosterPopulationForXMPPStream:(XMPPStream *)stream
{
	NSAssert(dispatch_get_current_queue() == storageQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	[rosterPopulationSet removeObject:[NSNumber numberWithPtr:stream]];
	
	[[self managedObjectContext] save:nil];
}

- (void)handleRosterItem:(NSXMLElement *)item xmppStream:(XMPPStream *)stream
{
	NSAssert(dispatch_get_current_queue() == storageQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	if ([self isRosterItem:item])
	{
		if ([rosterPopulationSet containsObject:[NSNumber numberWithPtr:stream]])
		{
			[XMPPUserCoreDataStorage insertInManagedObjectContext:[self managedObjectContext]
			                                             withItem:item
			                                           xmppStream:stream];
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
					[[self managedObjectContext] deleteObject:user];
				}
			}
			else
			{
				if (user)
				{
					[user updateWithItem:item];
				}
				else
				{
					[XMPPUserCoreDataStorage insertInManagedObjectContext:[self managedObjectContext]
					                                             withItem:item
					                                           xmppStream:stream];
				}
			}
			
			[[self managedObjectContext] save:nil];
		}
	}
}

- (void)handlePresence:(XMPPPresence *)presence xmppStream:(XMPPStream *)stream
{
	NSAssert(dispatch_get_current_queue() == storageQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	XMPPJID *jid = [presence from];
	XMPPUserCoreDataStorage *user = (XMPPUserCoreDataStorage *)[self userForJID:jid xmppStream:stream];
	
	if (user)
	{
		[user updateWithPresence:presence xmppStream:stream];
		
		if (![rosterPopulationSet containsObject:[NSNumber numberWithPtr:stream]])
		{
			[[self managedObjectContext] save:nil];
		}
	}
}

- (void)clearAllResourcesForXMPPStream:(XMPPStream *)stream
{
	NSAssert(dispatch_get_current_queue() == storageQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPResourceCoreDataStorage"
	                                          inManagedObjectContext:[self managedObjectContext]];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	
	if (stream)
	{
		[fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"stream == %p", stream]];
	}
	
	NSArray *allResources = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
	
	[fetchRequest release];
	
	for (XMPPResourceCoreDataStorage *resource in allResources)
	{
		[[self managedObjectContext] deleteObject:resource];
	}
	
	[[self managedObjectContext] save:nil];
}

- (void)clearAllUsersAndResourcesForXMPPStream:(XMPPStream *)stream
{
	NSAssert(dispatch_get_current_queue() == storageQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	// Note: Deleting a user will delete all associated resources because of the cascade rule in our core data model.
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPUserCoreDataStorage"
	                                          inManagedObjectContext:[self managedObjectContext]];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	
	if (stream)
	{
		[fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"stream == %p", stream]];
	}
	
	NSArray *allUsers = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
	
	[fetchRequest release];
	
	for (XMPPUserCoreDataStorage *user in allUsers)
	{
		[[self managedObjectContext] deleteObject:user];
	}
	
	[[self managedObjectContext] save:nil];
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
	
	[rosterPopulationSet release];
	
	[managedObjectContext release];
	[persistentStoreCoordinator release];
	[managedObjectModel release];
	
	[super dealloc];
}

@end
