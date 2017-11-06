#import "XMPPMessageCoreDataStorage+XEP_0184.h"
#import "XMPPMessageCoreDataStorageObject+Protected.h"
#import "XMPPMessageCoreDataStorageObject+ContextHelpers.h"
#import "NSManagedObject+XMPPCoreDataStorage.h"
#import "XMPPMessage+XEP_0184.h"

static XMPPMessageContextMarkerItemTag const XMPPMessageContextAssociatedDeliveryReceiptResponseTag = @"XMPPMessageContextAssociatedDeliveryReceiptResponse";
static XMPPMessageContextStringItemTag const XMPPMessageContextDeliveryReceiptResponseIDTag = @"XMPPMessageContextDeliveryReceiptResponseID";

@implementation XMPPMessageCoreDataStorageTransaction (XEP_0184)

- (void)storeReceivedDeliveryReceiptResponseMessage:(XMPPMessage *)message
{
    [self scheduleStorageUpdateWithBlock:^(XMPPMessageCoreDataStorageObject * _Nonnull messageObject) {
        NSAssert(messageObject.direction == XMPPMessageDirectionIncoming, @"This action is only allowed for incoming message objects");
        
        [messageObject registerIncomingMessageCore:message];
        
        NSString *deliveredMessageID = [message receiptResponseID];
        
        XMPPMessageContextCoreDataStorageObject *deliveryReceiptContext = [messageObject appendContextElement];
        [deliveryReceiptContext appendStringItemWithTag:XMPPMessageContextDeliveryReceiptResponseIDTag value:deliveredMessageID];
        
        XMPPMessageCoreDataStorageObject *sentMessageObject = [XMPPMessageCoreDataStorageObject findWithUniqueStanzaID:deliveredMessageID
                                                                                                inManagedObjectContext:messageObject.managedObjectContext];
        if (!sentMessageObject) {
            return;
        }
        
        XMPPMessageContextCoreDataStorageObject *deliveryConfirmationContext = [sentMessageObject appendContextElement];
        [deliveryConfirmationContext appendMarkerItemWithTag:XMPPMessageContextAssociatedDeliveryReceiptResponseTag];
    }];
}

@end

@implementation XMPPMessageCoreDataStorageObject (XEP_0184)

+ (XMPPMessageCoreDataStorageObject *)findDeliveryReceiptResponseForMessageWithID:(NSString *)messageID inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSFetchRequest *fetchRequest = [XMPPMessageContextStringItemCoreDataStorageObject xmpp_fetchRequestInManagedObjectContext:managedObjectContext];
    NSArray *predicates = @[[XMPPMessageContextStringItemCoreDataStorageObject stringPredicateWithValue:messageID],
                            [XMPPMessageContextStringItemCoreDataStorageObject tagPredicateWithValue:XMPPMessageContextDeliveryReceiptResponseIDTag]];
    fetchRequest.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:predicates];
    
    NSArray<XMPPMessageContextStringItemCoreDataStorageObject *> *result = [managedObjectContext xmpp_executeForcedSuccessFetchRequest:fetchRequest];
    NSAssert(result.count <= 1, @"Multiple delivery receipt context items for the given response ID");
    return result.firstObject.message;
}

- (BOOL)hasAssociatedDeliveryReceiptResponseMessage
{
    return [self lookupInContextWithBlock:^id _Nullable(XMPPMessageContextCoreDataStorageObject * _Nonnull contextElement) {
        return [contextElement hasMarkerItemForTag:XMPPMessageContextAssociatedDeliveryReceiptResponseTag] ? contextElement : nil;
    }] != nil;
}

- (NSString *)messageDeliveryReceiptResponseID
{
    return [self lookupInContextWithBlock:^id _Nullable(XMPPMessageContextCoreDataStorageObject * _Nonnull contextElement) {
        return [contextElement stringItemValueForTag:XMPPMessageContextDeliveryReceiptResponseIDTag];
    }];
}

@end
