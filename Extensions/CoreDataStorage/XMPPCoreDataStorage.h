#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

/**
 * This class provides an optional base class that may be used to implement
 * a CoreDataStorage class for an xmpp extension (or perhaps any core data storage class).
 * 
 * It operates on its own dispatch queue which allows it to easily provide storage for multiple extension instance.
 * More importantly, it smartly buffers its save operations to maximize performance!
 * 
 * It does this using two techniques:
 * 
 * First, it monitors the number of pending requests.
 * When a operation is requested of the class, it increments an atomic variable, and schedules the request.
 * After the request has been processed, it decrements the atomic variable.
 * At this point it knows if there are other pending requests,
 * and it uses the information to decide if it should save now,
 * or postpone the save operation until the pending requests have been executed.
 * 
 * Second, it monitors the number of unsaved changes.
 * Since NSManagedObjectContext retains any changed objects until they are saved to disk
 * it is an important memory management concern to keep the number of changed objects within a healthy range.
 * This class uses a configurable saveThreshold to save at appropriate times.
 * 
 * This class also offers several useful features such as
 * preventing multiple instances from using the same database file (conflict)
 * and caching of xmppStream.myJID to improve performance.
 * 
 * For more information on how to extend this class,
 * please see the XMPPCoreDataStorageProtected.h header file.
 * 
 * The framework comes with several classes that extend this base class such as:
 * - XMPPRosterCoreDataStorage       (Extensions/Roster)
 * - XMPPCapabilitiesCoreDataStorage (Extensions/XEP-0115)
 * - XMPPvCardCoreDataStorage        (Extensions/XEP-0054)
 * 
 * Feel free to skim over these as reference implementations.
**/

@interface XMPPCoreDataStorage : NSObject {
@private
	
	NSMutableDictionary *myJidCache;
	
	int32_t pendingRequests;
	
	NSManagedObjectModel *managedObjectModel;
	NSPersistentStoreCoordinator *persistentStoreCoordinator;
	NSManagedObjectContext *managedObjectContext;
	
@protected
	
	NSString *databaseFileName;
	NSUInteger saveThreshold;
	
	dispatch_queue_t storageQueue;
}

/**
 * Initializes a core data storage instance, backed by SQLite, with the given database store filename.
 * It is recommended your database filname use the "sqlite" file extension (e.g. "XMPPRoster.sqlite").
 * If you pass nil, a default database filename is automatically used.
 * This default is derived from the classname,
 * meaning subclasses will get a default database filename derived from the subclass classname.
 * 
 * If you attempt to create an instance of this class with the same databaseFileName as another existing instance,
 * this method will return nil.
**/
- (id)initWithDatabaseFilename:(NSString *)databaseFileName;

/**
 * Initializes a core data storage instance, backed by an in-memory store.
**/
- (id)initWithInMemoryStore;

/**
 * Readonly access to the databaseFileName used during initialization.
 * If nil was passed to the init method, returns the actual databaseFileName being used (the default filename).
**/
@property (readonly) NSString *databaseFileName;

/**
 * The saveThreshold specifies the maximum number of unsaved changes to NSManagedObjects before a save is triggered.
 * 
 * Since NSManagedObjectContext retains any changed objects until they are saved to disk
 * it is an important memory management concern to keep the number of changed objects within a healthy range.
**/
@property (readwrite) NSUInteger saveThreshold;

/**
 * Provides access the the thread-safe components of the CoreData stack.
 * 
 * Please note:
 * The managedObjectContext is private to the storageQueue.
 * You must create and use your own managedObjectContext.
 *  
 * If you think you can simply add a property for the private managedObjectContext,
 * then you need to go read the documentation for core data,
 * specifically the section entitled "Concurrency with Core Data".
**/
@property (readonly) NSManagedObjectModel *managedObjectModel;
@property (readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@end
