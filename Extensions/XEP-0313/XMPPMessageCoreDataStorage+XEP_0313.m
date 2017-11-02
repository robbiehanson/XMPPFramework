#import "XMPPMessageCoreDataStorage+XEP_0313.h"
#import "XMPPCoreDataStorageProtected.h"
#import "XMPPMessageCoreDataStorageObject+Protected.h"
#import "XMPPMessageCoreDataStorageObject+ContextHelpers.h"
#import "NSManagedObject+XMPPCoreDataStorage.h"
#import "XMPPMessage.h"
#import "NSXMLElement+XMPP.h"
#import "NSXMLElement+XEP_0297.h"

static XMPPMessageContextStringItemTag const XMPPMessageContextMAMArchiveIDTag = @"XMPPMessageContextMAMArchiveID";
static XMPPMessageContextTimestampItemTag const XMPPMessageContextMAMPartialResultPageTimestampTag = @"XMPPMessageContextMAMPartialResultPageTimestamp";
static XMPPMessageContextTimestampItemTag const XMPPMessageContextMAMCompleteResultPageTimestampTag = @"XMPPMessageContextMAMCompleteResultPageTimestamp";
static XMPPMessageContextTimestampItemTag const XMPPMessageContextMAMDeletedResultItemTimestampTag = @"XMPPMessageContextMAMDeletedResultItemTimestamp";

@implementation XMPPMessageCoreDataStorage (XEP_0313)

- (void)finalizeResultSetPageWithMessageArchiveIDs:(NSArray<NSString *> *)archiveIDs
{
    if (archiveIDs.count == 0) {
        return;
    }
    
    [self scheduleBlock:^{
        NSFetchRequest *finalizedArchiveIDsFetchRequest =
        [XMPPMessageContextStringItemCoreDataStorageObject xmpp_fetchRequestInManagedObjectContext:self.managedObjectContext];
        
        NSPredicate *archiveIDTagPredicate = [XMPPMessageContextStringItemCoreDataStorageObject tagPredicateWithValue:XMPPMessageContextMAMArchiveIDTag];
        NSMutableArray *archiveIDSubpredicates = [[NSMutableArray alloc] init];
        for (NSString *archiveID in archiveIDs) {
            [archiveIDSubpredicates addObject:[XMPPMessageContextStringItemCoreDataStorageObject stringPredicateWithValue:archiveID]];
        }
        finalizedArchiveIDsFetchRequest.predicate =
        [NSCompoundPredicate andPredicateWithSubpredicates:@[[NSCompoundPredicate orPredicateWithSubpredicates:archiveIDSubpredicates],
                                                             archiveIDTagPredicate]];
        
        NSArray *finalizedArchiveIDContextItems = [self.managedObjectContext xmpp_executeForcedSuccessFetchRequest:finalizedArchiveIDsFetchRequest];
        for (XMPPMessageContextStringItemCoreDataStorageObject *archiveIDContextItem in finalizedArchiveIDContextItems) {
            XMPPMessageContextCoreDataStorageObject *partialResultContext =
            [archiveIDContextItem.message lookupInContextWithBlock:^id _Nullable(XMPPMessageContextCoreDataStorageObject * _Nonnull contextElement) {
                return [contextElement timestampItemValueForTag:XMPPMessageContextMAMPartialResultPageTimestampTag] ? contextElement : nil;
            }];
            
            if (!partialResultContext) {
                continue;
            }
         
            NSDate *partialResultTimestamp = [partialResultContext timestampItemValueForTag:XMPPMessageContextMAMPartialResultPageTimestampTag];
            [partialResultContext removeTimestampItemsWithTag:XMPPMessageContextMAMPartialResultPageTimestampTag];
            [partialResultContext appendTimestampItemWithTag:XMPPMessageContextMAMCompleteResultPageTimestampTag value:partialResultTimestamp];
        }
    }];
}

@end

@implementation XMPPMessageCoreDataStorageTransaction (XEP_0313)

- (void)storeMessageArchiveQueryResultItem:(NSXMLElement *)resultItem inMode:(XMPPMessageArchiveQueryResultStorageMode)storageMode
{
    [self scheduleStorageUpdateWithBlock:^(XMPPMessageCoreDataStorageObject * _Nonnull messageObject) {
        NSAssert(messageObject.direction == XMPPMessageDirectionIncoming, @"This action is only allowed for incoming message objects");
        
        if ([[self class] isMessageArchiveQueryResultItem:resultItem alreadyStoredInManagedObjectContext:messageObject.managedObjectContext]) {
            [messageObject.managedObjectContext deleteObject:messageObject];
            return;
        }
        
        NSString *resultItemMessageID = [[resultItem forwardedMessage] elementID];
        if (resultItemMessageID
            && [XMPPMessageCoreDataStorageObject findWithUniqueStanzaID:resultItemMessageID inManagedObjectContext:messageObject.managedObjectContext])
        {
            [messageObject.managedObjectContext deleteObject:messageObject];
            return;
        }
        
        [messageObject retireStreamTimestamp];
        
        XMPPMessageContextCoreDataStorageObject *messageArchiveContext = [messageObject appendContextElement];
        [messageArchiveContext appendStringItemWithTag:XMPPMessageContextMAMArchiveIDTag value:[resultItem attributeStringValueForName:@"id"]];
        
        XMPPMessageContextTimestampItemTag timestampTag =
        [resultItem forwardedMessage] ? XMPPMessageContextMAMPartialResultPageTimestampTag : XMPPMessageContextMAMDeletedResultItemTimestampTag;
        [messageArchiveContext appendTimestampItemWithTag:timestampTag value:[resultItem forwardedStanzaDelayedDeliveryDate]];
        
        if (storageMode == XMPPMessageArchiveQueryResultStorageModeComplete && [resultItem forwardedMessage]) {
            [messageObject registerIncomingMessageCore:[resultItem forwardedMessage]];
        }
    }];
}

+ (BOOL)isMessageArchiveQueryResultItem:(NSXMLElement *)resultItem alreadyStoredInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSFetchRequest *existingArchiveIDFetchRequest =
    [XMPPMessageContextStringItemCoreDataStorageObject xmpp_fetchRequestInManagedObjectContext:managedObjectContext];
    
    NSArray *predicates = @[[XMPPMessageContextStringItemCoreDataStorageObject stringPredicateWithValue:[resultItem attributeStringValueForName:@"id"]],
                            [XMPPMessageContextStringItemCoreDataStorageObject tagPredicateWithValue:XMPPMessageContextMAMArchiveIDTag]];
    existingArchiveIDFetchRequest.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:predicates];
    
    NSArray<XMPPMessageContextStringItemCoreDataStorageObject *> *existingArchiveIDResult =
    [managedObjectContext xmpp_executeForcedSuccessFetchRequest:existingArchiveIDFetchRequest];
    if (existingArchiveIDResult.count != 0) {
        NSAssert(existingArchiveIDResult.count == 1, @"Expected a single message matching the given archive ID");
        NSAssert([[existingArchiveIDResult.firstObject.message messageArchiveDate] isEqualToDate:[resultItem forwardedStanzaDelayedDeliveryDate]],
                 @"The timestamp on an existing message does not match");
        return YES;
    } else {
        return NO;
    }
}

@end

@implementation XMPPMessageCoreDataStorageObject (XEP_0313)

- (NSString *)messageArchiveID
{
    return [self lookupInContextWithBlock:^id _Nullable(XMPPMessageContextCoreDataStorageObject * _Nonnull contextElement) {
        return [contextElement stringItemValueForTag:XMPPMessageContextMAMArchiveIDTag];
    }];
}

- (NSDate *)messageArchiveDate
{
    NSArray *archiveTimestampTags = @[XMPPMessageContextMAMPartialResultPageTimestampTag,
                                      XMPPMessageContextMAMCompleteResultPageTimestampTag,
                                      XMPPMessageContextMAMDeletedResultItemTimestampTag];
    
    for (XMPPMessageContextTimestampItemTag archiveTimestampTag in archiveTimestampTags) {
        NSDate *archiveTimestamp = [self lookupInContextWithBlock:^id _Nullable(XMPPMessageContextCoreDataStorageObject * _Nonnull contextElement) {
            return [contextElement timestampItemValueForTag:archiveTimestampTag];
        }];
        
        if (archiveTimestamp) {
            return archiveTimestamp;
        }
    }
    
    return nil;
}

- (BOOL)isMyArchivedChatMessage
{
    return self.type == XMPPMessageTypeChat && [self messageArchiveID] && [self.fromJID isEqualToJID:[self streamJID] options:XMPPJIDCompareBare];
}

@end

@implementation XMPPMessageContextItemCoreDataStorageObject (XEP_0313)

+ (NSPredicate *)messageArchiveTimestampKindPredicateWithOptions:(XMPPMessageArchiveTimestampContextOptions)options
{
    NSMutableArray *subpredicates = [[NSMutableArray alloc] init];
    [subpredicates addObject:[XMPPMessageContextStringItemCoreDataStorageObject tagPredicateWithValue:XMPPMessageContextMAMCompleteResultPageTimestampTag]];
    
    if (options & XMPPMessageArchiveTimestampContextIncludingPartialResultPages) {
        [subpredicates addObject:[XMPPMessageContextStringItemCoreDataStorageObject tagPredicateWithValue:XMPPMessageContextMAMPartialResultPageTimestampTag]];
    }
    
    if (options & XMPPMessageArchiveTimestampContextIncludingDeletedResultItems) {
        [subpredicates addObject:[XMPPMessageContextStringItemCoreDataStorageObject tagPredicateWithValue:XMPPMessageContextMAMDeletedResultItemTimestampTag]];
    }
    
    return [NSCompoundPredicate orPredicateWithSubpredicates:subpredicates];
}

@end
