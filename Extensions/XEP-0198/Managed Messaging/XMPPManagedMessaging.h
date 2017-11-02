#import "XMPPModule.h"

NS_ASSUME_NONNULL_BEGIN

@class XMPPMessage;

/**
 A module working in tandem with @c XMPPStreamManagement to trace outgoing message stream acknowledgements.
 
 This module only monitors messages with @c elementID assigned. The rationale behind this is that any potential retransmissions
 of messages without IDs will cause deduplication issues on the receiving end.
 */
@interface XMPPManagedMessaging : XMPPModule

@end

/// A protocol defining @c XMPPManagedMessaging module delegate API.
@protocol XMPPManagedMessagingDelegate <NSObject>

@optional

/// Notifies the delegate that a message subject to monitoring has been sent in the stream.
- (void)xmppManagedMessaging:(XMPPManagedMessaging *)sender didBeginMonitoringOutgoingMessage:(XMPPMessage *)message;

/// Notifies the delegate that @c XMPPStreamManagement module has received server acknowledgement for sent messages with given IDs.
- (void)xmppManagedMessaging:(XMPPManagedMessaging *)sender didConfirmSentMessagesWithIDs:(NSArray<NSString *> *)messageIDs;

/// @brief Notifies the delegate that post-reauthentication message acknowledgement processing is finished.
/// At this point, no more acknowledgements for currently monitored messages are to be expected.
- (void)xmppManagedMessagingDidFinishProcessingPreviousStreamConfirmations:(XMPPManagedMessaging *)sender;

@end

NS_ASSUME_NONNULL_END
