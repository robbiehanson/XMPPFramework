#import "XMPPRosterCoreDataStorage.h"

#import "DDLog.h"

#import "XMPPRosterPrivate.h"
#import "XMPPUserCoreDataStorage.h"
#import "XMPPResourceCoreDataStorage.h"
#import "XMPPStreamCoreDataStorage.h"
#import "XMPP.h"


@implementation XMPPRosterCoreDataStorage

@dynamic managedObjectModel;
@dynamic persistentStoreCoordinator;
@dynamic managedObjectContext;
@synthesize rosterPopulation;

#pragma mark -
#pragma mark init

- (id)init
{
	if ((self = [super init]))
	{
        self.rosterPopulation = [NSMutableDictionary dictionaryWithCapacity:2];
	}
	return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [managedObjectContext release];
    [persistentStoreCoordinator release];
    [managedObjectModel release];
    [rosterPopulation release];
    
    [super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Core Data Setup
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)persistentStoreDirectory
{
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
  NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
  
  NSBundle *bundle = [NSBundle mainBundle];
  
	// Attempt to find a name for this application
	NSString *appName = [bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];
	if (appName == nil) {
		appName = [bundle objectForInfoDictionaryKey:@"CFBundleName"];	
	}
  
  if (appName == nil) {
    appName = @"xmppframework";
  }
  
  NSString *result = [basePath stringByAppendingPathComponent:appName];
	
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

#pragma mark -
#pragma mark Notifcations


- (void)mergeChanges:(NSNotification *)notification
{    
    DDLogVerbose(@"%s",__PRETTY_FUNCTION__);
    
    // Merge changes into the main context on the main thread
    [self.managedObjectContext performSelectorOnMainThread:@selector(mergeChangesFromContextDidSaveNotification:)
                                                withObject:notification
                                             waitUntilDone:YES];  
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utility Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)addXMPPStream:(XMPPStream *)xmppStream {
    [XMPPStreamCoreDataStorage insertInManagedObjectContext:[self managedObjectContext] 
                                                 withStream:xmppStream];

    NSError *error = nil;
	
	if (![[self managedObjectContext] save:&error]) {
		DDLogError(@"%s ERROR: %@", __PRETTY_FUNCTION__,error);
	}
}

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
#pragma mark XMPPRosterStorage Protocol
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id <XMPPUser>)myUserForXMPPStream:(XMPPStream *)xmppStream {
    XMPPJID *myJID = xmppStream.myJID;
    
    return [self userForJID:myJID xmppStream:xmppStream];
}

- (id <XMPPResource>)myResourceForXMPPStream:(XMPPStream *)xmppStream
{
	XMPPJID *myJID = xmppStream.myJID;
	
	return [self resourceForJID:myJID xmppStream:xmppStream];
}


- (id <XMPPUser>)userForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)xmppStream
{
	if (jid == nil || xmppStream == nil) return nil;
	
	NSString *bareJIDStr = [jid bare];
    NSString *myJIDStr = [[xmppStream myJID] full];
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPUserCoreDataStorage"
	                                          inManagedObjectContext:[self managedObjectContext]];
	
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"jidStr == %@ AND stream.myJIDStr == %@", bareJIDStr, myJIDStr];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	[fetchRequest setPredicate:predicate];
	[fetchRequest setIncludesPendingChanges:YES];
	[fetchRequest setFetchLimit:1];
	
	NSArray *results = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
	
	[fetchRequest release];
	
	return (XMPPUserCoreDataStorage *)[results lastObject];
}

- (id <XMPPResource>)resourceForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)xmppStream
{
	if (jid == nil || xmppStream == nil) return nil;
	
	NSString *fullJIDStr = [jid full];
    NSString *myJIDStr = [[xmppStream myJID] full];
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPResourceCoreDataStorage"
	                                          inManagedObjectContext:[self managedObjectContext]];
	
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"jidStr == %@ AND stream.myJIDStr == %@", fullJIDStr, myJIDStr];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
	[fetchRequest setPredicate:predicate];
	[fetchRequest setIncludesPendingChanges:YES];
	[fetchRequest setFetchLimit:1];
	
	NSArray *results = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
	
	[fetchRequest release];
	
	return (XMPPResourceCoreDataStorage *)[results lastObject];
}

- (void)beginRosterPopulationForXMPPStream:(XMPPStream *)xmppStream
{
    NSManagedObjectContext *rosterPopulationManagedObjectContext = [[[NSManagedObjectContext alloc] init] autorelease];
    [rosterPopulationManagedObjectContext setPersistentStoreCoordinator:[self persistentStoreCoordinator]];
            
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(mergeChanges:)
                                                 name:NSManagedObjectContextDidSaveNotification
                                               object:rosterPopulationManagedObjectContext];
    XMPPJID *myJID = [xmppStream myJID];
    
    [self.rosterPopulation setObject:rosterPopulationManagedObjectContext forKey:myJID];
}

- (void)endRosterPopulationForXMPPStream:(XMPPStream *)xmppStream
{
    XMPPJID *myJID = [xmppStream myJID];
    NSManagedObjectContext *rosterPopulationManagedObjectContext = [self.rosterPopulation objectForKey:myJID];

	[rosterPopulationManagedObjectContext save:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSManagedObjectContextDidSaveNotification
                                                  object:rosterPopulationManagedObjectContext];
    
    [self.rosterPopulation removeObjectForKey:myJID];
}

- (void)handleRosterItem:(NSXMLElement *)item xmppStream:(XMPPStream *)xmppStream
{
	if ([self isRosterItem:item])
	{
        //DDLogTrace();
        XMPPUserCoreDataStorage *user = nil;

        NSManagedObjectContext *rosterPopulationManagedObjectContext = [self.rosterPopulation objectForKey:[xmppStream myJID]];
        
		if (rosterPopulationManagedObjectContext != nil)
		{
			[XMPPUserCoreDataStorage insertInManagedObjectContext:rosterPopulationManagedObjectContext
                                                              xmppStream:xmppStream
                                                                withItem:item];
		}
		else
		{
			NSString *jidStr = [item attributeStringValueForName:@"jid"];
			XMPPJID *jid = [[XMPPJID jidWithString:jidStr] bareJID];
			
			user = (XMPPUserCoreDataStorage *)[self userForJID:jid xmppStream:xmppStream];
			
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
                                                               xmppStream:xmppStream
                                                                 withItem:item];
				}
			}
			
			[[self managedObjectContext] save:nil];
		}
	}
}

- (void)handlePresence:(XMPPPresence *)presence xmppStream:(XMPPStream *)xmppStream
{
	XMPPJID *jid = [presence from];
	XMPPUserCoreDataStorage *user = (XMPPUserCoreDataStorage *)[self userForJID:jid xmppStream:xmppStream];
	
	if (user)
	{
		[user updateWithPresence:presence];
		
    NSError *error = nil;
		[[self managedObjectContext] save:&error];
    
    if (error != nil) {
      DDLogError(@"%s %@",__PRETTY_FUNCTION__, error);
    }
	}
}

- (void)clearAllResourcesForXMPPStream:(XMPPStream *)xmppStream
{
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPResourceCoreDataStorage"
	                                          inManagedObjectContext:[self managedObjectContext]];
    NSString *myJIDStr = [[xmppStream myJID] full];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"user.stream.myJIDStr == %@", myJIDStr];

	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
    [fetchRequest setPredicate:predicate];
	
	NSArray *allResources = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
	
	[fetchRequest release];
	
	for (XMPPResourceCoreDataStorage *resource in allResources)
	{
		[[self managedObjectContext] deleteObject:resource];
	}
	
	[[self managedObjectContext] save:nil];
}

- (void)clearAllUsersAndResourcesForXMPPStream:(XMPPStream *)xmppStream
{
	// Note: Deleting a user will delete all associated resources because of the cascade rule in our core data model.
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPUserCoreDataStorage"
	                                          inManagedObjectContext:[self managedObjectContext]];
    NSString *myJIDStr = [[xmppStream myJID] full];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"stream.myJIDStr == %@", myJIDStr];

	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entity];
    [fetchRequest setPredicate:predicate];
	
	NSArray *allUsers = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
	
	[fetchRequest release];
	
	for (XMPPUserCoreDataStorage *user in allUsers)
	{
		[[self managedObjectContext] deleteObject:user];
	}
	
	[[self managedObjectContext] save:nil];
}

@end
