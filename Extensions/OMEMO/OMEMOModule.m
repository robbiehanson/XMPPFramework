//
//  OMEMOModule.m
//  XMPPFramework
//
//  Created by Chris Ballinger on 4/21/16.
//
//  XEP-0384: OMEMO Encryption
//  https://xmpp.org/extensions/xep-0384.html
//
//  This specification defines a protocol for end-to-end encryption
//  in one-on-one chats that may have multiple clients per account.

#import "OMEMOModule.h"
#import "XMPPPubSub.h"
#import "XMPPIQ+XEP_0060.h"
#import "XMPPIQ+OMEMO.h"
#import "XMPPMessage+OMEMO.h"
#import "XMPPIDTracker.h"
#import "XMPPLogging.h"
#import "XMPPMessage+XEP_0280.h"

static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;

@interface OMEMOModule()
@property (nonatomic, strong, readonly) XMPPIDTracker *tracker;
@end

@implementation OMEMOModule

#pragma mark Init

- (instancetype) init {
    NSAssert(NO, @"Use designated initializer.");
    return nil;
}

- (instancetype) initWithOMEMOStorage:(id<OMEMOStorageDelegate>)omemoStorage xmlNamespace:(OMEMOModuleNamespace)xmlNamespace {
    return [self initWithOMEMOStorage:omemoStorage xmlNamespace:xmlNamespace dispatchQueue:self.moduleQueue];
}

- (instancetype) initWithDispatchQueue:(dispatch_queue_t)queue {
    NSAssert(NO, @"Use designated initializer.");
    return nil;
}

- (instancetype) initWithOMEMOStorage:(id<OMEMOStorageDelegate>)omemoStorage xmlNamespace:(OMEMOModuleNamespace)xmlNamespace dispatchQueue:(nullable dispatch_queue_t)queue {
    if (self = [super initWithDispatchQueue:queue]) {
        if ([omemoStorage configureWithParent:self queue:moduleQueue]) {
            _omemoStorage = omemoStorage;
        }
        _xmlNamespace = xmlNamespace;
    }
    return self;
}

- (BOOL)activate:(XMPPStream *)aXmppStream
{
    if ([super activate:aXmppStream])
    {
        [self performBlock:^{
            [xmppStream autoAddDelegate:self delegateQueue:moduleQueue toModulesOfClass:[XMPPCapabilities class]];
            _tracker = [[XMPPIDTracker alloc] initWithStream:aXmppStream dispatchQueue:moduleQueue];
        }];
        return YES;
    }
    
    return NO;
}

- (void) deactivate {
    [self performBlock:^{
        [_tracker removeAllIDs];
        _tracker = nil;
        [xmppStream removeAutoDelegate:self delegateQueue:moduleQueue fromModulesOfClass:[XMPPCapabilities class]];
    }];
    [super deactivate];
}

#pragma mark Public methods


- (void) publishDeviceIds:(NSArray<NSNumber*>*)deviceIds elementId:(nullable NSString*)elementId {
    __weak typeof(self) weakSelf = self;
    __weak id weakMulticast = multicastDelegate;
    [self performBlock:^{
        NSString *eid = [self fixElementId:elementId];
        XMPPIQ *iq = [XMPPIQ omemo_iqPublishDeviceIds:deviceIds elementId:eid xmlNamespace:self.xmlNamespace];
        [self.tracker addElement:iq block:^(XMPPIQ *responseIq, id<XMPPTrackingInfo> info) {
            __typeof__(self) strongSelf = weakSelf;
            if (!strongSelf) { return; }
            if (!responseIq || [responseIq isErrorIQ]) {
                // timeout
                XMPPLogWarn(@"publishDeviceIds error: %@ %@", iq, responseIq);
                [weakMulticast omemo:strongSelf failedToPublishDeviceIds:deviceIds errorIq:responseIq outgoingIq:iq];
                return;
            }
            [weakMulticast omemo:strongSelf publishedDeviceIds:deviceIds responseIq:responseIq outgoingIq:iq];
        } timeout:30];
        [xmppStream sendElement:iq];
    }];
}

/** For fetching. This should be handled automatically by PEP. */
- (void) fetchDeviceIdsForJID:(XMPPJID*)jid
                    elementId:(nullable NSString*)elementId {
    NSParameterAssert(jid != nil);
    if (!jid) { return; }
    __block BOOL isOurJID = [self.xmppStream.myJID isEqualToJID:jid options:XMPPJIDCompareBare];
    [self fetchDeviceIdsForJID:jid elementId:elementId completion:^(XMPPIQ *responseIq, id<XMPPTrackingInfo> info) {
        // If we get an error response and this is our jid then we should process as if it's an empty device list.
        if ((!responseIq || [responseIq isErrorIQ]) && !isOurJID) {
            // timeout
            XMPPLogWarn(@"fetchDeviceIdsForJID error: %@ %@", info.element, responseIq);
            [multicastDelegate omemo:self failedToFetchDeviceIdsForJID:jid errorIq:responseIq outgoingIq:(XMPPIQ*)info.element];
            return;
        }
        
        NSArray<NSNumber *> *devices = [responseIq omemo_deviceListFromIqResponse:self.xmlNamespace];
        if (!devices) {
            devices = @[];
            XMPPLogWarn(@"Missing devices from element: %@ %@", info.element, responseIq);
        }
        
        XMPPJID *bareJID = [[responseIq from] bareJID];
        if (bareJID == nil) {
            // Normal iq responses to have a from attribute. Getting the from attrirbute from the outgoing to attribute.
            // Should always be the account bare jid.
            bareJID = [[[info element] to] bareJID];
        }
        [multicastDelegate omemo:self deviceListUpdate:devices fromJID:bareJID incomingElement:responseIq];
        [self processIncomingDeviceIds:devices fromJID:bareJID];
    }];
}

- (void) fetchDeviceIdsForJID:(nonnull XMPPJID*)jid
                    elementId:(nullable NSString*)elementId
                   completion:(void (^_Nonnull)(XMPPIQ *responseIq, id<XMPPTrackingInfo> info))completion {
    [self performBlock:^{
        NSString *eid = [self fixElementId:elementId];
        XMPPIQ *iq = [XMPPIQ omemo_iqFetchDeviceIdsForJID:jid elementId:eid xmlNamespace:self.xmlNamespace];
        [self.tracker addElement:iq block:completion timeout:30];
        [xmppStream sendElement:iq];
    }];
}

- (void) publishBundle:(OMEMOBundle*)bundle
             elementId:(nullable NSString*)elementId {
    NSParameterAssert(bundle);
    if (!bundle) { return; }
    __weak typeof(self) weakSelf = self;
    __weak id weakMulticast = multicastDelegate;
    [self performBlock:^{
        NSString *eid = [self fixElementId:elementId];
        XMPPIQ *iq = [XMPPIQ omemo_iqPublishBundle:bundle elementId:eid xmlNamespace:self.xmlNamespace];
        [self.tracker addElement:iq block:^(XMPPIQ *responseIq, id<XMPPTrackingInfo> info) {
            __typeof__(self) strongSelf = weakSelf;
            if (!strongSelf) { return; }
            if (!responseIq || [responseIq isErrorIQ]) {
                // timeout
                XMPPLogWarn(@"publishBundle error: %@ %@", iq, responseIq);
                [weakMulticast omemo:strongSelf failedToPublishBundle:bundle errorIq:responseIq outgoingIq:iq];
                return;
            }
            [weakMulticast omemo:strongSelf publishedBundle:bundle responseIq:responseIq outgoingIq:iq];
        } timeout:30];
        [xmppStream sendElement:iq];
    }];
}


- (void) fetchBundleForDeviceId:(uint32_t)deviceId
                            jid:(XMPPJID*)jid
                      elementId:(nullable NSString*)elementId {
    NSParameterAssert(jid);
    if (!jid) { return; }
    __weak typeof(self) weakSelf = self;
    __weak id weakMulticast = multicastDelegate;
    [self performBlock:^{
        NSString *eid = [self fixElementId:elementId];
        XMPPIQ *iq = [XMPPIQ omemo_iqFetchBundleForDeviceId:deviceId jid:jid.bareJID elementId:eid xmlNamespace:self.xmlNamespace];
        [self.tracker addElement:iq block:^(XMPPIQ *responseIq, id<XMPPTrackingInfo> info) {
            __typeof__(self) strongSelf = weakSelf;
            if (!strongSelf) { return; }
            if (!responseIq || [responseIq isErrorIQ]) {
                // timeout
                XMPPLogWarn(@"fetchBundleForDeviceId error: %@ %@", iq, responseIq);
                [weakMulticast omemo:strongSelf failedToFetchBundleForDeviceId:deviceId fromJID:jid errorIq:responseIq outgoingIq:iq];
                return;
            }
            OMEMOBundle *bundle = [responseIq omemo_bundle:strongSelf.xmlNamespace];
            if (bundle) {
                [weakMulticast omemo:strongSelf fetchedBundle:bundle fromJID:jid responseIq:responseIq outgoingIq:iq];
            } else {
                XMPPLogWarn(@"fetchBundleForDeviceId bundle parsing error: %@ %@", iq, responseIq);
                [weakMulticast omemo:strongSelf failedToFetchBundleForDeviceId:deviceId fromJID:jid errorIq:responseIq outgoingIq:iq];
            }
        } timeout:30];
        [xmppStream sendElement:iq];
    }];
}

//All the different delegates that can happend. And you can't remove your self unless change delegate callback on bundle
- (void) removeDeviceIds:(NSArray<NSNumber*>*)deviceIds elementId:(NSString *)elementId {
    __weak typeof(self) weakSelf = self;
    __weak id weakMulticast = multicastDelegate;
    [self performBlock:^{
        [self fetchDeviceIdsForJID:self.xmppStream.myJID elementId:nil completion:^(XMPPIQ *responseIq, id<XMPPTrackingInfo> info) {
            __typeof__(self) strongSelf = weakSelf;
            if (!strongSelf) { return; }
            if (!responseIq || [responseIq isErrorIQ]) {
                // timeout
                XMPPLogWarn(@"fetchDeviceIdsForJID error: %@ %@", info.element, responseIq);
                [weakMulticast omemo:strongSelf failedToRemoveDeviceIds:deviceIds errorIq:responseIq elementId:elementId];
                return;
            }
            
            NSArray<NSNumber *> *devices = [responseIq omemo_deviceListFromIqResponse:strongSelf.xmlNamespace];
            NSIndexSet *indexSet = [devices indexesOfObjectsPassingTest:^BOOL(NSNumber * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                return [deviceIds containsObject:obj];
            }];
            NSMutableArray<NSNumber *> *mutableDevices = [devices mutableCopy];
            // Remove devices
            [mutableDevices removeObjectsAtIndexes:indexSet];
            //publish new list of devices
            [strongSelf publishDeviceIds:[mutableDevices copy] elementId:elementId];
        }];
    }];
}

- (void) sendKeyData:(NSArray<OMEMOKeyData*>*)keyData
                  iv:(NSData*)iv
               toJID:(XMPPJID*)toJID
             payload:(nullable NSData*)payload
           elementId:(nullable NSString*)elementId {
    NSParameterAssert(keyData.count > 0);
    NSParameterAssert(iv.length > 0);
    NSParameterAssert(toJID != nil);
    if (!keyData.count || !iv.length || !toJID) {
        return;
    }
    [self performBlock:^{
        OMEMOBundle *myBundle = [self.omemoStorage fetchMyBundle];
        if (!myBundle) {
            XMPPLogWarn(@"sendKeyData: could not fetch my bundle");
            return;
        }
        NSString *eid = [self fixElementId:elementId];
        XMPPMessage *message = [XMPPMessage omemo_messageWithKeyData:keyData iv:iv senderDeviceId:myBundle.deviceId toJID:toJID payload:payload elementId:eid xmlNamespace:self.xmlNamespace];
        [xmppStream sendElement:message];
    }];
}



#pragma mark Namespace methods

+ (NSString*) xmlnsOMEMO:(OMEMOModuleNamespace)ns {
    if (ns == OMEMOModuleNamespaceOMEMO) {
        return @"urn:xmpp:omemo:0";
    } else { // OMEMOModuleNamespaceConversationsLegacy
        return @"eu.siacs.conversations.axolotl";
    }
}
+ (NSString*) xmlnsOMEMODeviceList:(OMEMOModuleNamespace)ns {
    NSString *xmlns = [self xmlnsOMEMO:ns];
    if (ns == OMEMOModuleNamespaceOMEMO) {
        return [NSString stringWithFormat:@"%@:devicelist", xmlns];
    } else { // OMEMOModuleNamespaceConversationsLegacy
        return [NSString stringWithFormat:@"%@.devicelist", xmlns];
    }
}
+ (NSString*) xmlnsOMEMODeviceListNotify:(OMEMOModuleNamespace)ns {
    return [NSString stringWithFormat:@"%@+notify", [self xmlnsOMEMODeviceList:ns]];
}
+ (NSString*) xmlnsOMEMOBundles:(OMEMOModuleNamespace)ns {
    NSString *xmlns = [self xmlnsOMEMO:ns];
    if (ns == OMEMOModuleNamespaceOMEMO) {
        xmlns = [NSString stringWithFormat:@"%@:bundles", xmlns];
    } else { // OMEMOModuleNamespaceConversationsLegacy
        xmlns = [NSString stringWithFormat:@"%@.bundles", xmlns];
    }
    NSParameterAssert(xmlns != nil);
    return xmlns;
}

+ (NSString*) xmlnsOMEMOBundles:(OMEMOModuleNamespace)ns deviceId:(uint32_t)deviceId {
    return [NSString stringWithFormat:@"%@:%d", [self xmlnsOMEMOBundles:ns], (int)deviceId];
}

#pragma mark XMPPStreamDelegate methods

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender {
    OMEMOBundle *myBundle = [self.omemoStorage fetchMyBundle];
    [self fetchDeviceIdsForJID:sender.myJID elementId:nil];
    [self publishBundle:myBundle elementId:nil];
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message {
    // Check for incoming device list updates
    NSArray<NSNumber *> *deviceIds = [message omemo_deviceListFromPEPUpdate:self.xmlNamespace];
    XMPPJID *bareJID = [[message from] bareJID];
    if (deviceIds) {
        [multicastDelegate omemo:self deviceListUpdate:deviceIds fromJID:bareJID incomingElement:message];
        [self processIncomingDeviceIds:deviceIds fromJID:bareJID];
        return;
    }
    
    XMPPMessage *possibleOMEMOMessage = message;
    if ([message isMessageCarbon]) {
        possibleOMEMOMessage = [message messageCarbonForwardedMessage];
    }
    
    NSXMLElement *omemo = [possibleOMEMOMessage omemo_encryptedElement:self.xmlNamespace];
    if (omemo) {
        uint32_t deviceId = [omemo omemo_senderDeviceId];
        NSArray<OMEMOKeyData*>* keyData = [omemo omemo_keyData];
        NSData *iv = [omemo omemo_iv];
        NSData *payload = [omemo omemo_payload];
        if (deviceId > 0 && keyData.count > 0 && iv) {
            [multicastDelegate omemo:self receivedKeyData:keyData iv:iv senderDeviceId:deviceId fromJID:bareJID payload:payload message:message];
        }
    }
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq {
    BOOL success = NO;
    if (!iq.from) {
        // Some error responses for self or contacts don't have a "from"
        success = [self.tracker invokeForID:iq.elementID withObject:iq];
    } else {
        success = [self.tracker invokeForElement:iq withObject:iq];
    }
    //DDLogWarn(@"Could not match IQ: %@", iq);
    return success;
}

#pragma mark XMPPCapabilitiesDelegate methods

- (NSArray<NSString*>*) myFeaturesForXMPPCapabilities:(XMPPCapabilities *)sender {
    return @[[[self class] xmlnsOMEMODeviceList:self.xmlNamespace], [[self class] xmlnsOMEMODeviceListNotify:self.xmlNamespace]];
}

#pragma mark Utility

/** Executes block on moduleQueue */
- (void) performBlock:(dispatch_block_t)block {
    if (dispatch_get_specific(moduleQueueTag))
        block();
    else
        dispatch_sync(moduleQueue, block);
}

/** Generate elementId UUID if needed */
- (nonnull NSString*) fixElementId:(nullable NSString*)elementId {
    NSString *eid = nil;
    if (!elementId.length) {
        eid = [[NSUUID UUID] UUIDString];
    } else {
        eid = [elementId copy];
    }
    return eid;
}

- (void) processIncomingDeviceIds:(NSArray<NSNumber*>*)deviceIds fromJID:(XMPPJID*)fromJID {
    NSParameterAssert(fromJID != nil);
    NSParameterAssert(deviceIds != nil);
    if (!fromJID || !deviceIds) {
        return;
    }
    fromJID = [fromJID bareJID];
    // This may temporarily remove your own deviceId until we can update (below)
    [self.omemoStorage storeDeviceIds:deviceIds forJID:fromJID];
    
    // Check if your device is contained in the update
    if ([fromJID isEqualToJID:xmppStream.myJID options:XMPPJIDCompareBare]) {
        OMEMOBundle *myBundle = [self.omemoStorage fetchMyBundle];
        if (!myBundle) {
            return;
        }
        if([deviceIds containsObject:@(myBundle.deviceId)]) {
            return;
        }
        // Republish deviceIds with your deviceId
        NSArray *appended = [deviceIds arrayByAddingObject:@(myBundle.deviceId)];
        [self.omemoStorage storeDeviceIds:appended forJID:fromJID];
        [self publishDeviceIds:appended elementId:[[NSUUID UUID] UUIDString]];
    }

}

@end
