#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "XMPPCapabilities.h"

/**
 * This class is an example implementation of XMPPCapabilitiesStorage using core data.
 * You are free to substitute your own storage class.
**/

@interface XMPPCapabilitiesCoreDataStorage : NSObject <XMPPCapabilitiesStorage>
{
	BOOL singleUsage;
	
	dispatch_queue_t storageQueue;
	
	NSManagedObjectModel *managedObjectModel;
	NSPersistentStoreCoordinator *persistentStoreCoordinator;
	NSManagedObjectContext *managedObjectContext;
}

/**
 * Creates a CoreDataStorage instance designed to be used by a single instance of XMPPCapabilities.
 * 
 * The storage instance will inherit its dispatch queue from its parent (the XMPPCapabilities instance).
**/
- (id)init;
- (id)initForSingleUsage;

/**
 * Creates a CoreDataStorage instance that may be used by multiple instances of XMPPCapabilities.
 * This may be useful if your application creates multiple XMPPStream connections.
 * 
 * The storage instance will operate on its own dispatch queue, which may optionally be provided.
**/
- (id)initForMultipleUsage;
- (id)initForMultipleUsageWithDispatchQueue:(dispatch_queue_t)queue;


@property (readonly) NSManagedObjectModel *managedObjectModel;
@property (readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;

// The managedObjectContext is private to the storageQueue.
// You must create and use your own managedObjectContext.
// 
// If you think you can simply add a property for the private managedObjectContext,
// then you need to go read the documentation for core data,
// specifically the section entitled "Concurrency with Core Data".

@end
