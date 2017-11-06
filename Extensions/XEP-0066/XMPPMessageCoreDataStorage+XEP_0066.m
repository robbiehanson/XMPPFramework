#import "XMPPMessageCoreDataStorage+XEP_0066.h"
#import "XMPPMessageCoreDataStorageObject+ContextHelpers.h"
#import "XMPPMessage+XEP_0066.h"

static XMPPMessageContextStringItemTag const XMPPMessageContextOutOfBandResourceIDTag = @"XMPPMessageContextOutOfBandResourceID";
static XMPPMessageContextStringItemTag const XMPPMessageContextOutOfBandResourceURIStringTag = @"XMPPMessageContextOutOfBandResourceURIString";
static XMPPMessageContextStringItemTag const XMPPMessageContextOutOfBandResourceDescriptionTag = @"XMPPMessageContextOutOfBandResourceDescription";

@interface XMPPMessageCoreDataStorageObject (XEP_0066_Private)

- (void)appendOutOfBandResourceContextWithInternalID:(NSString *)internalID description:(NSString *)resourceDescription;

@end

@implementation XMPPMessageCoreDataStorageTransaction (XEP_0066)

- (void)registerOutOfBandResourceForReceivedMessage:(XMPPMessage *)message
{
    [self scheduleStorageUpdateWithBlock:^(XMPPMessageCoreDataStorageObject * _Nonnull messageObject) {
        NSAssert(messageObject.direction == XMPPMessageDirectionIncoming, @"This action is only allowed for incoming message objects");
        [messageObject appendOutOfBandResourceContextWithInternalID:[NSUUID UUID].UUIDString description:[message outOfBandDesc]];
        [messageObject setAssignedOutOfBandResourceURIString:[message outOfBandURI]];
    }];
}

@end

@implementation XMPPMessageCoreDataStorageObject (XEP_0066)

- (nullable NSString *)outOfBandResourceInternalID
{
    return [self lookupInContextWithBlock:^id _Nullable(XMPPMessageContextCoreDataStorageObject * _Nonnull contextElement) {
        return [contextElement stringItemValueForTag:XMPPMessageContextOutOfBandResourceIDTag];
    }];
}

- (nullable NSString *)outOfBandResourceURIString
{
    return [self lookupInContextWithBlock:^id _Nullable(XMPPMessageContextCoreDataStorageObject * _Nonnull contextElement) {
        return [contextElement stringItemValueForTag:XMPPMessageContextOutOfBandResourceURIStringTag];
    }];
}

- (nullable NSString *)outOfBandResourceDescription
{
    return [self lookupInContextWithBlock:^id _Nullable(XMPPMessageContextCoreDataStorageObject * _Nonnull contextElement) {
        return [contextElement stringItemValueForTag:XMPPMessageContextOutOfBandResourceDescriptionTag];
    }];
}

- (void)assignOutOfBandResourceWithInternalID:(NSString *)internalID description:(NSString *)resourceDescription
{
    NSAssert(self.direction == XMPPMessageDirectionOutgoing, @"This action is only allowed for outgoing message objects");
    [self appendOutOfBandResourceContextWithInternalID:internalID description:resourceDescription];
}

- (void)setAssignedOutOfBandResourceURIString:(NSString *)resourceURIString
{
    XMPPMessageContextCoreDataStorageObject *outOfBandResourceContext =
    [self lookupInContextWithBlock:^id _Nullable(XMPPMessageContextCoreDataStorageObject * _Nonnull contextElement) {
        return [contextElement stringItemValueForTag:XMPPMessageContextOutOfBandResourceIDTag] ? contextElement : nil;
    }];
    NSAssert(outOfBandResourceContext, @"No out of band resource is assigned yet");
    NSAssert(![outOfBandResourceContext stringItemValueForTag:XMPPMessageContextOutOfBandResourceURIStringTag], @"Out of band resource URI is already set");
    
    [outOfBandResourceContext appendStringItemWithTag:XMPPMessageContextOutOfBandResourceURIStringTag value:resourceURIString];
}

- (void)appendOutOfBandResourceContextWithInternalID:(NSString *)internalID description:(NSString *)resourceDescription
{
    NSAssert(![self outOfBandResourceInternalID], @"Out of band resource is already assigned");
    
    XMPPMessageContextCoreDataStorageObject *outOfBandResourceContext = [self appendContextElement];
    [outOfBandResourceContext appendStringItemWithTag:XMPPMessageContextOutOfBandResourceIDTag value:internalID];
    if (resourceDescription) {
        [outOfBandResourceContext appendStringItemWithTag:XMPPMessageContextOutOfBandResourceDescriptionTag value:resourceDescription];
    }
}

@end
