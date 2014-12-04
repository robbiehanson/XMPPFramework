#import "ServerlessDemoAppDelegate.h"
#import "RootViewController.h"
#import "BonjourClient.h"
#import "StreamController.h"
#import "XMPPJID.h"
#import "XMPPLogging.h"
#import "DDLog.h"
#import "DDTTYLogger.h"

#import <arpa/inet.h>

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_VERBOSE;


@implementation ServerlessDemoAppDelegate

@synthesize window;
@synthesize navigationController;
@synthesize myJID;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark App Delegate Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL) application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	// Configure logging
	
    [DDLog addLogger:[DDTTYLogger sharedInstance] withLogLevel:XMPP_LOG_FLAG_SEND_RECV];
	
	// Configure UI
	
	RootViewController *rootViewController = (RootViewController *)[navigationController topViewController];
	rootViewController.managedObjectContext = self.managedObjectContext;
	
	window.rootViewController = navigationController;
    [window makeKeyAndVisible];
	
	// Configure everything else
	
	NSString *jidStr = [NSString stringWithFormat:@"demo@%@", [[[UIDevice currentDevice] name] stringByReplacingOccurrencesOfString:@" " withString:@""]];
	self.myJID = [XMPPJID jidWithString:jidStr];
	
	BonjourClient *bonjourClient = [BonjourClient sharedInstance];
	StreamController *streamController = [StreamController sharedInstance];
	
	[streamController startListening];
	
	[bonjourClient startBrowsing];
	[bonjourClient publishServiceOnPort:[streamController listeningPort]];
    
    return YES;
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	// Don't bother saving the data.
	// We currently delete the SQL database file on app launch.
	
//	if (managedObjectContext && [managedObjectContext hasChanges])
//	{
//		NSError *error = nil;
//		
//		if (![managedObjectContext save:&error])
//		{
//			DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
//			abort();
//        }
//	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Core Data stack
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns the managed object model for the application.
 * If the model doesn't already exist, it is created by merging all of the models found in the application bundle.
**/
- (NSManagedObjectModel *)managedObjectModel
{
	if (managedObjectModel != nil) {
        return managedObjectModel;
    }
    managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];    
    return managedObjectModel;
}

/**
 * Returns the persistent store coordinator for the application.
 * If the coordinator doesn't already exist, it is created and the application's store added to it.
**/
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
	if (persistentStoreCoordinator != nil) {
        return persistentStoreCoordinator;
    }
	
	NSString *storeName = @"ServerlessDemo.sqlite";
	NSString *storePath = [[self applicationDocumentsDirectory] stringByAppendingPathComponent:storeName];
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:storePath])
	{
		[[NSFileManager defaultManager] removeItemAtPath:storePath error:NULL];
	}
	
    NSURL *storeUrl = [NSURL fileURLWithPath:storePath];
	
	NSManagedObjectModel *mom = [self managedObjectModel];
	
	NSError *error = nil;
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
	
	NSPersistentStore *persistentStore = [persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
	                                                                              configuration:nil
	                                                                                        URL:storeUrl
	                                                                                    options:nil
	                                                                                      error:&error];
    if (persistentStore == nil)
	{
		DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
		abort();
    }    
	
    return persistentStoreCoordinator;
}

/**
 * Returns the managed object context for the application.
 * If the context doesn't already exist, it is created and
 * bound to the persistent store coordinator for the application.
**/
- (NSManagedObjectContext *)managedObjectContext
{
	if (managedObjectContext != nil) {
        return managedObjectContext;
    }
	
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        managedObjectContext = [[NSManagedObjectContext alloc] init];
        [managedObjectContext setPersistentStoreCoordinator: coordinator];
    }
    return managedObjectContext;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Common Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns the path to the application's Documents directory.
**/
- (NSString *)applicationDocumentsDirectory
{
	return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}

/**
 * The iPhone only supports IPv4, so we often need to filter a list
 * of resolved addresses into just the IPv4 address.
**/
- (NSData *)IPv4AddressFromAddresses:(NSArray *)addresses
{
	// The iPhone only supports IPv4, so we need to get the IPv4 address from the resolve operation.
	
	for (NSData *address in addresses)
	{
		struct sockaddr *sa = (struct sockaddr *)[address bytes];
		
		if(sa->sa_family == AF_INET)
		{
			return address;
		}
	}
	
	return nil;
}

/**
 * Returns the human readable version of the given address.
 * Does not include the port number.
**/
- (NSString *)stringFromAddress:(NSData *)address
{
	struct sockaddr *sa = (struct sockaddr *)[address bytes];
	
	if(sa->sa_family == AF_INET)
	{
		char addr[INET_ADDRSTRLEN];
		struct sockaddr_in *sin = (struct sockaddr_in *)sa;
		
		if(inet_ntop(AF_INET, &sin->sin_addr, addr, sizeof(addr)))
		{
			return [NSString stringWithUTF8String:addr];
		}
	}
	else if(sa->sa_family == AF_INET6)
	{
		char addr[INET6_ADDRSTRLEN];
		struct sockaddr_in6 *sin6 = (struct sockaddr_in6 *)sa;
		
		if(inet_ntop(AF_INET6, &sin6->sin6_addr, addr, sizeof(addr)))
		{
			return [NSString stringWithUTF8String:addr];
		}
	}
	
	return nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Memory management
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



@end

