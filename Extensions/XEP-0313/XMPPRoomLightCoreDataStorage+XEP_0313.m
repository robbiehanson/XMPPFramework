#import "XMPPRoomLightCoreDataStorage+XEP_0313.h"
#import "XMPPRoomLightCoreDataStorageProtected.h"

@implementation XMPPRoomLightCoreDataStorage (XEP_0313)

- (void)importRemoteArchiveMessage:(XMPPMessage *)message withTimestamp:(NSDate *)archiveTimestamp inRoom:(XMPPRoomLight *)room fromStream:(XMPPStream *)stream
{
    XMPPJID *sender = [XMPPJID jidWithString:[message from].resource];
    XMPPJID *me = [self myJIDForXMPPStream:stream];
    BOOL isOutgoing = [sender isEqualToJID:me options:XMPPJIDCompareBare];
    
    [self scheduleBlock:^{
        if ([self isMessageUnique:message withRemoteTimestamp:archiveTimestamp inRoom:room]) {
            [self insertMessage:message outgoing:isOutgoing remoteTimestamp:archiveTimestamp forRoom:room stream:stream];
        }
    }];
}

- (BOOL)isMessageUnique:(XMPPMessage *)message withRemoteTimestamp:(NSDate *)remoteTimestamp inRoom:(XMPPRoomLight *)room
{
    NSManagedObjectContext *moc = [self managedObjectContext];
    NSEntityDescription *messageEntity = [self messageEntity:moc];
    
    NSString *messageBody = [[message elementForName:@"body"] stringValue];
    
    NSString *senderFullJID = [[message from] full];
    
    NSDate *minLocalTimestamp = [remoteTimestamp dateByAddingTimeInterval:-60];
    NSDate *maxLocalTimestamp = [remoteTimestamp dateByAddingTimeInterval: 60];
    
    NSPredicate *contentPredicate = [NSPredicate predicateWithFormat:@"body = %@", messageBody];
    NSPredicate *locationPredicate = [NSPredicate predicateWithFormat:@"jidStr = %@", senderFullJID];
    NSPredicate *preciseTimestampPredicate = [NSPredicate predicateWithFormat:@"remoteTimestamp = %@", remoteTimestamp];
    NSPredicate *approximateTimestampPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[[NSPredicate predicateWithFormat:@"remoteTimestamp = nil"],
                                                                                                      [NSPredicate predicateWithFormat:@"localTimestamp BETWEEN {%@, %@}", minLocalTimestamp, maxLocalTimestamp]]];
    NSPredicate *timestampPredicate = [NSCompoundPredicate orPredicateWithSubpredicates:@[preciseTimestampPredicate, approximateTimestampPredicate]];
    NSPredicate *predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[contentPredicate, locationPredicate, timestampPredicate]];
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.entity = messageEntity;
    fetchRequest.predicate = predicate;
    fetchRequest.fetchLimit = 1;
    
    NSArray *results = [moc executeFetchRequest:fetchRequest error:NULL];
    
    return results && results.count == 0;
}

@end
