#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "XMPPCapabilities.h"
#import "XMPPCoreDataStorage.h"

/**
 * This class is an example implementation of XMPPCapabilitiesStorage using core data.
 * You are free to substitute your own storage class.
**/

@interface XMPPCapabilitiesCoreDataStorage : XMPPCoreDataStorage <XMPPCapabilitiesStorage>
{
	/* Inherited protected variables from XMPPCoreDataStorage
	
	NSString *databaseFileName;
	NSUInteger saveThreshold;
	
	dispatch_queue_t storageQueue;
	 
	*/
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


/* Inherited from XMPPCoreDataStorage
 * Please see the XMPPCoreDataStorage header file for extensive documentation.
 
- (id)initWithDatabaseFilename:(NSString *)databaseFileName storeOptions:(NSDictionary *)storeOptions;
- (id)initWithInMemoryStore;

@property (readonly) NSString *databaseFileName;
 
@property (readwrite) NSUInteger saveThreshold;

@property (readonly) NSManagedObjectModel *managedObjectModel;
@property (readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (readonly) NSManagedObjectContext *mainThreadManagedObjectContext;
 
*/

@end
