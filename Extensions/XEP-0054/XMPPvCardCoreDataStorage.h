//
//  XMPPvCardCoreDataStorage.h
//  XEP-0054 vCard-temp
//
//  Originally created by Eric Chamberlain on 3/18/11.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "XMPPvCardTempModule.h"


@interface XMPPvCardCoreDataStorage : NSObject <XMPPvCardTempModuleStorage>
{
	BOOL singleUsage;
	
	dispatch_queue_t storageQueue;
	
	NSManagedObjectModel *_managedObjectModel;
	NSPersistentStoreCoordinator *_persistentStoreCoordinator;
	NSManagedObjectContext *_managedObjectContext;
}

/**
 * Creates a vCard CoreDataStorage instance designed to be used by a single instance of XMPPvCardTempModule.
 * 
 * The storage instance will inherit its dispatch queue from its parent (the XMPPvCardTempModule instance).
**/
- (id)init;
- (id)initForSingleUsage;

/**
 * Creates a vCard CoreDataStorage instance that may be used by multiple instances of XMPPvCardTempModule.
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
