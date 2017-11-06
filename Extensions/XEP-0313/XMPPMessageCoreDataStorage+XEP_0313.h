#import "XMPPMessageCoreDataStorage.h"
#import "XMPPMessageCoreDataStorageObject.h"
#import "XMPPMessageContextItemCoreDataStorageObject.h"

NS_ASSUME_NONNULL_BEGIN

@class NSXMLElement;

typedef NS_ENUM(NSInteger, XMPPMessageArchiveQueryResultStorageMode) {
    /// A mode where only MAM metadata (archive ID and timestamp) are stored.
    XMPPMessageArchiveQueryResultStorageModeMetadataOnly,
    /// A mode where both MAM metadata (archive ID/timestamp) and the embedded payload is stored.
    XMPPMessageArchiveQueryResultStorageModeComplete
};

typedef NS_OPTIONS(NSInteger, XMPPMessageArchiveTimestampContextOptions) {
    /// A flag indicating that a MAM timestamp context fetch should include items belonging to incomplete query result set pages.
    XMPPMessageArchiveTimestampContextIncludingPartialResultPages = 1 << 0,
    /// A flag indicating that a MAM timestamp context fetch should include placeholder items for messages removed from the middle of an archive.
    XMPPMessageArchiveTimestampContextIncludingDeletedResultItems = 1 << 1,
};

@interface XMPPMessageCoreDataStorage (XEP_0313)

/**
 Marks message objects with given archive IDs as belonging to a complete result set page.
 
 MAM archive content is streamed to the client and then processed in the framework message by message.
 As in-order processing of the individual messages within a single page cannot be guaranteed, staging updates
 is the only way to prevent gaps in the local history in certain situations, e.g. when critical errors occur or an app crashes.
 Avoiding such gaps is important as they make incremental archive synchronization impossible.
 
 This method is intented to be invoked in response to MAM module's @c xmppMessageArchiveManagement:didFinishReceivingMessagesWithArchiveIDs:
 delegate callback. At that point all messages from the given page have already been processed locally.
 */
- (void)finalizeResultSetPageWithMessageArchiveIDs:(NSArray<NSString *> *)archiveIDs;

@end

@interface XMPPMessageCoreDataStorageTransaction (XEP_0313)

/**
 Stores MAM metadata along with an optional payload from a @c result element contained in a received query result message.
 
 This method is intended to be invoked in one of the two possible scenarios:
 
 1. The MAM module is not configured to submit payloads for further stream processing (@c submitsPayloadMessagesForStreamProcessing set to @c NO).
 
 In this case the module's delegate is expected to extract the query result item in the @c xmppMessageArchiveManagement:didReceiveMAMMessage: callback
 and invoke this method in @c XMPPMessageArchiveQueryResultStorageModeComplete mode, storing both the metadata and the actual payload.
 However, since the storage is not expected to be aware of any other XMPP extensions, only the basic RFC 3921/6121 properties can be stored
 for the provided payload.
 
 2. The module is configured to submit payloads for further stream processing (@c submitsPayloadMessagesForStreamProcessing set to @c YES).
 
 In this scenario it is assumed that other modules will handle payload storage the same way they do for "live" messages. The module's delegate
 is still responsible for registering MAM metadata though. To do so, it should invoke this method in @c XMPPMessageArchiveQueryResultStorageModeMetadataOnly
 mode on a transaction in the context of the @c xmppMessageArchiveManagement:didSubmitPayloadMessageFromQueryResult: callback, allowing MAM metadata
 to be linked to the message storage object processed by other modules.
 
 This method will abort the whole transaction if it is determined that the corresponding message is already stored locally.
 */
- (void)storeMessageArchiveQueryResultItem:(NSXMLElement *)resultItem inMode:(XMPPMessageArchiveQueryResultStorageMode)storageMode;

@end

@interface XMPPMessageCoreDataStorageObject (XEP_0313)

/// Returns the unique archive ID assigned by the server for message objects received via MAM.
- (nullable NSString *)messageArchiveID;

/// Returns the timestamp of when the message was originally sent (for an outgoing message) or received (for an incoming message)
/// for message objects received via MAM.
- (nullable NSDate *)messageArchiveDate;

/**
 Returns YES for own chat message objects received via MAM.
 
 Note that such messages will not appear in fetch results from @c requestByTimestampsWithPredicate:inAscendingOrder:fromManagedObjectContext:
 on @c XMPPMessageContextItemCoreDataStorageObject when using a predicate obtained from @c messageRemotePartyJIDPredicateWithValue:compareOptions:.
 This is because that predicate only expects outgoing direction messages to have the relevant @c toJID value.
 */
- (BOOL)isMyArchivedChatMessage;

@end

@interface XMPPMessageContextItemCoreDataStorageObject (XEP_0313)

/**
 Returns a predicate to be provided to @c requestByTimestampsWithPredicate:inAscendingOrder:fromManagedObjectContext:
 that limits the fetch results to only include the message archive context timestamp for each message.
 
 It is possible to OR-combine this predicate with @c streamTimestampKindPredicate without getting duplicates
 as the result set of the latter will not include any messages with message archive timestamps assigned.
 
 @see requestByTimestampsWithPredicate:inAscendingOrder:fromManagedObjectContext:
 @see streamTimestampKindPredicate
 */
+ (NSPredicate *)messageArchiveTimestampKindPredicateWithOptions:(XMPPMessageArchiveTimestampContextOptions)options;

@end

NS_ASSUME_NONNULL_END
