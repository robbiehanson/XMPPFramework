#import "XMPPMessageCoreDataStorage.h"
#import "XMPPMessageCoreDataStorageObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface XMPPMessageCoreDataStorageTransaction (XMPPMUCLight)

/// Stores core XMPP properties for the received MUC Light message.
- (void)storeReceivedRoomLightMessage:(XMPPMessage *)message;

/// Registers outgoing stream event information for the chat message processed in the transaction.
- (void)registerSentRoomLightMessage;

@end

@interface XMPPMessageCoreDataStorageObject (XMPPMUCLight)

/**
 Returns YES for incoming messages where the MUC Light occupant associated with the message matches the stream JID.
 
 A single user may have several clients in the same MUC Light room. The messages broadcasted from "sibling" resources will appear as incoming;
 an application may use this method to detect such messages and treat them as if they were outgoing.
 */
- (BOOL)isMyIncomingRoomLightMessage;

@end
   
NS_ASSUME_NONNULL_END
