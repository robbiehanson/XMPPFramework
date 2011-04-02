#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "XMPPCapabilities.h"

/**
 * This class is an example implementation of XMPPCapabilitiesStorage using core data.
 * You are free to substitute your own storage class.
**/

@interface XMPPCapabilitiesCoreDataStorage : NSObject <XMPPCapabilitiesStorage>
{
	XMPPCapabilities *parent;
	dispatch_queue_t storageQueue;
	
	NSManagedObjectModel *managedObjectModel;
	NSPersistentStoreCoordinator *persistentStoreCoordinator;
	NSManagedObjectContext *managedObjectContext;
}

@property (readonly) NSManagedObjectModel *managedObjectModel;
@property (readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;

// The managedObjectContext is private to the storageQueue.
// You must create and use your own managedObjectContext.
// 
// If you think you can simply add a property for the private managedObjectContext,
// then you need to go read the documentation for core data,
// specifically the section entitled "Concurrency with Core Data".

@end
