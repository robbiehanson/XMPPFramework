#import "XMPPCoreDataStorage.h"

@class XMPPJID;
@class XMPPStream;

/**
 * The methods in this class are to be used ONLY by subclasses of XMPPCoreDataStorage.
**/

@interface XMPPCoreDataStorage (Protected)

#pragma mark Override Me

/**
 * If your subclass needs to do anything for init, it can do so easily by overriding this method.
 * All public init methods will invoke this method at the end of their implementation.
 * 
 * Important: If overriden you must invoke [super commonInit] at some point.
**/
- (void)commonInit;

/**
 * Override me, if needed, to provide customized behavior.
 * 
 * This method is queried to get the name of the ManagedObjectModel within a bundle.
 * It should return the name of the appropriate file (*.xdatamodel / *.mom / *.momd) sans file extension.
 * 
 * The default implementation returns the name of the subclass, stripping any suffix of "CoreDataStorage".
 * E.g., if your subclass was named "XMPPExtensionCoreDataStorage", then this method would return "XMPPExtension".
 * 
 * Note that a file extension should NOT be included.
**/
- (NSString *)managedObjectModelName;


/**
 * Override me, if needed, to provide customized behavior.
 *
 * This method is queried to get the bundle containing the ManagedObjectModel.
**/
- (NSBundle *)managedObjectModelBundle;

/**
 * Override me, if needed, to provide customized behavior.
 * 
 * This method is queried if the initWithDatabaseFileName:storeOptions: method is invoked with a nil parameter for databaseFileName.
 * The default implementation returns:
 * 
 * [NSString stringWithFormat:@"%@.sqlite", [self managedObjectModelName]];
 * 
 * You are encouraged to use the sqlite file extension.
**/
- (NSString *)defaultDatabaseFileName;


/**
 * Override me, if needed, to provide customized behavior.
 *
 * This method is queried if the initWithDatabaseFileName:storeOptions method is invoked with a nil parameter for storeOptions.
 * The default implementation returns the following:
 *
 * @{ NSMigratePersistentStoresAutomaticallyOption: @(YES),
 *    NSInferMappingModelAutomaticallyOption : @(YES) };
 **/
- (NSDictionary *)defaultStoreOptions;

/**
 * Override me, if needed, to provide customized behavior.
 * 
 * If you are using a database file with pure non-persistent data (e.g. for memory optimization purposes on iOS),
 * you may want to delete the database file if it already exists on disk.
 * 
 * If this instance was created via initWithDatabaseFilename, then the storePath parameter will be non-nil.
 * If this instance was created via initWithInMemoryStore, then the storePath parameter will be nil.
 * 
 * The default implementation does nothing.
**/
- (void)willCreatePersistentStoreWithPath:(NSString *)storePath options:(NSDictionary *)storeOptions;

/**
 * Override me, if needed, to completely customize the persistent store.
 * 
 * Adds the persistent store path to the persistent store coordinator.
 * Returns true if the persistent store is created.
 * 
 * If this instance was created via initWithDatabaseFilename, then the storePath parameter will be non-nil.
 * If this instance was created via initWithInMemoryStore, then the storePath parameter will be nil.
**/
- (BOOL)addPersistentStoreWithPath:(NSString *)storePath options:(NSDictionary *)storeOptions error:(NSError **)errorPtr;

/**
 * Override me, if needed, to provide customized behavior.
 * 
 * For example, if you are using the database for non-persistent data and the model changes, you may want
 * to delete the database file if it already exists on disk and a core data migration is not worthwhile.
 * 
 * If this instance was created via initWithDatabaseFilename, then the storePath parameter will be non-nil.
 * If this instance was created via initWithInMemoryStore, then the storePath parameter will be nil.
 * 
 * The default implementation simply writes to the XMPP error log.
**/
- (void)didNotAddPersistentStoreWithPath:(NSString *)storePath options:(NSDictionary *)storeOptions error:(NSError *)error;

/**
 * Override me, if needed, to provide customized behavior.
 * 
 * For example, you may want to perform cleanup of any non-persistent data before you start using the database.
 * 
 * The default implementation does nothing.
**/
- (void)didCreateManagedObjectContext;

/**
 * Override me if you need to do anything special just before changes are saved to disk.
 * 
 * This method will be invoked on the storageQueue.
 * The default implementation does nothing.
**/
- (void)willSaveManagedObjectContext;

/**
 * Override me if you need to do anything special after changes have been saved to disk.
 * 
 * This method will be invoked on the storageQueue.
 * The default implementation does nothing.
**/
- (void)didSaveManagedObjectContext;

/**
 * This method will be invoked on the main thread,
 * after the mainThreadManagedObjectContext has merged changes from another context.
 * 
 * This method may be useful if you have code dependent upon when changes the datastore hit the user interface.
 * For example, you want to play a sound when a message is received.
 * You could play the sound right away, from the background queue, but the timing may be slightly off because
 * the user interface won't update til the changes have been saved to disk,
 * and then propogated to the managedObjectContext of the main thread.
 * Alternatively you could set a flag, and then hook into this method
 * to play the sound at the exact moment the propogation hits the main thread.
 * 
 * The default implementation does nothing.
**/
- (void)mainThreadManagedObjectContextDidMergeChanges;

#pragma mark Setup

/**
 * This is the standard configure method used by xmpp extensions to configure a storage class.
 * 
 * Feel free to override this method if needed,
 * and just invoke super at some point to make sure everything is kosher at this level as well.
 * 
 * Note that the default implementation allows the storage class to be used by multiple xmpp streams.
 * If you design your storage class to be used by a single stream, then you should implement this method
 * to ensure that your class can only be configured by one parent.
 * If you do, again, don't forget to invoke super at some point.
**/
- (BOOL)configureWithParent:(id)aParent queue:(dispatch_queue_t)queue;

#pragma mark Stream JID caching

/**
 * This class provides a caching service for xmppStream.myJID to avoid constantly querying the xmppStream for it.
 * 
 * The motivation behind this is the fact that to query the xmppStream for its myJID
 * requires going through the xmppStream's internal dispatch queue. (A dispatch_sync).
 * It's not necessarily that this is an expensive operation,
 * but storage classes sometimes require this information for just about every operation they perform.
 * For a variable that changes infrequently, caching the value can reduce some overhead.
 * In addition, if we can stay out of xmppStream's internal dispatch queue,
 * we free it to perform more xmpp processing tasks.
 * 
 * If the xmppStream.myJID changes, the cache will automatically be updated.
 * 
 * If you store any variant of xmppStream.myJID (bare, full, domain, etc) in your database
 * you are strongly encouraged to use the caching service.
 * 
 * For example, say you're implementing a core data storage caching mechanism for Private XML Storage (XEP-0049).
 * The data you're caching is explictly tied to the stream's bare myJID. ([xmppStream.myJID bare])
 * You want your storage class to support multiple xmpp streams,
 * so you add a field to the database called streamBareJidStr (or whatever).
 * Given an xmppStream, you can use the built-in cache to quickly get the xmppStream.myJid property:
 * 
 * [self myJidForXMPPStream:stream]
 * 
 * This method will retrieve the myJID property of the given xmppStream the first time,
 * and then cache it for future lookups. The cache is automatically updated if the xmppStream.myJID ever changes.
**/
- (XMPPJID *)myJIDForXMPPStream:(XMPPStream *)stream;

/**
 * This method is invoked if the cached myJID changes for a particular xmpp stream.
 * 
 * This method works in correlation with the myJIDForXMPPStream method.
 * In other words, calling myJIDForXMPPStream will cache the value.
 * If that value later changes, this method is invoked.
 * 
 * So if the myJID of an xmpp stream changes, but there was no cached value for that xmpp stream,
 * then this method is never called. E.g. this method is only called for streams we're actually interested in.
 * 
 * You may wish to override this method if your storage class prefetches data related to the current user.
 * 
 * This method will be invoked on the storageQueue.
 * The default implementation does nothing.
**/
- (void)didChangeCachedMyJID:(XMPPJID *)cachedMyJID forXMPPStream:(XMPPStream *)stream;

#pragma mark Core Data

/**
 * The standard persistentStoreDirectory method.
**/
- (NSString *)persistentStoreDirectory;

/**
 * Provides access to the managedObjectContext.
 * 
 * Keep in mind that NSManagedObjectContext is NOT thread-safe.
 * So you can ONLY access this property from within the context of the storageQueue.
 * 
 * Important:
 * The primary purpose of this class is to optimize disk IO by buffering save operations to the managedObjectContext.
 * It does this using the methods outlined in the 'Performance Optimizations' section below.
 * If you manually save the managedObjectContext you are destroying these optimizations.
 * See the documentation for executeBlock & scheduleBlock below for proper usage surrounding the optimizations.
**/
@property (readonly) NSManagedObjectContext *managedObjectContext;

#pragma mark Performance Optimizations

/**
 * Queries the managedObjectContext to determine the number of unsaved managedObjects.
**/
- (NSUInteger)numberOfUnsavedChanges;

/**
 * You will not often need to manually call this method.
 * It is called automatically, at appropriate and optimized times, via the executeBlock and scheduleBlock methods.
 * 
 * The one exception to this is when you are inserting/deleting/updating a large number of objects in a loop.
 * It is recommended that you invoke save from within the loop.
 * E.g.:
 * 
 * NSUInteger unsavedCount = [self numberOfUnsavedChanges];
 * for (NSManagedObject *obj in fetchResults)
 * {
 *     [[self managedObjectContext] deleteObject:obj];
 *     
 *     if (++unsavedCount >= saveThreshold)
 *     {
 *         [self save];
 *         unsavedCount = 0;
 *     }
 * }
 * 
 * See also the documentation for executeBlock and scheduleBlock below.
**/
- (void)save; // Read the comments above !

/**
 * You will rarely need to manually call this method.
 * It is called automatically, at appropriate and optimized times, via the executeBlock and scheduleBlock methods.
 * 
 * This method makes informed decisions as to whether it should save the managedObjectContext changes to disk.
 * Since this disk IO is a slow process, it is better to buffer writes during high demand.
 * This method takes into account the number of pending requests waiting on the storage instance,
 * as well as the number of unsaved changes (which reside in NSManagedObjectContext's internal memory).
 * 
 * Please see the documentation for executeBlock and scheduleBlock below.
**/
- (void)maybeSave; // Read the comments above !

/**
 * This method synchronously invokes the given block (dispatch_sync) on the storageQueue.
 * 
 * Prior to dispatching the block it increments (atomically) the number of pending requests.
 * After the block has been executed, it decrements (atomically) the number of pending requests,
 * and then invokes the maybeSave method which implements the logic behind the optimized disk IO.
 * 
 * If you use the executeBlock and scheduleBlock methods for all your database operations,
 * you will automatically inherit optimized disk IO for free.
 * 
 * If you manually invoke [managedObjectContext save:] you are destroying the optimizations provided by this class.
 * 
 * The block handed to this method is automatically wrapped in a NSAutoreleasePool,
 * so there is no need to create these yourself as this method automatically handles it for you.
 * 
 * The architecture of this class purposefully puts the CoreDataStorage instance on a separate dispatch_queue
 * from the parent XmppExtension. Not only does this allow a single storage instance to service multiple extension
 * instances, but it provides the mechanism for the disk IO optimizations. The theory behind the optimizations
 * is to delay a save of the data (a slow operation) until the storage class is no longer being used. With xmpp
 * it is often the case that a burst of data causes a flurry of queries and/or updates for a storage class.
 * Thus the theory is to delay the slow save operation until later when the flurry has ended and the storage
 * class no longer has any pending requests.
 * 
 * This method is designed to be invoked from within the XmppExtension storage protocol methods.
 * In other words, it is expecting to be invoked from a dispatch_queue other than the storageQueue.
 * If you attempt to invoke this method from within the storageQueue, an exception is thrown.
 * Therefore care should be taken when designing your implementation.
 * The recommended procedure is as follows:
 * 
 * All of the methods that implement the XmppExtension storage protocol invoke either executeBlock or scheduleBlock.
 * However, none of these methods invoke each other (they are only to be invoked from the XmppExtension instance).
 * Instead, create internal utility methods that may be invoked.
 * 
 * For an example, see the XMPPRosterCoreDataStorage implementation's _userForJID:xmppStream: method.
**/
- (void)executeBlock:(dispatch_block_t)block;

/**
 * This method asynchronously invokes the given block (dispatch_async) on the storageQueue.
 * 
 * It works very similarly to the executeBlock method.
 * See the executeBlock method above for a full discussion.
**/
- (void)scheduleBlock:(dispatch_block_t)block;

/**
 * Sometimes you want to call a method before calling save on a Managed Object Context e.g. willSaveObject:
 *
 * addWillSaveManagedObjectContextBlock allows you to add a block of code to be called before saving a Managed Object Context,
 * without the overhead of having to call save at that moment.
**/
- (void)addWillSaveManagedObjectContextBlock:(void (^)(void))willSaveBlock;

/**
 * Sometimes you want to call a method after calling save on a Managed Object Context e.g. didSaveObject:
 *
 * addDidSaveManagedObjectContextBlock allows you to add a block of code to be after saving a Managed Object Context,
 * without the overhead of having to call save at that moment.
**/
- (void)addDidSaveManagedObjectContextBlock:(void (^)(void))didSaveBlock;

@end
