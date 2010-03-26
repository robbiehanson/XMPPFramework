#import "XMPPRosterCoreDataStorage.h"
#import "XMPPRosterPrivate.h"
#import "XMPPUserCoreDataStorage.h"
#import "XMPPResourceCoreDataStorage.h"
#import "XMPP.h"


@implementation XMPPRosterCoreDataStorage

@synthesize parent;

@dynamic managedObjectModel;
@dynamic persistentStoreCoordinator;
@dynamic managedObjectContext;

- (id)init
{
	if ((self = [super init]))
	{
		isRosterPopulation = NO;
	}
	return self;
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
	if (managedObjectModel)
	{
		return managedObjectModel;
	}
	
	NSString *path = [[NSBundle mainBundle] pathForResource:@"XMPPRoster" ofType:@"mom"];
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
		if(!persistentStore)
		{
			NSLog(@"=====================================================================================");
			NSLog(@"Error creating persistent store:\n%@", error);
		#if TARGET_OS_IPHONE
			NSLog(@"Chaned core data model recently? Quick Fix: Delete the app from device and reinstall.");
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
#pragma mark XMPPUser Protocol
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id <XMPPUser>)myUser
{
	XMPPJID *myJID = parent.xmppStream.myJID;
	
	return [self userForJID:myJID];
}

- (id <XMPPResource>)myResource
{
	XMPPJID *myJID = parent.xmppStream.myJID;
	
	return [self resourceForJID:myJID];
}

- (id <XMPPUser>)userForJID:(XMPPJID *)jid
{
	if (jid == nil) return nil;
	
	NSString *bareJIDStr = [jid bare];
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPUserCoreDataStorage"
	                                          inManagedObjectContext:[self managedObjectContext]];
	
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"jidStr == %@", bareJIDStr];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	[fetchRequest setPredicate:predicate];
	[fetchRequest setIncludesPendingChanges:YES];
	[fetchRequest setFetchLimit:1];
	
	NSArray *results = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
	
	[fetchRequest release];
	
	return (XMPPUserCoreDataStorage *)[results lastObject];
}

- (id <XMPPResource>)resourceForJID:(XMPPJID *)jid
{
	if (jid == nil) return nil;
	
	NSString *fullJIDStr = [jid full];
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPResourceCoreDataStorage"
	                                          inManagedObjectContext:[self managedObjectContext]];
	
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"jidStr == %@", fullJIDStr];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	[fetchRequest setPredicate:predicate];
	[fetchRequest setIncludesPendingChanges:YES];
	[fetchRequest setFetchLimit:1];
	
	NSArray *results = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
	
	[fetchRequest release];
	
	return (XMPPResourceCoreDataStorage *)[results lastObject];
}

- (void)beginRosterPopulation
{
	isRosterPopulation = YES;
}

- (void)endRosterPopulation
{
	isRosterPopulation = NO;
	
	[[self managedObjectContext] save:nil];
}

- (void)handleRosterItem:(NSXMLElement *)item
{
	if ([self isRosterItem:item])
	{
		if (isRosterPopulation)
		{
			[XMPPUserCoreDataStorage insertInManagedObjectContext:[self managedObjectContext] withItem:item];
		}
		else
		{
			NSString *jidStr = [item attributeStringValueForName:@"jid"];
			XMPPJID *jid = [[XMPPJID jidWithString:jidStr] bareJID];
			
			XMPPUserCoreDataStorage *user = (XMPPUserCoreDataStorage *)[self userForJID:jid];
			
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
					[XMPPUserCoreDataStorage insertInManagedObjectContext:[self managedObjectContext] withItem:item];
				}
			}
			
			[[self managedObjectContext] save:nil];
		}
	}
}

- (void)handlePresence:(XMPPPresence *)presence
{
	XMPPJID *jid = [presence from];
	XMPPUserCoreDataStorage *user = (XMPPUserCoreDataStorage *)[self userForJID:jid];
	
	if (user)
	{
		[user updateWithPresence:presence];
		
		[[self managedObjectContext] save:nil];
	}
}

- (void)clearAllResources
{
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPResourceCoreDataStorage"
	                                          inManagedObjectContext:[self managedObjectContext]];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	
	NSArray *allResources = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
	
	[fetchRequest release];
	
	for (XMPPResourceCoreDataStorage *resource in allResources)
	{
		[[self managedObjectContext] deleteObject:resource];
	}
	
	[[self managedObjectContext] save:nil];
}

- (void)clearAllUsersAndResources
{
	// Note: Deleting a user will delete all associated resources because of the cascade rule in our core data model.
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPUserCoreDataStorage"
	                                          inManagedObjectContext:[self managedObjectContext]];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	
	NSArray *allUsers = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
	
	[fetchRequest release];
	
	for (XMPPUserCoreDataStorage *user in allUsers)
	{
		[[self managedObjectContext] deleteObject:user];
	}
	
	[[self managedObjectContext] save:nil];
}

@end
