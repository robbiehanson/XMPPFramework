#import "XMPPRoomLightCoreDataStorage.h"

NS_ASSUME_NONNULL_BEGIN
@interface XMPPRoomLightCoreDataStorage (XEP_0313)

/**
 A helper method to use when synchronizing with a remote message store.
 - Infers whether the message is incoming or outgoing
 - Will not store a message it considers a duplicate of another message stored earlier
 */
- (void)importRemoteArchiveMessage:(XMPPMessage *)message
                     withTimestamp:(nullable NSDate *)archiveTimestamp
                            inRoom:(XMPPRoomLight *)room
                        fromStream:(XMPPStream *)stream;

@end
NS_ASSUME_NONNULL_END
