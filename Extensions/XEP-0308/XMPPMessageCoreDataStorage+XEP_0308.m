#import "XMPPMessageCoreDataStorage+XEP_0308.h"
#import "XMPPMessageCOreDataStorageObject+Protected.h"
#import "XMPPMessageCoreDataStorageObject+ContextHelpers.h"
#import "NSManagedObject+XMPPCoreDataStorage.h"
#import "XMPPMessage+XEP_0308.h"

static XMPPMessageContextMarkerItemTag const XMPPMessageContextAssociatedCorrectionTag = @"XMPPMessageContextAssociatedCorrection";
static XMPPMessageContextStringItemTag const XMPPMessageContextCorrectionIDTag = @"XMPPMessageContextCorrectionID";

@interface XMPPMessageCoreDataStorageObject (XEP_0308_Private)

- (void)appendMessageCorrectionContextWithID:(NSString *)originalMessageID;

@end

@implementation XMPPMessageCoreDataStorageTransaction (XEP_0308)

- (void)registerOriginalMessageIDForReceivedCorrectedMessage:(XMPPMessage *)message
{
    [self scheduleStorageUpdateWithBlock:^(XMPPMessageCoreDataStorageObject * _Nonnull messageObject) {
        NSAssert(messageObject.direction == XMPPMessageDirectionIncoming, @"This action is only allowed for incoming message objects");
        [messageObject appendMessageCorrectionContextWithID:[message correctedMessageID]];
    }];
}

@end

@implementation XMPPMessageCoreDataStorageObject (XEP_0308)

+ (XMPPMessageCoreDataStorageObject *)findCorrectionForMessageWithID:(NSString *)originalMessageID inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSFetchRequest *fetchRequest = [XMPPMessageContextStringItemCoreDataStorageObject xmpp_fetchRequestInManagedObjectContext:managedObjectContext];
    NSArray *predicates = @[[XMPPMessageContextStringItemCoreDataStorageObject stringPredicateWithValue:originalMessageID],
                            [XMPPMessageContextStringItemCoreDataStorageObject tagPredicateWithValue:XMPPMessageContextCorrectionIDTag]];
    fetchRequest.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:predicates];
    
    NSArray<XMPPMessageContextStringItemCoreDataStorageObject *> *result = [managedObjectContext xmpp_executeForcedSuccessFetchRequest:fetchRequest];
    NSAssert(result.count <= 1, @"Multiple correction context items for the given original ID");
    return result.firstObject.message;
}

- (BOOL)hasAssociatedCorrectionMessage
{
    return [self lookupInContextWithBlock:^id _Nullable(XMPPMessageContextCoreDataStorageObject * _Nonnull contextElement) {
        return [contextElement hasMarkerItemForTag:XMPPMessageContextAssociatedCorrectionTag] ? contextElement : nil;
    }] != nil;
}

- (NSString *)messageCorrectionID
{
    return [self lookupInContextWithBlock:^id _Nullable(XMPPMessageContextCoreDataStorageObject * _Nonnull contextElement) {
        return [contextElement stringItemValueForTag:XMPPMessageContextCorrectionIDTag];
    }];
}

- (void)assignMessageCorrectionID:(NSString *)originalMessageID
{
    NSAssert(self.direction == XMPPMessageDirectionOutgoing, @"Only allowed for outgoing message objects");
    [self appendMessageCorrectionContextWithID:originalMessageID];
}

- (void)appendMessageCorrectionContextWithID:(NSString *)originalMessageID
{
    NSAssert(self.managedObjectContext, @"Attempted to assign a correction ID with no managed object context available");
    NSAssert(![self messageCorrectionID], @"Message correction ID is already assigned");
    
    [self retireStreamTimestamp];
    
    XMPPMessageContextCoreDataStorageObject *correctionContext = [self appendContextElement];
    [correctionContext appendStringItemWithTag:XMPPMessageContextCorrectionIDTag value:originalMessageID];
    
    XMPPMessageCoreDataStorageObject *originalMessage = [XMPPMessageCoreDataStorageObject findWithUniqueStanzaID:originalMessageID
                                                                                          inManagedObjectContext:self.managedObjectContext];
    NSAssert(originalMessage, @"Original message object not found");
    XMPPMessageContextCoreDataStorageObject *correctionOriginContext = [originalMessage appendContextElement];
    [correctionOriginContext appendMarkerItemWithTag:XMPPMessageContextAssociatedCorrectionTag];
}

@end
