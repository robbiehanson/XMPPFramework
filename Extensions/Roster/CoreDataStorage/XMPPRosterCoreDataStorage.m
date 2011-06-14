#import "XMPPRosterCoreDataStorage.h"
#import "XMPPUserCoreDataStorageObject.h"
#import "XMPPResourceCoreDataStorageObject.h"
#import "XMPPRosterPrivate.h"
#import "XMPPCoreDataStorageProtected.h"
#import "XMPP.h"
#import "XMPPLogging.h"
#import "NSNumber+XMPP.h"

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

@implementation XMPPRosterCoreDataStorage

static XMPPRosterCoreDataStorage *sharedInstance;

+ (XMPPRosterCoreDataStorage *)sharedInstance
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		sharedInstance = [[XMPPRosterCoreDataStorage alloc] initWithDatabaseFilename:nil];
	});
	
	return sharedInstance;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Setup
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)init
{
	return [self initWithDatabaseFilename:nil];
}

- (id)initWithDatabaseFilename:(NSString *)aDatabaseFileName
{
	if ((self = [super initWithDatabaseFilename:aDatabaseFileName]))
	{
		rosterPopulationSet = [[NSMutableSet alloc] init];
	}
	return self;
}

- (BOOL)configureWithParent:(XMPPRoster *)aParent queue:(dispatch_queue_t)queue
{
	return [super configureWithParent:aParent queue:queue];
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

- (id <XMPPUser>)_userForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
	NSAssert(dispatch_get_current_queue() == storageQueue, @"Invoked on incorrect queue");
	
	
	if (jid == nil) return nil;
	
	NSString *bareJIDStr = [jid bare];
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPUserCoreDataStorageObject"
	                                          inManagedObjectContext:[self managedObjectContext]];
	
	NSPredicate *predicate;
	if (stream == nil)
		predicate = [NSPredicate predicateWithFormat:@"jidStr == %@", bareJIDStr];
	else
		predicate = [NSPredicate predicateWithFormat:@"jidStr == %@ AND streamBareJidStr == %@",
					 bareJIDStr, [[self myJIDForXMPPStream:stream] bare]];
	
	NSFetchRequest *fetchRequest = [[[NSFetchRequest alloc] init] autorelease];
	[fetchRequest setEntity:entity];
	[fetchRequest setPredicate:predicate];
	[fetchRequest setIncludesPendingChanges:YES];
	[fetchRequest setFetchLimit:1];
	
	NSArray *results = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
	
	return (XMPPUserCoreDataStorageObject *)[results lastObject];
}

- (id <XMPPResource>)_resourceForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
	NSAssert(dispatch_get_current_queue() == storageQueue, @"Invoked on incorrect queue");
	
	
	if (jid == nil) return nil;
	
	NSString *fullJIDStr = [jid full];
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPResourceCoreDataStorageObject"
	                                          inManagedObjectContext:[self managedObjectContext]];
	
	NSPredicate *predicate;
	if (stream == nil)
		predicate = [NSPredicate predicateWithFormat:@"jidStr == %@", fullJIDStr];
	else
		predicate = [NSPredicate predicateWithFormat:@"jidStr == %@ AND streamBareJidStr == %@",
					 fullJIDStr, [[self myJIDForXMPPStream:stream] bare]];
	
	NSFetchRequest *fetchRequest = [[[NSFetchRequest alloc] init] autorelease];
	[fetchRequest setEntity:entity];
	[fetchRequest setPredicate:predicate];
	[fetchRequest setIncludesPendingChanges:YES];
	[fetchRequest setFetchLimit:1];
	
	NSArray *results = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
	
	return (XMPPResourceCoreDataStorageObject *)[results lastObject];
}

- (void)_clearAllResourcesForXMPPStream:(XMPPStream *)stream
{
	NSAssert(dispatch_get_current_queue() == storageQueue, @"Invoked on incorrect queue");
	
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPResourceCoreDataStorageObject"
	                                          inManagedObjectContext:[self managedObjectContext]];
	
	NSFetchRequest *fetchRequest = [[[NSFetchRequest alloc] init] autorelease];
	[fetchRequest setEntity:entity];
	[fetchRequest setFetchBatchSize:saveThreshold];
	
	if (stream)
	{
		NSPredicate *predicate;
		predicate = [NSPredicate predicateWithFormat:@"streamBareJidStr == %@",
		                                    [[self myJIDForXMPPStream:stream] bare]];
		
		[fetchRequest setPredicate:predicate];
	}
	
	NSArray *allResources = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
	
	NSUInteger unsavedCount = [self numberOfUnsavedChanges];
	
	for (XMPPResourceCoreDataStorageObject *resource in allResources)
	{
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

- (void)willCreatePersistentStore:(NSString *)filePath
{
	// This method is overriden from the XMPPCoreDataStore superclass.
	// From the documentation:
	// 
	// Override me, if needed, to provide customized behavior.
	// 
	// For example, if you are using the database for non-persistent data you may want to delete the database
	// file if it already exists on disk.
	// 
	// The default implementation does nothing.
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:filePath])
	{
		[[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
	}
}

- (void)didCreateManagedObjectContext
{
	// This method is overriden from the XMPPCoreDataStore superclass.
	// From the documentation:
	// 
	// Override me, if needed, to provide customized behavior.
	// 
	// For example, if you are using the database for non-persistent data you may want to delete the database
	// file if it already exists on disk.
	// 
	// The default implementation does nothing.
	
	
	// Reserved for future use (directory versioning).
	// Perhaps invoke [self _clearAllResourcesForXMPPStream:nil] ?
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
	
	__block XMPPUserCoreDataStorageObject *result;
	
	[self executeBlock:^{
	
		result = [[self _userForJID:myJID xmppStream:stream] retain];
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
	
	__block XMPPResourceCoreDataStorageObject *result;
	
	[self executeBlock:^{
		
		result = [[self resourceForJID:myJID xmppStream:stream] retain];
	}];
	
	return [result autorelease];
}

- (id <XMPPUser>)userForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	__block XMPPUserCoreDataStorageObject *result;
	
	[self executeBlock:^{
		
		result = [[self _userForJID:jid xmppStream:stream] retain];
	}];
		
	return [result autorelease];
}

- (id <XMPPResource>)resourceForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	__block XMPPResourceCoreDataStorageObject *result;
	
	[self executeBlock:^{
		
		result = [[self _resourceForJID:jid xmppStream:stream] retain];
	}];
	
	return [result autorelease];
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

- (void)handleRosterItem:(NSXMLElement *)itemSubElement xmppStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	// Remember XML heirarchy memory management rules.
	// The passed parameter is a subnode of the IQ, and we need to pass it to an asynchronous operation.
	NSXMLElement *item = [[itemSubElement copy] autorelease];
	
	[self scheduleBlock:^{
		
		if ([self isRosterItem:item])
		{
			if ([rosterPopulationSet containsObject:[NSNumber numberWithPtr:stream]])
			{
				NSString *streamBareJidStr = [[self myJIDForXMPPStream:stream] bare];
				
				[XMPPUserCoreDataStorageObject insertInManagedObjectContext:[self managedObjectContext]
				                                             withItem:item
				                                     streamBareJidStr:streamBareJidStr];
			}
			else
			{
				NSString *jidStr = [item attributeStringValueForName:@"jid"];
				XMPPJID *jid = [[XMPPJID jidWithString:jidStr] bareJID];
				
				XMPPUserCoreDataStorageObject *user = (XMPPUserCoreDataStorageObject *)[self _userForJID:jid xmppStream:stream];
				
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
						NSString *streamBareJidStr = [[self myJIDForXMPPStream:stream] bare];
						
						[XMPPUserCoreDataStorageObject insertInManagedObjectContext:[self managedObjectContext]
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
		XMPPUserCoreDataStorageObject *user = (XMPPUserCoreDataStorageObject *)[self _userForJID:jid xmppStream:stream];
		
		if (user)
		{
			NSString *streamBareJidStr = [[self myJIDForXMPPStream:stream] bare];
			
			[user updateWithPresence:presence streamBareJidStr:streamBareJidStr];
		}
	}];
}

- (void)clearAllResourcesForXMPPStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	[self scheduleBlock:^{
		
		[self _clearAllResourcesForXMPPStream:stream];
	}];
}

- (void)clearAllUsersAndResourcesForXMPPStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	[self scheduleBlock:^{
		
		// Note: Deleting a user will delete all associated resources
		// because of the cascade rule in our core data model.
		
		NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPUserCoreDataStorageObject"
												  inManagedObjectContext:[self managedObjectContext]];
		
		NSFetchRequest *fetchRequest = [[[NSFetchRequest alloc] init] autorelease];
		[fetchRequest setEntity:entity];
		[fetchRequest setFetchBatchSize:saveThreshold];
		
		if (stream)
		{
			NSPredicate *predicate;
			predicate = [NSPredicate predicateWithFormat:@"streamBareJidStr == %@",
			                            [[self myJIDForXMPPStream:stream] bare]];
			
			[fetchRequest setPredicate:predicate];
		}
		
		NSArray *allUsers = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
		
		NSUInteger unsavedCount = [self numberOfUnsavedChanges];
		
		for (XMPPUserCoreDataStorageObject *user in allUsers)
		{
			[[self managedObjectContext] deleteObject:user];
			
			if (++unsavedCount >= saveThreshold)
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
	[rosterPopulationSet release];
	[super dealloc];
}

@end
