#import "XMPPMessageCoreDataStorage+XEP_0198.h"
#import "XMPPCoreDataStorageProtected.h"
#import "XMPPMessageCoreDataStorageObject+Protected.h"
#import "XMPPMessageCoreDataStorageObject+ContextHelpers.h"
#import "NSManagedObject+XMPPCoreDataStorage.h"

static XMPPMessageContextTimestampItemTag const XMPPMessageContextManagedMessagingAttemptTimestampTag = @"XMPPMessageContextManagedMessagingAttemptTimestamp";
static XMPPMessageContextMarkerItemTag const XMPPMessageContextManagedMessagingPendingStatusTag = @"XMPPMessageContextManagedMessagingPendingStatus";
static XMPPMessageContextMarkerItemTag const XMPPMessageContextManagedMessagingAcknowledgedStatusTag = @"XMPPMessageContextManagedMessagingAcknowledgedStatus";

@interface XMPPMessageCoreDataStorageObject (XEP_0198_Private)

- (XMPPMessageContextCoreDataStorageObject *)lookupManagedMessagingContextWithBlock:(BOOL (^)(XMPPMessageContextCoreDataStorageObject *contextElement))block;
- (id)lookupInManagedMessagingContextWithBlock:(id (^)(XMPPMessageContextCoreDataStorageObject *contextElement))block;

@end

@implementation XMPPMessageCoreDataStorage (XEP_0198)

- (void)registerAcknowledgedManagedMessageIDs:(NSArray<NSString *> *)messageIDs
{
    [self scheduleBlock:^{
        // TODO: a single fetch
        for (NSString *messageID in messageIDs) {
            XMPPMessageCoreDataStorageObject *message = [XMPPMessageCoreDataStorageObject findWithUniqueStanzaID:messageID
                                                                                          inManagedObjectContext:self.managedObjectContext];
            XMPPMessageContextCoreDataStorageObject *managedMessagingContext =
            [message lookupManagedMessagingContextWithBlock:^BOOL(XMPPMessageContextCoreDataStorageObject *contextElement) {
                return [contextElement hasMarkerItemForTag:XMPPMessageContextManagedMessagingPendingStatusTag];
            }];
            NSAssert(managedMessagingContext, @"No managed messaging context awaiting confirmation found");
            
            [managedMessagingContext removeMarkerItemsWithTag:XMPPMessageContextManagedMessagingPendingStatusTag];
            [managedMessagingContext appendMarkerItemWithTag:XMPPMessageContextManagedMessagingAcknowledgedStatusTag];
        }
    }];
}

- (void)registerFailureForUnacknowledgedManagedMessages
{
    [self scheduleBlock:^{
        NSFetchRequest *fetchRequest = [XMPPMessageContextMarkerItemCoreDataStorageObject xmpp_fetchRequestInManagedObjectContext:self.managedObjectContext];
        fetchRequest.predicate = [XMPPMessageContextMarkerItemCoreDataStorageObject tagPredicateWithValue:XMPPMessageContextManagedMessagingPendingStatusTag];
        
        for (XMPPMessageContextMarkerItemCoreDataStorageObject *markerItem in [self.managedObjectContext xmpp_executeForcedSuccessFetchRequest:fetchRequest]) {
            XMPPMessageContextCoreDataStorageObject *managedMessagingContext = markerItem.contextElement;
            [managedMessagingContext removeMarkerItemsWithTag:XMPPMessageContextManagedMessagingPendingStatusTag];
        }
    }];
}

@end

@implementation XMPPMessageCoreDataStorageTransaction (XEP_0198)

- (void)registerSentManagedMessage
{
    [self scheduleStorageUpdateWithBlock:^(XMPPMessageCoreDataStorageObject * _Nonnull messageObject) {
        NSAssert(messageObject.direction == XMPPMessageDirectionOutgoing, @"No outgoing message found");
        NSAssert(![messageObject lookupManagedMessagingContextWithBlock:^BOOL(XMPPMessageContextCoreDataStorageObject *contextElement) {
            return [contextElement hasMarkerItemForTag:XMPPMessageContextManagedMessagingAcknowledgedStatusTag];
        }], @"Managed message already acknowledged");
        
        XMPPMessageContextCoreDataStorageObject *managedMessagingContext =
        [messageObject lookupManagedMessagingContextWithBlock:^BOOL(XMPPMessageContextCoreDataStorageObject *contextElement) {
            return [contextElement hasMarkerItemForTag:XMPPMessageContextManagedMessagingPendingStatusTag];
        }];
        if (!managedMessagingContext) {
            managedMessagingContext = [messageObject appendContextElement];
            [managedMessagingContext appendMarkerItemWithTag:XMPPMessageContextManagedMessagingPendingStatusTag];
        }
        
        [managedMessagingContext appendTimestampItemWithTag:XMPPMessageContextManagedMessagingAttemptTimestampTag value:[messageObject streamTimestamp]];
    }];
}

@end

@implementation XMPPMessageCoreDataStorageObject (XEP_0198)

- (XMPPManagedMessagingStatus)managedMessagingStatus
{
    __block BOOL hasManagedMessagingContext = NO;
    NSNumber *managedMessagingStatusNumber = [self lookupInManagedMessagingContextWithBlock:^id(XMPPMessageContextCoreDataStorageObject *contextElement) {
        hasManagedMessagingContext = YES;
        
        if ([contextElement hasMarkerItemForTag:XMPPMessageContextManagedMessagingAcknowledgedStatusTag]) {
            return @(XMPPManagedMessagingStatusAcknowledged);
        }
        
        if ([contextElement hasMarkerItemForTag:XMPPMessageContextManagedMessagingPendingStatusTag]) {
            return @(XMPPManagedMessagingStatusPendingAcknowledgement);
        }
        
        return nil;
    }];
    
    if (managedMessagingStatusNumber) {
        return managedMessagingStatusNumber.integerValue;
    } else if (hasManagedMessagingContext) {
        return XMPPManagedMessagingStatusUnacknowledged;
    } else {
        return XMPPManagedMessagingStatusUnspecified;
    }
}

- (XMPPMessageContextCoreDataStorageObject *)lookupManagedMessagingContextWithBlock:(BOOL (^)(XMPPMessageContextCoreDataStorageObject *))block
{
    return [self lookupInManagedMessagingContextWithBlock:^id(XMPPMessageContextCoreDataStorageObject *contextElement) {
        return block(contextElement) ? contextElement : nil;
    }];
}

- (id)lookupInManagedMessagingContextWithBlock:(id (^)(XMPPMessageContextCoreDataStorageObject *))block
{
    return [self lookupInContextWithBlock:^id _Nullable(XMPPMessageContextCoreDataStorageObject * _Nonnull contextElement) {
        return [contextElement timestampItemValuesForTag:XMPPMessageContextManagedMessagingAttemptTimestampTag].count > 0 ? block(contextElement) : nil;
    }];
}

@end
