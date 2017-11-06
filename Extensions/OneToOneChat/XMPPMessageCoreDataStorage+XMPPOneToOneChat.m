#import "XMPPMessageCoreDataStorage+XMPPOneToOneChat.h"
#import "XMPPMessageCoreDataStorageObject+Protected.h"

@implementation XMPPMessageCoreDataStorageTransaction (XMPPOneToOneChat)

- (void)storeReceivedChatMessage:(XMPPMessage *)message
{
    [self scheduleStorageUpdateWithBlock:^(XMPPMessageCoreDataStorageObject * _Nonnull messageObject) {
        NSAssert(messageObject.direction == XMPPMessageDirectionIncoming, @"This action is only allowed for incoming message objects");
        [messageObject registerIncomingMessageCore:message];
    }];
}

- (void)registerSentChatMessage
{
    [self scheduleStorageUpdateWithBlock:^(XMPPMessageCoreDataStorageObject * _Nonnull messageObject) {
        NSAssert(messageObject.direction == XMPPMessageDirectionOutgoing, @"This action is only allowed for outgoing message objects");
        // No additional processing required
    }];
}

@end
