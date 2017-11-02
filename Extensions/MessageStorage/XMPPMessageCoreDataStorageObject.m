#import "XMPPMessageCoreDataStorageObject.h"
#import "XMPPMessageCoreDataStorageObject+Protected.h"
#import "XMPPMessageCoreDataStorageObject+ContextHelpers.h"
#import "XMPPMessageContextItemCoreDataStorageObject.h"
#import "NSManagedObject+XMPPCoreDataStorage.h"
#import "XMPPJID.h"
#import "XMPPMessage.h"

static XMPPMessageContextJIDItemTag const XMPPMessageContextStreamJIDTag = @"XMPPMessageContextStreamJID";
static XMPPMessageContextMarkerItemTag const XMPPMessageContextPendingStreamContextAssignmentTag = @"XMPPMessageContextPendingStreamContextAssignment";
static XMPPMessageContextMarkerItemTag const XMPPMessageContextLatestStreamTimestampRetirementTag = @"XMPPMessageContextLatestStreamTimestampRetirement";
static XMPPMessageContextStringItemTag const XMPPMessageContextStreamEventIDTag = @"XMPPMessageContextStreamEventID";
static XMPPMessageContextTimestampItemTag const XMPPMessageContextActiveStreamTimestampTag = @"XMPPMessageContextActiveStreamTimestamp";
static XMPPMessageContextTimestampItemTag const XMPPMessageContextRetiredStreamTimestampTag = @"XMPPMessageContextRetiredStreamTimestamp";

@interface XMPPMessageCoreDataStorageObject ()

@property (nonatomic, copy, nullable) NSString *fromDomain;
@property (nonatomic, copy, nullable) NSString *fromResource;
@property (nonatomic, copy, nullable) NSString *fromUser;
@property (nonatomic, copy, nullable) NSString *toDomain;
@property (nonatomic, copy, nullable) NSString *toResource;
@property (nonatomic, copy, nullable) NSString *toUser;

@property (nonatomic, copy, nullable) NSSet<XMPPMessageContextCoreDataStorageObject *> *contextElements;

@end

@interface XMPPMessageCoreDataStorageObject (CoreDataGeneratedPrimitiveAccessors)

- (XMPPJID *)primitiveFromJID;
- (void)setPrimitiveFromJID:(XMPPJID *)value;
- (void)setPrimitiveFromDomain:(NSString *)value;
- (void)setPrimitiveFromResource:(NSString *)value;
- (void)setPrimitiveFromUser:(NSString *)value;

- (XMPPJID *)primitiveToJID;
- (void)setPrimitiveToJID:(XMPPJID *)value;
- (void)setPrimitiveToDomain:(NSString *)value;
- (void)setPrimitiveToResource:(NSString *)value;
- (void)setPrimitiveToUser:(NSString *)value;

@end

@implementation XMPPMessageCoreDataStorageObject

@dynamic fromDomain, fromResource, fromUser, toDomain, toResource, toUser, body, stanzaID, subject, thread, direction, type, contextElements;

#pragma mark - fromJID transient property

- (XMPPJID *)fromJID
{
    [self willAccessValueForKey:NSStringFromSelector(@selector(fromJID))];
    XMPPJID *fromJID = [self primitiveFromJID];
    [self didAccessValueForKey:NSStringFromSelector(@selector(fromJID))];
    
    if (fromJID) {
        return fromJID;
    }
    
    XMPPJID *newFromJID = [XMPPJID jidWithUser:self.fromUser domain:self.fromDomain resource:self.fromResource];
    [self setPrimitiveFromJID:newFromJID];
    
    return newFromJID;
}

- (void)setFromJID:(XMPPJID *)fromJID
{
    if ([self.fromJID isEqualToJID:fromJID options:XMPPJIDCompareFull]) {
        return;
    }
    
    [self willChangeValueForKey:NSStringFromSelector(@selector(fromJID))];
    [self willChangeValueForKey:NSStringFromSelector(@selector(fromDomain))];
    [self willChangeValueForKey:NSStringFromSelector(@selector(fromResource))];
    [self willChangeValueForKey:NSStringFromSelector(@selector(fromUser))];
    [self setPrimitiveFromJID:fromJID];
    [self setPrimitiveFromDomain:fromJID.domain];
    [self setPrimitiveFromResource:fromJID.resource];
    [self setPrimitiveFromUser:fromJID.user];
    [self didChangeValueForKey:NSStringFromSelector(@selector(fromDomain))];
    [self didChangeValueForKey:NSStringFromSelector(@selector(fromResource))];
    [self didChangeValueForKey:NSStringFromSelector(@selector(fromUser))];
    [self didChangeValueForKey:NSStringFromSelector(@selector(fromJID))];
}

- (void)setFromDomain:(NSString *)fromDomain
{
    if ([self.fromDomain isEqualToString:fromDomain]) {
        return;
    }
    
    [self willChangeValueForKey:NSStringFromSelector(@selector(fromDomain))];
    [self willChangeValueForKey:NSStringFromSelector(@selector(fromJID))];
    [self setPrimitiveFromDomain:fromDomain];
    [self setPrimitiveFromJID:nil];
    [self didChangeValueForKey:NSStringFromSelector(@selector(fromJID))];
    [self didChangeValueForKey:NSStringFromSelector(@selector(fromDomain))];
}

- (void)setFromResource:(NSString *)fromResource
{
    if ([self.fromResource isEqualToString:fromResource]) {
        return;
    }
    
    [self willChangeValueForKey:NSStringFromSelector(@selector(fromResource))];
    [self willChangeValueForKey:NSStringFromSelector(@selector(fromJID))];
    [self setPrimitiveFromResource:fromResource];
    [self setPrimitiveFromJID:nil];
    [self didChangeValueForKey:NSStringFromSelector(@selector(fromJID))];
    [self didChangeValueForKey:NSStringFromSelector(@selector(fromResource))];
}

- (void)setFromUser:(NSString *)fromUser
{
    if ([self.fromUser isEqualToString:fromUser]) {
        return;
    }
    
    [self willChangeValueForKey:NSStringFromSelector(@selector(fromUser))];
    [self willChangeValueForKey:NSStringFromSelector(@selector(fromJID))];
    [self setPrimitiveFromUser:fromUser];
    [self setPrimitiveFromJID:nil];
    [self didChangeValueForKey:NSStringFromSelector(@selector(fromJID))];
    [self didChangeValueForKey:NSStringFromSelector(@selector(fromUser))];
}

#pragma mark - toJID transient property

- (XMPPJID *)toJID
{
    [self willAccessValueForKey:NSStringFromSelector(@selector(toJID))];
    XMPPJID *toJID = [self primitiveToJID];
    [self didAccessValueForKey:NSStringFromSelector(@selector(toJID))];
    
    if (toJID) {
        return toJID;
    }
    
    XMPPJID *newToJID = [XMPPJID jidWithUser:self.toUser domain:self.toDomain resource:self.toResource];
    [self setPrimitiveToJID:newToJID];
    
    return newToJID;
}

- (void)setToJID:(XMPPJID *)toJID
{
    if ([self.toJID isEqualToJID:toJID options:XMPPJIDCompareFull]) {
        return;
    }
    
    [self willChangeValueForKey:NSStringFromSelector(@selector(toJID))];
    [self willChangeValueForKey:NSStringFromSelector(@selector(toDomain))];
    [self willChangeValueForKey:NSStringFromSelector(@selector(toResource))];
    [self willChangeValueForKey:NSStringFromSelector(@selector(toUser))];
    [self setPrimitiveToJID:toJID];
    [self setPrimitiveToDomain:toJID.domain];
    [self setPrimitiveToResource:toJID.resource];
    [self setPrimitiveToUser:toJID.user];
    [self didChangeValueForKey:NSStringFromSelector(@selector(toDomain))];
    [self didChangeValueForKey:NSStringFromSelector(@selector(toResource))];
    [self didChangeValueForKey:NSStringFromSelector(@selector(toUser))];
    [self didChangeValueForKey:NSStringFromSelector(@selector(toJID))];
}

- (void)setToDomain:(NSString *)toDomain
{
    if ([self.toDomain isEqualToString:toDomain]) {
        return;
    }
    
    [self willChangeValueForKey:NSStringFromSelector(@selector(toDomain))];
    [self willChangeValueForKey:NSStringFromSelector(@selector(toJID))];
    [self setPrimitiveToDomain:toDomain];
    [self setPrimitiveToJID:nil];
    [self didChangeValueForKey:NSStringFromSelector(@selector(toJID))];
    [self didChangeValueForKey:NSStringFromSelector(@selector(toDomain))];
}

- (void)setToResource:(NSString *)toResource
{
    if ([self.toResource isEqualToString:toResource]) {
        return;
    }
    
    [self willChangeValueForKey:NSStringFromSelector(@selector(toResource))];
    [self willChangeValueForKey:NSStringFromSelector(@selector(toJID))];
    [self setPrimitiveToResource:toResource];
    [self setPrimitiveToJID:nil];
    [self didChangeValueForKey:NSStringFromSelector(@selector(toJID))];
    [self didChangeValueForKey:NSStringFromSelector(@selector(toResource))];
}

- (void)setToUser:(NSString *)toUser
{
    if ([self.toUser isEqualToString:toUser]) {
        return;
    }
    
    [self willChangeValueForKey:NSStringFromSelector(@selector(toUser))];
    [self willChangeValueForKey:NSStringFromSelector(@selector(toJID))];
    [self setPrimitiveToUser:toUser];
    [self setPrimitiveToJID:nil];
    [self didChangeValueForKey:NSStringFromSelector(@selector(toJID))];
    [self didChangeValueForKey:NSStringFromSelector(@selector(toUser))];
}

#pragma mark - Public

+ (XMPPMessageCoreDataStorageObject *)findWithStreamEventID:(NSString *)streamEventID inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSFetchRequest *fetchRequest = [XMPPMessageContextStringItemCoreDataStorageObject xmpp_fetchRequestInManagedObjectContext:managedObjectContext];
    NSArray *predicates = @[[XMPPMessageContextStringItemCoreDataStorageObject stringPredicateWithValue:streamEventID],
                            [XMPPMessageContextStringItemCoreDataStorageObject tagPredicateWithValue:XMPPMessageContextStreamEventIDTag]];
    fetchRequest.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:predicates];
    
    NSArray<XMPPMessageContextStringItemCoreDataStorageObject *> *fetchResult = [managedObjectContext xmpp_executeForcedSuccessFetchRequest:fetchRequest];
    NSAssert(fetchResult.count <= 1, @"Expected a single context item for any given stream event ID");
    
    return fetchResult.firstObject.contextElement.message;
}

+ (XMPPMessageCoreDataStorageObject *)findWithUniqueStanzaID:(NSString *)stanzaID inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSFetchRequest *fetchRequest = [XMPPMessageCoreDataStorageObject xmpp_fetchRequestInManagedObjectContext:managedObjectContext];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"%K = %@", NSStringFromSelector(@selector(stanzaID)), stanzaID];
    
    NSArray *fetchResult = [managedObjectContext xmpp_executeForcedSuccessFetchRequest:fetchRequest];
    return fetchResult.count == 1 ? fetchResult.firstObject : nil;
}

- (XMPPMessage *)coreMessage
{
    NSString *typeString;
    switch (self.type) {
        case XMPPMessageTypeChat:
            typeString = @"chat";
            break;
            
        case XMPPMessageTypeError:
            typeString = @"error";
            break;
            
        case XMPPMessageTypeGroupchat:
            typeString = @"groupchat";
            break;
            
        case XMPPMessageTypeHeadline:
            typeString = @"headline";
            break;
            
        case XMPPMessageTypeNormal:
            typeString = @"normal";
            break;
    }
    
    XMPPMessage *message = [[XMPPMessage alloc] initWithType:typeString to:self.toJID elementID:self.stanzaID];
    
    if (self.body) {
        [message addBody:self.body];
    }
    if (self.subject) {
        [message addSubject:self.subject];
    }
    if (self.thread) {
        [message addThread:self.thread];
    }
    
    return message;
}

- (void)registerIncomingMessageCore:(XMPPMessage *)message
{
    NSAssert(self.direction == XMPPMessageDirectionIncoming, @"Only applicable to incoming message objects");
    
    self.fromJID = [message from];
    self.toJID = [message to];
    self.body = [message body];
    self.stanzaID = [message elementID];
    self.subject = [message subject];
    self.thread = [message thread];
    
    if ([[message type] isEqualToString:@"chat"]) {
        self.type = XMPPMessageTypeChat;
    } else if ([[message type] isEqualToString:@"error"]) {
        self.type = XMPPMessageTypeError;
    } else if ([[message type] isEqualToString:@"groupchat"]) {
        self.type = XMPPMessageTypeGroupchat;
    } else if ([[message type] isEqualToString:@"headline"]) {
        self.type = XMPPMessageTypeHeadline;
    } else {
        self.type = XMPPMessageTypeNormal;
    }
}

- (void)registerIncomingMessageStreamEventID:(NSString *)streamEventID streamJID:(XMPPJID *)streamJID streamEventTimestamp:(NSDate *)streamEventTimestamp
{
    NSAssert(self.direction == XMPPMessageDirectionIncoming, @"Only applicable to incoming message objects");
    NSAssert(![self lookupCurrentStreamContext], @"Another stream context element already exists");
    
    XMPPMessageContextCoreDataStorageObject *streamContext = [self appendContextElement];
    [streamContext appendStringItemWithTag:XMPPMessageContextStreamEventIDTag value:streamEventID];
    [streamContext appendJIDItemWithTag:XMPPMessageContextStreamJIDTag value:streamJID];
    [streamContext appendTimestampItemWithTag:XMPPMessageContextActiveStreamTimestampTag value:streamEventTimestamp];
}

- (void)registerOutgoingMessageStreamEventID:(NSString *)outgoingMessageStreamEventID
{
    NSAssert(self.direction == XMPPMessageDirectionOutgoing, @"Only applicable to outgoing message objects");
    NSAssert(![self lookupPendingStreamContext], @"Pending stream context element already exists");
    
    XMPPMessageContextCoreDataStorageObject *streamContext = [self appendContextElement];
    [streamContext appendStringItemWithTag:XMPPMessageContextStreamEventIDTag value:outgoingMessageStreamEventID];
    [streamContext appendMarkerItemWithTag:XMPPMessageContextPendingStreamContextAssignmentTag];
}

- (void)registerOutgoingMessageStreamJID:(XMPPJID *)streamJID streamEventTimestamp:(NSDate *)streamEventTimestamp
{
    NSAssert(self.direction == XMPPMessageDirectionOutgoing, @"Only applicable to outgoing message objects");
    
    XMPPMessageContextCoreDataStorageObject *streamContext = [self lookupPendingStreamContext];
    NSAssert(streamContext, @"No pending stream context element found");
    
    XMPPMessageContextTimestampItemTag timestampTag;
    if ([self lookupActiveStreamContext]) {
        [self retireStreamTimestamp];
        timestampTag = XMPPMessageContextActiveStreamTimestampTag;
    } else if (![self lookupLatestRetiredStreamContext]) {
        timestampTag = XMPPMessageContextActiveStreamTimestampTag;
    } else {
        timestampTag = XMPPMessageContextRetiredStreamTimestampTag;
    }
    
    [streamContext removeMarkerItemsWithTag:XMPPMessageContextPendingStreamContextAssignmentTag];
    [streamContext appendJIDItemWithTag:XMPPMessageContextStreamJIDTag value:streamJID];
    [streamContext appendTimestampItemWithTag:timestampTag value:streamEventTimestamp];
}

- (XMPPJID *)streamJID
{
    return [[self lookupCurrentStreamContext] jidItemValueForTag:XMPPMessageContextStreamJIDTag];
}

- (NSDate *)streamTimestamp
{
    XMPPMessageContextCoreDataStorageObject *latestStreamContext = [self lookupCurrentStreamContext];
    return [latestStreamContext timestampItemValueForTag:XMPPMessageContextActiveStreamTimestampTag] ?: [latestStreamContext timestampItemValueForTag:XMPPMessageContextRetiredStreamTimestampTag];
}

- (void)retireStreamTimestamp
{
    XMPPMessageContextCoreDataStorageObject *previousRetiredStreamContext = [self lookupLatestRetiredStreamContext];
    XMPPMessageContextCoreDataStorageObject *activeStreamContext = [self lookupActiveStreamContext];
    
    if (activeStreamContext) {
        [previousRetiredStreamContext removeMarkerItemsWithTag:XMPPMessageContextLatestStreamTimestampRetirementTag];
        
        NSDate *retiredStreamTimestamp = [activeStreamContext timestampItemValueForTag:XMPPMessageContextActiveStreamTimestampTag];
        [activeStreamContext removeTimestampItemsWithTag:XMPPMessageContextActiveStreamTimestampTag];
        [activeStreamContext appendTimestampItemWithTag:XMPPMessageContextRetiredStreamTimestampTag value:retiredStreamTimestamp];
        [activeStreamContext appendMarkerItemWithTag:XMPPMessageContextLatestStreamTimestampRetirementTag];
    } else if (!previousRetiredStreamContext) {
        XMPPMessageContextCoreDataStorageObject *initialPendingStreamContext = [self lookupPendingStreamContext];
        [initialPendingStreamContext appendMarkerItemWithTag:XMPPMessageContextLatestStreamTimestampRetirementTag];
    } else {
        NSAssert(NO, @"No stream context element found for retiring");
    }
}

#pragma mark - Overridden

- (void)awakeFromSnapshotEvents:(NSSnapshotEventType)flags
{
    [super awakeFromSnapshotEvents:flags];
    
    [self setPrimitiveFromJID:nil];
    [self setPrimitiveToJID:nil];
}

#pragma mark - Private

- (XMPPMessageContextCoreDataStorageObject *)lookupPendingStreamContext
{
    return [self lookupInContextWithBlock:^id _Nullable(XMPPMessageContextCoreDataStorageObject * _Nonnull contextElement) {
        return [contextElement hasMarkerItemForTag:XMPPMessageContextPendingStreamContextAssignmentTag] ? contextElement : nil;
    }];
}

- (XMPPMessageContextCoreDataStorageObject *)lookupCurrentStreamContext
{
    return [self lookupActiveStreamContext] ?: [self lookupLatestRetiredStreamContext];
}

- (XMPPMessageContextCoreDataStorageObject *)lookupActiveStreamContext
{
    return [self lookupInContextWithBlock:^id _Nullable(XMPPMessageContextCoreDataStorageObject * _Nonnull contextElement) {
        return [contextElement timestampItemValueForTag:XMPPMessageContextActiveStreamTimestampTag] ? contextElement : nil;
    }];
}

- (XMPPMessageContextCoreDataStorageObject *)lookupLatestRetiredStreamContext
{
    return [self lookupInContextWithBlock:^id _Nullable(XMPPMessageContextCoreDataStorageObject * _Nonnull contextElement) {
        return [contextElement hasMarkerItemForTag:XMPPMessageContextLatestStreamTimestampRetirementTag] ? contextElement : nil;
    }];
}

@end

@implementation XMPPMessageContextItemCoreDataStorageObject (XMPPMessageCoreDataStorageFetch)

+ (NSFetchRequest<XMPPMessageContextItemCoreDataStorageObject *> *)requestByTimestampsWithPredicate:(NSPredicate *)predicate inAscendingOrder:(BOOL)isInAscendingOrder fromManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSFetchRequest *fetchRequest = [XMPPMessageContextTimestampItemCoreDataStorageObject xmpp_fetchRequestInManagedObjectContext:managedObjectContext];
    fetchRequest.predicate = predicate;
    fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:NSStringFromSelector(@selector(value)) ascending:isInAscendingOrder]];
    return fetchRequest;
}

+ (NSPredicate *)streamTimestampKindPredicate
{
    return [XMPPMessageContextTimestampItemCoreDataStorageObject tagPredicateWithValue:XMPPMessageContextActiveStreamTimestampTag];
}

+ (NSPredicate *)timestampRangePredicateWithStartValue:(nullable NSDate *)startValue endValue:(nullable NSDate *)endValue
{
    return [XMPPMessageContextTimestampItemCoreDataStorageObject timestampRangePredicateWithStartValue:startValue endValue:endValue];
}

+ (NSPredicate *)messageFromJIDPredicateWithValue:(XMPPJID *)value compareOptions:(XMPPJIDCompareOptions)compareOptions
{
    return [self xmpp_jidPredicateWithDomainKeyPath:[[self messageKeyPath] stringByAppendingFormat:@".%@", NSStringFromSelector(@selector(fromDomain))]
                                    resourceKeyPath:[[self messageKeyPath] stringByAppendingFormat:@".%@", NSStringFromSelector(@selector(fromResource))]
                                        userKeyPath:[[self messageKeyPath] stringByAppendingFormat:@".%@", NSStringFromSelector(@selector(fromUser))]
                                              value:value
                                     compareOptions:compareOptions];
}

+ (NSPredicate *)messageToJIDPredicateWithValue:(XMPPJID *)value compareOptions:(XMPPJIDCompareOptions)compareOptions
{
    return [self xmpp_jidPredicateWithDomainKeyPath:[[self messageKeyPath] stringByAppendingFormat:@".%@", NSStringFromSelector(@selector(toDomain))]
                                    resourceKeyPath:[[self messageKeyPath] stringByAppendingFormat:@".%@", NSStringFromSelector(@selector(toResource))]
                                        userKeyPath:[[self messageKeyPath] stringByAppendingFormat:@".%@", NSStringFromSelector(@selector(toUser))]
                                              value:value
                                     compareOptions:compareOptions];
}

+ (NSPredicate *)messageRemotePartyJIDPredicateWithValue:(XMPPJID *)value compareOptions:(XMPPJIDCompareOptions)compareOptions
{
    NSArray *outgoingMessagePredicates = @[[self messageToJIDPredicateWithValue:value compareOptions:compareOptions],
                                           [XMPPMessageContextItemCoreDataStorageObject messageDirectionPredicateWithValue:XMPPMessageDirectionOutgoing]];
    NSArray *incomingMessagePredicates = @[[self messageFromJIDPredicateWithValue:value compareOptions:compareOptions],
                                           [XMPPMessageContextItemCoreDataStorageObject messageDirectionPredicateWithValue:XMPPMessageDirectionIncoming]];
    
    return [NSCompoundPredicate orPredicateWithSubpredicates:@[[NSCompoundPredicate andPredicateWithSubpredicates:outgoingMessagePredicates],
                                                               [NSCompoundPredicate andPredicateWithSubpredicates:incomingMessagePredicates]]];
}

+ (NSPredicate *)messageBodyPredicateWithValue:(NSString *)value compareOperator:(XMPPMessageContentCompareOperator)compareOperator options:(XMPPMessageContentCompareOptions)options
{
    return [self messageContentPredicateWithKey:NSStringFromSelector(@selector(body)) value:value compareOperator:compareOperator options:options];
}

+ (NSPredicate *)messageSubjectPredicateWithValue:(NSString *)value compareOperator:(XMPPMessageContentCompareOperator)compareOperator options:(XMPPMessageContentCompareOptions)options
{
    return [self messageContentPredicateWithKey:NSStringFromSelector(@selector(subject)) value:value compareOperator:compareOperator options:options];
}

+ (NSPredicate *)messageThreadPredicateWithValue:(NSString *)value
{
    return [NSPredicate predicateWithFormat:@"%K.%K = %@", [self messageKeyPath], NSStringFromSelector(@selector(thread)), value];
}

+ (NSPredicate *)messageDirectionPredicateWithValue:(XMPPMessageDirection)value
{
    return [NSPredicate predicateWithFormat:@"%K.%K = %d", [self messageKeyPath], NSStringFromSelector(@selector(direction)), value];
}

+ (NSPredicate *)messageTypePredicateWithValue:(XMPPMessageType)value
{
    return [NSPredicate predicateWithFormat:@"%K.%K = %d", [self messageKeyPath], NSStringFromSelector(@selector(type)), value];
}

+ (NSPredicate *)messageContentPredicateWithKey:(NSString *)contentKey value:(NSString *)value compareOperator:(XMPPMessageContentCompareOperator)compareOperator options:(XMPPMessageContentCompareOptions)options
{
    NSMutableString *predicateFormat = [[NSMutableString alloc] initWithFormat:@"%@.%@ ", [self messageKeyPath], contentKey];
    
    switch (compareOperator) {
        case XMPPMessageContentCompareOperatorEquals:
            [predicateFormat appendString:@"= "];
            break;
        case XMPPMessageContentCompareOperatorBeginsWith:
            [predicateFormat appendString:@"BEGINSWITH "];
            break;
        case XMPPMessageContentCompareOperatorContains:
            [predicateFormat appendString:@"CONTAINS "];
            break;
        case XMPPMessageContentCompareOperatorEndsWith:
            [predicateFormat appendString:@"ENDSWITH "];
            break;
        case XMPPMessageContentCompareOperatorLike:
            [predicateFormat appendString:@"LIKE "];
            break;
        case XMPPMessageContentCompareOperatorMatches:
            [predicateFormat appendString:@"MATCHES "];
            break;
    }
    
    NSMutableString *optionString = [[NSMutableString alloc] init];
    if (options & XMPPMessageContentCompareCaseInsensitive) {
        [optionString appendString:@"c"];
    }
    if (options & XMPPMessageContentCompareDiacriticInsensitive) {
        [optionString appendString:@"d"];
    }
    if (optionString.length > 0) {
        [predicateFormat appendFormat:@"[%@] ", optionString];
    }
    
    [predicateFormat appendString:@"%@"];
    
    return [NSPredicate predicateWithFormat:predicateFormat, value];
}

+ (NSString *)messageKeyPath
{
    return [NSString stringWithFormat:@"%@.%@", NSStringFromSelector(@selector(contextElement)), NSStringFromSelector(@selector(message))];
}

- (XMPPMessageCoreDataStorageObject *)message
{
    return self.contextElement.message;
}

@end
