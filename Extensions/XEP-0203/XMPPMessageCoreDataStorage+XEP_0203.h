#import "XMPPMessageCoreDataStorage.h"
#import "XMPPMessageCoreDataStorageObject.h"
#import "XMPPMessageContextItemCoreDataStorageObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface XMPPMessageCoreDataStorageTransaction (XEP_0203)

/// @brief Registers XEP-0203 delayed delivery information for the received message.
/// @discussion It is assumed that the provided @c XMPPMessage contains at least a delayed delivery timestamp.
- (void)registerDelayedDeliveryForReceivedMessage:(XMPPMessage *)message;

@end

@interface XMPPMessageCoreDataStorageObject (XEP_0203)

/// Returns the timestamp when the message was originally sent.
- (nullable NSDate *)delayedDeliveryDate;

/// Returns the JID of the entity that originally sent/delayed the delivery of the message.
- (nullable XMPPJID *)delayedDeliveryFrom;

/// Returns the natural language description of the reason for the delay.
- (nullable NSString *)delayedDeliveryReasonDescription;

/// Associates delayed delivery information with the message.
- (void)setDelayedDeliveryDate:(NSDate *)delayedDeliveryDate
                          from:(nullable XMPPJID *)delayedDeliveryFrom
             reasonDescription:(nullable NSString *)delayedDeliveryReasonDescription;

@end

@interface XMPPMessageContextItemCoreDataStorageObject (XEP_0203)

/**
 Returns a predicate to be provided to @c requestByTimestampsWithPredicate:inAscendingOrder:fromManagedObjectContext:
 that limits the fetch results to only include the delayed delivery context timestamp for each message.
 
 It is possible to OR-combine this predicate with @c streamTimestampKindPredicate without getting duplicates
 as the result set of the latter will not include any messages with delayed delivery timestamps assigned.
 
 @see requestByTimestampsWithPredicate:inAscendingOrder:fromManagedObjectContext:
 @see streamTimestampKindPredicate
 */
+ (NSPredicate *)delayedDeliveryTimestampKindPredicate;

@end

NS_ASSUME_NONNULL_END
