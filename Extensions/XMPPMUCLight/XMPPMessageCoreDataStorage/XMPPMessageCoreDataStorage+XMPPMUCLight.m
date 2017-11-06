#import "XMPPMessageCoreDataStorage+XMPPMUCLight.h"
#import "XMPPMessageCoreDataStorageObject+Protected.h"
#import "XMPPMessage.h"

@implementation XMPPMessageCoreDataStorageTransaction (XMPPMUCLight)

- (void)storeReceivedRoomLightMessage:(XMPPMessage *)message
{
    [self scheduleStorageUpdateWithBlock:^(XMPPMessageCoreDataStorageObject * _Nonnull messageObject) {
        NSAssert(messageObject.direction == XMPPMessageDirectionIncoming, @"This action is only allowed for incoming message objects");
        
        if (![[self class] isEchoedRoomLightMessage:message inManagedObjectContext:messageObject.managedObjectContext]) {
            [messageObject registerIncomingMessageCore:message];
        } else {
            [messageObject.managedObjectContext deleteObject:messageObject];
        }
    }];
}

- (void)registerSentRoomLightMessage
{
    [self scheduleStorageUpdateWithBlock:^(XMPPMessageCoreDataStorageObject * _Nonnull messageObject) {
        NSAssert(messageObject.direction == XMPPMessageDirectionOutgoing, @"This action is only allowed for outgoing message objects");
        // No additional processing required
    }];
}

+ (BOOL)isEchoedRoomLightMessage:(XMPPMessage *)message inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    if (![message elementID]) {
        return NO;
    }
    
    XMPPMessageCoreDataStorageObject *sentMessageStorageObject = [XMPPMessageCoreDataStorageObject findWithUniqueStanzaID:[message elementID]
                                                                                                   inManagedObjectContext:managedObjectContext];
    return sentMessageStorageObject && sentMessageStorageObject.direction == XMPPMessageDirectionOutgoing;
}

@end

@implementation XMPPMessageCoreDataStorageObject (XMPPMUCLight)

- (BOOL)isMyIncomingRoomLightMessage
{
    if (self.type != XMPPMessageTypeGroupchat || self.direction != XMPPMessageDirectionIncoming) {
        return NO;
    }
    
    NSString *roomLightUserString = self.fromJID.resource;
    return roomLightUserString && [[XMPPJID jidWithString:roomLightUserString] isEqualToJID:[self streamJID] options:XMPPJIDCompareBare];
}

@end
