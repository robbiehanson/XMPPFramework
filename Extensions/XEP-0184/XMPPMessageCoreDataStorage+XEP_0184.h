#import "XMPPMessageCoreDataStorage.h"
#import "XMPPMessageCoreDataStorageObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface XMPPMessageCoreDataStorageTransaction (XEP_0184)

/// @brief Stores core XMPP properties of a received XEP-0184 delivery receipt response message and associates it with the delivered message.
/// @discussion Although the XEP does not call for a mandatory delivered content message ID in the response message, this method assumes it is present.
- (void)storeReceivedDeliveryReceiptResponseMessage:(XMPPMessage *)message;

@end

@interface XMPPMessageCoreDataStorageObject (XEP_0184)

/// Returns the message object that contains a XEP-0184 delivery receipt response for the provided delivered message ID.
+ (nullable XMPPMessageCoreDataStorageObject *)findDeliveryReceiptResponseForMessageWithID:(NSString *)messageID
                                                                    inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
NS_SWIFT_NAME(findDeliveryReceiptResponse(forMessageWithID:in:));

/// Returns @c YES if the storage contains a XEP-0184 delivery receipt response message for the given message object.
- (BOOL)hasAssociatedDeliveryReceiptResponseMessage;

/// Returns the delivered message ID if the given object contains a XEP-0184 delivery receipt response message.
- (nullable NSString *)messageDeliveryReceiptResponseID;

@end

NS_ASSUME_NONNULL_END
