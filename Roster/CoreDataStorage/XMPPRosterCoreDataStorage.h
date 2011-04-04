#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "XMPPRoster.h"

/**
 * This class is an example implementation of XMPPRosterStorage using core data.
 * You are free to substitute your own roster storage class.
**/

@interface XMPPRosterCoreDataStorage : NSObject <XMPPRosterStorage>
{
	NSString *databaseFileName;
	NSMutableDictionary *myJidCache;
	
	dispatch_queue_t storageQueue;
	
	int32_t unsavedCount;
	int32_t pendingRequests;
	
	NSMutableSet *rosterPopulationSet;
	
	NSManagedObjectModel *managedObjectModel;
	NSPersistentStoreCoordinator *persistentStoreCoordinator;
	NSManagedObjectContext *managedObjectContext;
}

/**
 * Convenience method to get an instance with the default database name.
 * 
 * IMPORTANT:
 * You are NOT required to use the sharedInstance.
 * 
 * If your application uses multiple xmppStreams, and you use a sharedInstance of this class,
 * then all of your streams share the same database store. You might get better performance if you create
 * multiple instances of this class instead (using different database filenames), as this way you can have
 * concurrent writes to multiple databases.
**/
+ (XMPPRosterCoreDataStorage *)sharedInstance;

/**
 * Initializes the core data storage instance, with the given database store filename.
 * It is recommended your filname use the "sqlite" file extension.
 * If you pass nil, the default value of "XMPPRoster.sqlite" is automatically used.
 * 
 * If you attempt to create an instance of this class with the same databaseFileName as another existing instance,
 * this method will return nil.
**/
- (id)initWithDatabaseFilename:(NSString *)databaseFileName;


@property (readonly) NSString *databaseFileName;

@property (readonly) NSManagedObjectModel *managedObjectModel;
@property (readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;

// The managedObjectContext is private to the storageQueue.
// You must create and use your own managedObjectContext.
// 
// If you think you can simply add a property for the private managedObjectContext,
// then you need to go read the documentation for core data,
// specifically the section entitled "Concurrency with Core Data".

@end
