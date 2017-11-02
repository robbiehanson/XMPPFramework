#import <CoreData/CoreData.h>
#import "XMPPJID.h"

NS_ASSUME_NONNULL_BEGIN

@class XMPPMessageCoreDataStorageObject;

typedef NS_ENUM(int16_t, XMPPMessageDirection);
typedef NS_ENUM(int16_t, XMPPMessageType);

typedef NS_ENUM(NSInteger, XMPPMessageContentCompareOperator) {
    /// Content is equal the search string.
    XMPPMessageContentCompareOperatorEquals,
    /// Content begins with the search string.
    XMPPMessageContentCompareOperatorBeginsWith,
    /// Content contains the search string.
    XMPPMessageContentCompareOperatorContains,
    /// Content ends with the search string.
    XMPPMessageContentCompareOperatorEndsWith,
    /// Content is equal to the search string and the search string can contain wildcard characters.
    XMPPMessageContentCompareOperatorLike,
    /// Content matches the the search string interpreted as a regular expression.
    XMPPMessageContentCompareOperatorMatches
};

typedef NS_OPTIONS(NSInteger, XMPPMessageContentCompareOptions) {
    /// Content comparison is case-insensitive.
    XMPPMessageContentCompareCaseInsensitive = 1 << 0,
    /// Content comparison is diacritic-insensitive.
    XMPPMessageContentCompareDiacriticInsensitive = 1 << 1
};

/**
 A storage object representing a module-provided value assigned to a stored message.
 
 @see XMPPMessageCoreDataStorageObject
 @see XMPPMessageContextCoreDataStorageObject
 */
@interface XMPPMessageContextItemCoreDataStorageObject : NSManagedObject

@end

@interface XMPPMessageContextItemCoreDataStorageObject (XMPPMessageCoreDataStorageFetch)

/**
 Returns a fetch request for timestamp context values with associated messages.
 
 A common application use case involves fetching temporally ordered messages. In terms of the message storage Core Data model,
 this translates to fetching timestamp context values with specific predicates and then looking up the message objects they are attached to.
 
 The modules that assign custom timestamp context values will also provide appropriate predicates to be used with this method.
 It is application's responsibility to avoid fetches with duplicate messages when composing predicates coming from multiple modules.
 */
+ (NSFetchRequest<XMPPMessageContextItemCoreDataStorageObject *> *)requestByTimestampsWithPredicate:(NSPredicate *)predicate
                                                                                   inAscendingOrder:(BOOL)isInAscendingOrder
                                                                           fromManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 Returns a predicate to be provided to @c requestByTimestampsWithPredicate:inAscendingOrder:fromManagedObjectContext:
 that limits the fetch results to only include the single most relevant stream context timestamp per message.
 
 @see requestByTimestampsWithPredicate:inAscendingOrder:fromManagedObjectContext:
 */
+ (NSPredicate *)streamTimestampKindPredicate;

/**
 Returns a predicate to be provided to @c requestByTimestampsWithPredicate:inAscendingOrder:fromManagedObjectContext:
 that limits the fetch results to only include timestamp values from the given range.
 
 In order to request an open range, provide a nil value for the respective boundary.
 
 @see requestByTimestampsWithPredicate:inAscendingOrder:fromManagedObjectContext:
 */
+ (NSPredicate *)timestampRangePredicateWithStartValue:(nullable NSDate *)startValue endValue:(nullable NSDate *)endValue;

/**
 Returns a predicate to be provided to @c requestByTimestampsWithPredicate:inAscendingOrder:fromManagedObjectContext:
 that limits the fetch results to only include timestamp values for messages with the given @c fromJID value.
 
 @see requestByTimestampsWithPredicate:inAscendingOrder:fromManagedObjectContext:
 */
+ (NSPredicate *)messageFromJIDPredicateWithValue:(XMPPJID *)value compareOptions:(XMPPJIDCompareOptions)compareOptions;

/**
 Returns a predicate to be provided to @c requestByTimestampsWithPredicate:inAscendingOrder:fromManagedObjectContext:
 that limits the fetch results to only include timestamp values for messages with the given @c toJID value.
 
 @see requestByTimestampsWithPredicate:inAscendingOrder:fromManagedObjectContext:
 */
+ (NSPredicate *)messageToJIDPredicateWithValue:(XMPPJID *)value compareOptions:(XMPPJIDCompareOptions)compareOptions;

/**
 Returns a predicate to be provided to @c requestByTimestampsWithPredicate:inAscendingOrder:fromManagedObjectContext:
 that limits the fetch results to only include timestamp values for messages exchanged with an entity with the given JID value.
 
 The relevant messages in this case are the outgoing ones with a matching @c toJID value and incoming ones with a matching @c fromJID value.
 
 @see requestByTimestampsWithPredicate:inAscendingOrder:fromManagedObjectContext:
 */
+ (NSPredicate *)messageRemotePartyJIDPredicateWithValue:(XMPPJID *)value compareOptions:(XMPPJIDCompareOptions)compareOptions;

/**
 Returns a predicate to be provided to @c requestByTimestampsWithPredicate:inAscendingOrder:fromManagedObjectContext:
 that limits the fetch results to only include timestamp values for messages with specific body content.
 
 @see requestByTimestampsWithPredicate:inAscendingOrder:fromManagedObjectContext:
 */
+ (NSPredicate *)messageBodyPredicateWithValue:(NSString *)value
                               compareOperator:(XMPPMessageContentCompareOperator)compareOperator
                                       options:(XMPPMessageContentCompareOptions)options;

/**
 Returns a predicate to be provided to @c requestByTimestampsWithPredicate:inAscendingOrder:fromManagedObjectContext:
 that limits the fetch results to only include timestamp values for messages with specific subject content.
 
 @see requestByTimestampsWithPredicate:inAscendingOrder:fromManagedObjectContext:
 */
+ (NSPredicate *)messageSubjectPredicateWithValue:(NSString *)value
                                  compareOperator:(XMPPMessageContentCompareOperator)compareOperator
                                          options:(XMPPMessageContentCompareOptions)options;

/**
 Returns a predicate to be provided to @c requestByTimestampsWithPredicate:inAscendingOrder:fromManagedObjectContext:
 that limits the fetch results to only include timestamp values for messages from the given thread.
 
 @see requestByTimestampsWithPredicate:inAscendingOrder:fromManagedObjectContext:
 */
+ (NSPredicate *)messageThreadPredicateWithValue:(NSString *)value;

/**
 Returns a predicate to be provided to @c requestByTimestampsWithPredicate:inAscendingOrder:fromManagedObjectContext:
 that limits the fetch results to only include timestamp values for messages with the specified direction.
 
 @see requestByTimestampsWithPredicate:inAscendingOrder:fromManagedObjectContext:
 */
+ (NSPredicate *)messageDirectionPredicateWithValue:(XMPPMessageDirection)value;

/**
 Returns a predicate to be provided to @c requestByTimestampsWithPredicate:inAscendingOrder:fromManagedObjectContext:
 that limits the fetch results to only include timestamp values for messages of the specified type.
 
 @see requestByTimestampsWithPredicate:inAscendingOrder:fromManagedObjectContext:
 */
+ (NSPredicate *)messageTypePredicateWithValue:(XMPPMessageType)value;

/// Returns the message the context item is associated with.
- (XMPPMessageCoreDataStorageObject *)message;

@end

NS_ASSUME_NONNULL_END
