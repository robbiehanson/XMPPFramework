#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "XMPP.h"
#import "XMPPRoom.h"
#import "XMPPRoomMessageCoreDataStorageObject.h"
#import "XMPPRoomOccupantCoreDataStorageObject.h"
#import "XMPPCoreDataStorage.h"


@interface XMPPRoomCoreDataStorage : XMPPCoreDataStorage <XMPPRoomStorage>

/**
 * Convenience method to get an instance with the default database name.
 * 
 * IMPORTANT:
 * You are NOT required to use the sharedInstance.
 * 
 * If your application makes extensive use of MUC, and you use a sharedInstance of this class,
 * then all of your MUC rooms share the same database store. You might get better performance if you create
 * multiple instances of this class instead (using different database filenames), as this way you can have
 * concurrent writes to multiple databases.
**/
+ (instancetype)sharedInstance;


/* Inherited from XMPPCoreDataStorage
 * Please see the XMPPCoreDataStorage header file for extensive documentation.
 
- (id)initWithDatabaseFilename:(NSString *)databaseFileName storeOptions:(NSDictionary *)storeOptions;
- (id)initWithInMemoryStore;

@property (readonly) NSString *databaseFileName;
 
@property (readwrite) NSUInteger saveThreshold;

@property (readonly) NSManagedObjectModel *managedObjectModel;
@property (readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;
 
*/

/**
 * You may choose to extend this class, and/or the message/occupant classes for customized functionality.
 * These properties allow for such customization.
 * 
 * You must set your desired entity names, if different from default, before you begin using the storage class.
**/
@property (strong, readwrite) NSString * messageEntityName;
@property (strong, readwrite) NSString * occupantEntityName;

/**
 * It is likely you don't want the message history to persist forever.
 * Doing so would allow the database to grow infinitely large over time.
 * 
 * The maxMessageAge property provides a way to specify how old a message can get
 * before it should get deleted from the database.
 * 
 * The deleteInterval specifies how often to sweep for old messages.
 * Since deleting is an expensive operation (disk io) it is done on a fixed interval.
 * 
 * You can optionally disable the maxMessageAge by setting it to zero (or a negative value).
 * If you disable the maxMessageAge then old messages are not deleted.
 * 
 * You can optionally disable the deleteInterval by setting it to zero (or a negative value).
 * 
 * The default maxAge is 7 days.
 * The default deleteInterval is 5 minutes.
**/
@property (assign, readwrite) NSTimeInterval maxMessageAge;
@property (assign, readwrite) NSTimeInterval deleteInterval;

/**
 * You may optionally prevent old message deletion for particular rooms.
**/
- (void)pauseOldMessageDeletionForRoom:(XMPPJID *)roomJID;
- (void)resumeOldMessageDeletionForRoom:(XMPPJID *)roomJID;

/**
 * Convenience method to get the message/occupant entity description.
 * 
 * @see messageEntityName
 * @see occupantEntityName
**/
- (NSEntityDescription *)messageEntity:(NSManagedObjectContext *)moc;
- (NSEntityDescription *)occupantEntity:(NSManagedObjectContext *)moc;

/**
 * Returns the timestamp of the most recent message stored in the database for the given room.
 * This may be used when requesting the message history from the server,
 * to prevent redownloading messages you already have.
 * 
 * @param roomJID    - The JID of the room (a bare JID)
 * 
 * @param xmppStream - This class can support multiple concurrent xmppStreams.
 *                     Optionally pass the xmppStream the room applies to.
 *                     If you're using this claass with a single xmppStream, you can pass nil.
 *
 * @param moc        - The managedObjectContext to use when doing the lookups.
 *                     If non-nil, this should match the thread you're currently using.
 *                     If nil, the operation is dispatch_sync'd onto the internal queue,
 *                     and uses the internal managedObjectContext.
 * 
 * The moc may optionally be nil strictly because this method does not return a NSManagedObject.
**/
- (NSDate *)mostRecentMessageTimestampForRoom:(XMPPJID *)roomJID
                                       stream:(XMPPStream *)xmppStream
                                    inContext:(NSManagedObjectContext *)moc;

/**
 * Returns the occupant for the given full jid.
 * 
 * @param jid        - The full jid of the room occupant (including resource).
 * 
 * @param xmppStream - This class can support multiple concurrent xmppStreams.
 *                     Optionally pass the xmppStream the room applies to.
 *                     If you're using this claass with a single xmppStream, you can pass nil.
 * 
 * @param moc        - The managedObjectContext to use when doing the lookups.
 *                     This must not be nil, and should match the thread you're currently using.
**/
- (XMPPRoomOccupantCoreDataStorageObject *)occupantForJID:(XMPPJID *)jid
                                                   stream:(XMPPStream *)xmppStream
                                                inContext:(NSManagedObjectContext *)moc;

@end
