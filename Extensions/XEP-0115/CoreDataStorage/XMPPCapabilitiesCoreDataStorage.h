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
	
	NSFetchRequest *fr_resourceForJID;
	NSFetchRequest *fr_capsForHash_algorithm;
}

@end
