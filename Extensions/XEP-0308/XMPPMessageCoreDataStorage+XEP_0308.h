#import "XMPPMessageCoreDataStorage.h"
#import "XMPPMessageCoreDataStorageObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface XMPPMessageCoreDataStorageTransaction (XEP_0308)

/// @brief Registers a reference to the original message that is being corrected by the provided XEP-0308 message.
/// @discussion It is assumed that the provided message contains a XEP-0308 element referring the original message.
- (void)registerOriginalMessageIDForReceivedCorrectedMessage:(XMPPMessage *)message;

@end

@interface XMPPMessageCoreDataStorageObject (XEP_0308)

/// @brief Returns the message object that contains a XEP-0308 correction of a message with the provided element ID.
/// @see findCorrectionForMessageWithID:inManagedObjectContext:
+ (nullable XMPPMessageCoreDataStorageObject *)findCorrectionForMessageWithID:(NSString *)originalMessageID
                                                       inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
NS_SWIFT_NAME(findCorrection(forMessageWithID:in:));

/**
 Returns YES if the storage contains a XEP-0308 correction of the given message object.
 
 A message object representing the corrected message will not be included in @c XMPPMessageContextItemCoreDataStorageObject
 timestamp context fetch results. Instead, an application is expected to check for a potential correction message presence
 using this method and, if needed, look up the correction using @c findCorrectionForMessageWithID:inManagedObjectContext: .
 
 @see findCorrectionForMessageWithID:inManagedObjectContext:
 */
- (BOOL)hasAssociatedCorrectionMessage;

/// Returns the ID of the corrected message if the given object represents a XEP-0308 message correction.
- (nullable NSString *)messageCorrectionID;

/// @brief Marks the represented message as a XEP-0308 correction of the message with the provided element ID.
/// @discussion This method can only be invoked on an object representing an outgoing message.
- (void)assignMessageCorrectionID:(NSString *)messageCorrectionID;

@end

NS_ASSUME_NONNULL_END
