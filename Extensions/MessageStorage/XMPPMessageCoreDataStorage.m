#import "XMPPMessageCoreDataStorage.h"
#import "XMPPCoreDataStorageProtected.h"
#import "XMPPMessageCoreDataStorageObject+Protected.h"
#import "NSManagedObject+XMPPCoreDataStorage.h"
#import "XMPPStream.h"

typedef NSMutableArray<void (^)(XMPPMessageCoreDataStorageObject *)> XMPPMessageCoreDataStorageUpdateBatch;

static void * const XMPPMessageCoreDataStorageIncomingEventObservationContext = (void *)&XMPPMessageCoreDataStorageIncomingEventObservationContext;
static void * const XMPPMessageCoreDataStorageOutgoingEventObservationContext = (void *)&XMPPMessageCoreDataStorageOutgoingEventObservationContext;

static void * const XMPPMessageCoreDataStorageTransactionIndexQueueTag = (void *)&XMPPMessageCoreDataStorageTransactionIndexQueueTag;

static NSString * const XMPPElementEventCompletionKeyPath = @"processingCompleted";

@interface XMPPMessageCoreDataStorage ()

@property (nonatomic, copy, readonly) NSMutableDictionary<NSString *, XMPPMessageCoreDataStorageTransaction *> *transactionIndex;
@property (nonatomic, strong, readonly) dispatch_queue_t transactionIndexQueue;

@end

@interface XMPPMessageCoreDataStorageTransaction ()

@property (nonatomic, unsafe_unretained, readonly) XMPPMessageCoreDataStorage *storage;
@property (nonatomic, strong, readonly) XMPPMessageCoreDataStorageUpdateBatch *updateBatch;

- (instancetype)initWithStorage:(XMPPMessageCoreDataStorage *)storage;

@end

@implementation XMPPMessageCoreDataStorage

- (id)initWithDatabaseFilename:(NSString *)aDatabaseFileName storeOptions:(NSDictionary *)theStoreOptions
{
    self = [super initWithDatabaseFilename:aDatabaseFileName storeOptions:theStoreOptions];
    if (self) {
        [self commonMessageStorageInit];
    }
    return self;
}

- (id)initWithInMemoryStore
{
    self = [super initWithInMemoryStore];
    if (self) {
        [self commonMessageStorageInit];
    }
    return self;
}

- (void)commonMessageStorageInit
{
    _transactionIndex = [[NSMutableDictionary alloc] init];
    _transactionIndexQueue = dispatch_queue_create("XMPPMessageCoreDataStorage.transactionIndexQueue", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_set_specific(_transactionIndexQueue,
                                XMPPMessageCoreDataStorageTransactionIndexQueueTag,
                                XMPPMessageCoreDataStorageTransactionIndexQueueTag,
                                NULL);
}

- (XMPPMessageCoreDataStorageObject *)insertOutgoingMessageStorageObject
{
    XMPPMessageCoreDataStorageObject *messageObject =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.mainThreadManagedObjectContext];
    messageObject.direction = XMPPMessageDirectionOutgoing;
    return messageObject;
}

- (void)provideTransactionForIncomingMessageEvent:(XMPPElementEvent *)event withHandler:(void (^)(XMPPMessageCoreDataStorageTransaction * _Nonnull))handler
{
    [self provideTransactionForMessageEvent:event withObservationContext:XMPPMessageCoreDataStorageIncomingEventObservationContext handler:handler];
}

- (void)provideTransactionForOutgoingMessageEvent:(XMPPElementEvent *)event withHandler:(void (^)(XMPPMessageCoreDataStorageTransaction * _Nonnull))handler
{
    [self provideTransactionForMessageEvent:event withObservationContext:XMPPMessageCoreDataStorageOutgoingEventObservationContext handler:handler];
}

- (void)provideTransactionForMessageEvent:(XMPPElementEvent *)event withObservationContext:(void *)observationContext handler:(void (^)(XMPPMessageCoreDataStorageTransaction *transaction))handler
{
    id transactionLookupToken = [event beginDelayedProcessing];
    
    dispatch_async(self.transactionIndexQueue, ^{
        XMPPMessageCoreDataStorageTransaction *transaction = self.transactionIndex[event.uniqueID];
        if (!transaction) {
            transaction = [[XMPPMessageCoreDataStorageTransaction alloc] initWithStorage:self];
            self.transactionIndex[event.uniqueID] = transaction;
            
            [event addObserver:transaction
                    forKeyPath:XMPPElementEventCompletionKeyPath
                       options:NSKeyValueObservingOptionNew
                       context:observationContext];
        }
        
        handler(transaction);
        
        [event endDelayedProcessingWithToken:transactionLookupToken];
    });
}

- (void)unregisterTransactionForMessageEvent:(XMPPElementEvent *)event withObservationContext:(void *)observationContext
{
    dispatch_async(self.transactionIndexQueue, ^{
        XMPPMessageCoreDataStorageTransaction *transaction = self.transactionIndex[event.uniqueID];
        NSAssert(transaction, @"No transaction registered for the given event");
        [event removeObserver:transaction forKeyPath:XMPPElementEventCompletionKeyPath context:observationContext];
        [self.transactionIndex removeObjectForKey:event.uniqueID];
    });
}

@end

@implementation XMPPMessageCoreDataStorageTransaction

- (instancetype)initWithStorage:(XMPPMessageCoreDataStorage *)storage
{
    self = [super init];
    if (self) {
        _storage = storage;
        _updateBatch = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)scheduleStorageUpdateWithBlock:(void (^)(XMPPMessageCoreDataStorageObject * _Nonnull))block
{
    NSAssert(dispatch_get_specific(XMPPMessageCoreDataStorageTransactionIndexQueueTag), @"This has to be invoked from a transaction handler block");
    [self.updateBatch addObject:block];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if (context == XMPPMessageCoreDataStorageIncomingEventObservationContext) {
        if ([keyPath isEqualToString:XMPPElementEventCompletionKeyPath] && [change[NSKeyValueChangeNewKey] isEqualToNumber:@YES]) {
            [self observeProcessingCompletionForIncomingMessageEvent:object];
            [self.storage unregisterTransactionForMessageEvent:object withObservationContext:context];
        }
    } else if (context == XMPPMessageCoreDataStorageOutgoingEventObservationContext) {
        if ([keyPath isEqualToString:XMPPElementEventCompletionKeyPath] && [change[NSKeyValueChangeNewKey] isEqualToNumber:@YES]) {
            [self observeProcessingCompletionForOutgoingMessageEvent:object];
            [self.storage unregisterTransactionForMessageEvent:object withObservationContext:context];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)observeProcessingCompletionForIncomingMessageEvent:(XMPPElementEvent *)event
{
    [self.storage scheduleBlock:^{
        NSAssert(![XMPPMessageCoreDataStorageObject findWithStreamEventID:event.uniqueID inManagedObjectContext:self.storage.managedObjectContext],
                 @"Unexpected existing storage object found");
        
        XMPPMessageCoreDataStorageObject *insertedMessageObject =
        [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.managedObjectContext];
        insertedMessageObject.direction = XMPPMessageDirectionIncoming;
        [insertedMessageObject registerIncomingMessageStreamEventID:event.uniqueID streamJID:event.myJID streamEventTimestamp:event.timestamp];
        
        for (void (^updateBlock)(XMPPMessageCoreDataStorageObject *) in self.updateBatch) {
            updateBlock(insertedMessageObject);
        }
    }];
}

- (void)observeProcessingCompletionForOutgoingMessageEvent:(XMPPElementEvent *)event
{
    [self.storage scheduleBlock:^{
        XMPPMessageCoreDataStorageObject *existingMessageObject = [XMPPMessageCoreDataStorageObject findWithStreamEventID:event.uniqueID
                                                                                                   inManagedObjectContext:self.storage.managedObjectContext];
        NSAssert(existingMessageObject, @"Expected existing storage object not found");
        NSAssert(existingMessageObject.direction == XMPPMessageDirectionOutgoing, @"Unexpected existing storage object direction");
        
        [existingMessageObject registerOutgoingMessageStreamJID:event.myJID streamEventTimestamp:event.timestamp];
        
        for (void (^updateBlock)(XMPPMessageCoreDataStorageObject *) in self.updateBatch) {
            updateBlock(existingMessageObject);
        }
    }];
}

@end
