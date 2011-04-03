#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "XMPPCapabilities.h"

/**
 * This class is an example implementation of XMPPCapabilitiesStorage using core data.
 * You are free to substitute your own storage class.
**/

@interface XMPPCapabilitiesCoreDataStorage : NSObject <XMPPCapabilitiesStorage>
{
	NSString *databaseFileName;
	NSMutableDictionary *myJidCache;
	
	int32_t unsavedCount;
	int32_t pendingRequests;
	
	dispatch_queue_t storageQueue;
	
	NSManagedObjectModel *managedObjectModel;
	NSPersistentStoreCoordinator *persistentStoreCoordinator;
	NSManagedObjectContext *managedObjectContext;
}

/**
 * XEP-0115 provides a mechanism for hashing a list of capabilities.
 * Clients then broadcast this hash instead of the entire list to save bandwidth.
 * Because the hashing is standardized, it is safe to persistently store the linked hash & capabilities.
 * 
 * For this reason, it is recommended you use this sharedInstance across all your xmppStreams.
 * This way all streams can shared a knowledgebase concerning known hashes.
 * 
 * All other aspects of capabilities handling (such as JID's, lookup failures, etc) are kept separate between streams.
**/
+ (XMPPCapabilitiesCoreDataStorage *)sharedInstance;

/**
 * Initializes the core data storage instance, with the given database store filename.
 * It is recommended your filname use the "sqlite" file extension.
 * If you pass nil, the default value of "XMPPCapabilities.sqlite" is automatically used.
 * 
 * If you attempt to create an instance of this class with the same dbFileName as another existing instance,
 * this method will return nil.
 * 
 * It is highly recommended you use the sharedInstance above.
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
