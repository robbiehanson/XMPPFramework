#import "XMPPRoomLightCoreDataStorage.h"
#import "XMPPCoreDataStorageProtected.h"

@interface XMPPRoomLightCoreDataStorage (Protected)

- (NSEntityDescription *)messageEntity:(NSManagedObjectContext *)moc;

- (void)insertMessage:(XMPPMessage *)message
             outgoing:(BOOL)isOutgoing
      remoteTimestamp:(NSDate *)remoteTimestamp
              forRoom:(XMPPRoomLight *)room
               stream:(XMPPStream *)xmppStream;

@end
