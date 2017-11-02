#import "XMPPMessageCoreDataStorage.h"

NS_ASSUME_NONNULL_BEGIN

@class XMPPMessage;

@interface XMPPMessageCoreDataStorageTransaction (XMPPOneToOneChat)

/// Stores core XMPP properties for the received chat message.
- (void)storeReceivedChatMessage:(XMPPMessage *)message;

/// Registers outgoing stream event information for the chat message processed in the transaction.
- (void)registerSentChatMessage;

@end

NS_ASSUME_NONNULL_END
