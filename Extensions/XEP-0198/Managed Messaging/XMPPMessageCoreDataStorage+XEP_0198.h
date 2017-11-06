#import "XMPPMessageCoreDataStorage.h"
#import "XMPPMessageCoreDataStorageObject.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, XMPPManagedMessagingStatus) {
    /// The status of an untracked message.
    XMPPManagedMessagingStatusUnspecified,
    /// The status of a tracked outgoing message for which an acknowledgement has not been received yet.
    XMPPManagedMessagingStatusPendingAcknowledgement,
    /// The status of an outgoing message for which an acknowledgement has been received.
    XMPPManagedMessagingStatusAcknowledged,
    /// The status of a tracked outgoing message for which an acknowledgement has never been received.
    XMPPManagedMessagingStatusUnacknowledged
};

@interface XMPPMessageCoreDataStorage (XEP_0198)

/**
 Marks sent message objects with given element IDs as acknowledged by the stream's remote end.
 
 This method is intended to be invoked in response to @c XMPPManagedMessagingDelegate
 @c xmppManagedMessaging:didConfirmSentMessagesWithIDs: delegate callback.
 */
- (void)registerAcknowledgedManagedMessageIDs:(NSArray<NSString *> *)messageIDs;

/**
 Marks sent message objects that are still pending stream acknowledgement as never acknowledged.
 
 This method is intended to be invoked in response to @c XMPPManagedMessagingDelegate
 @c xmppManagedMessagingDidFinishProcessingPreviousStreamConfirmations: delegate callback.
 */
- (void)registerFailureForUnacknowledgedManagedMessages;

@end

@interface XMPPMessageCoreDataStorageTransaction (XEP_0198)

/// Marks the outgoing message associated with the given transaction as pending stream acknowledgement.
- (void)registerSentManagedMessage;

@end

@interface XMPPMessageCoreDataStorageObject (XEP_0198)

/// Returns the message object's stream acknowledgement status.
- (XMPPManagedMessagingStatus)managedMessagingStatus;

@end

NS_ASSUME_NONNULL_END
