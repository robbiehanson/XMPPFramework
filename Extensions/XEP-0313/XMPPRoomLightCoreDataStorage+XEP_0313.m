#import "XMPPRoomLightCoreDataStorage+XEP_0313.h"
#import "XMPPRoomLightCoreDataStorageProtected.h"
#import "XMPPRoomMessage.h"

@interface XMPPMessage (XMPPRoomLightCoreDataStorage_XEP_0313)

- (NSDictionary<NSString *, NSString *> *)xElementStringsDictionary;

@end

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
    
    if (messageBody.length == 0) {
        // for non-body messages fall back to comparing <x> elements; this has to be done post-fetch as managed objects lack relevant attributes
        results = [results filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
            id<XMPPRoomMessage> evaluatedMessage = evaluatedObject;
            return [[[evaluatedMessage message] xElementStringsDictionary] isEqualToDictionary:[message xElementStringsDictionary]];
        }]];
    }
    
    return results && results.count == 0;
}

@end

@implementation XMPPMessage (XMPPRoomLightCoreDataStorage_XEP_0313)

- (NSDictionary<NSString *,NSString *> *)xElementStringsDictionary
{
    NSMutableDictionary *xElementStringsDictionary = [NSMutableDictionary dictionary];
    
    // Enumerating children due to a bug in Apple's NSXML implementation where -elementsForName: does not pick up namespace-qualified ones
    for (NSXMLNode *node in self.children) {
        if (node.kind == NSXMLElementKind && [node.name isEqualToString:@"x"]) {
            // Returning XML strings as equality test in KissXML is based on comparing node pointers
            xElementStringsDictionary[node.name] = node.XMLString;
        }
    }
    
    return xElementStringsDictionary;
}

@end
