//
//  OMEMOModule.m
//  Pods
//
//  Created by Chris Ballinger on 4/21/16.
//
//

#import "OMEMOModule.h"
#import "XMPPPubSub.h"
#import "XMPPIQ+XEP_0060.h"
#import "XMPPIQ+OMEMO.h"
#import "XMPPMessage+OMEMO.h"
#import "XMPPIDTracker.h"
#import "XMPPLogging.h"
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
    NSParameterAssert(deviceIds.count > 0);
    if (!deviceIds.count) { return; }
    __weak typeof(self) weakSelf = self;
    __weak id weakMulticast = multicastDelegate;
    [self performBlock:^{
        NSString *eid = [self fixElementId:elementId];
        XMPPIQ *iq = [XMPPIQ omemo_iqPublishDeviceIds:deviceIds elementId:eid xmlNamespace:self.xmlNamespace];
        [self.tracker addElement:iq block:^(XMPPIQ *responseIq, id<XMPPTrackingInfo> info) {
            if (!responseIq || [responseIq isErrorIQ]) {
                // timeout
                XMPPLogWarn(@"publishDeviceIds error: %@ %@", iq, responseIq);
                [weakMulticast omemo:weakSelf failedToPublishDeviceIds:deviceIds errorIq:responseIq outgoingIq:iq];
                return;
            }
            [weakMulticast omemo:weakSelf publishedDeviceIds:deviceIds responseIq:responseIq outgoingIq:iq];
        } timeout:30];
        [xmppStream sendElement:iq];
    }];
}

/** For fetching. This should be handled automatically by PEP. */
- (void) fetchDeviceIdsForJID:(XMPPJID*)jid
                    elementId:(nullable NSString*)elementId {
    NSParameterAssert(jid != nil);
    if (!jid) { return; }
    __weak typeof(self) weakSelf = self;
    __weak id weakMulticast = multicastDelegate;
    [self performBlock:^{
        NSString *eid = [self fixElementId:elementId];
        XMPPIQ *iq = [XMPPIQ omemo_iqFetchDeviceIdsForJID:jid elementId:eid xmlNamespace:self.xmlNamespace];
        [self.tracker addElement:iq block:^(XMPPIQ *responseIq, id<XMPPTrackingInfo> info) {
            if (!responseIq || [responseIq isErrorIQ]) {
                // timeout
                XMPPLogWarn(@"fetchDeviceIdsForJID error: %@ %@", iq, responseIq);
                [weakMulticast omemo:weakSelf failedToFetchDeviceIdsForJID:jid errorIq:responseIq outgoingIq:iq];
                return;
            }
            /*
<iq xmlns="jabber:client" id="AEA43C1D-DA7D-448F-8F41-268D1A14FF3F" type="result" to="test@example.com/b9038fb3-0575-47bf-b8bb-cd1073f972c6" from="conversations@example.com">
<pubsub xmlns="http://jabber.org/protocol/pubsub">
    <items node="eu.siacs.conversations.axolotl.devicelist">
        <item id="1">
            <list xmlns="eu.siacs.conversations.axolotl">
                <device id="1259777401"/>
            </list>
        </item>
    </items>
</pubsub>
</iq>
             */
            NSXMLElement *pubsub = [responseIq elementForName:@"pubsub" xmlns:XMLNS_PUBSUB];
            if (!pubsub) {
                XMPPLogWarn(@"Missing pubsub element: %@ %@", iq, responseIq);
            }
            NSXMLElement *items = [pubsub elementForName:@"items"];
            if (!items) {
                XMPPLogWarn(@"Missing items element: %@ %@", iq, responseIq);
            }
            NSArray<NSNumber *> *devices = [items omemo_deviceListFromItems:self.xmlNamespace];
            if (!devices) {
                devices = @[];
                XMPPLogWarn(@"Missing devices from element: %@ %@", iq, responseIq);
            }
            
            XMPPJID *bareJID = [[responseIq from] bareJID];
            [weakMulticast omemo:weakSelf deviceListUpdate:devices fromJID:bareJID incomingElement:responseIq];
            [weakSelf processIncomingDeviceIds:devices fromJID:bareJID];
        } timeout:30];
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
            if (!responseIq || [responseIq isErrorIQ]) {
                // timeout
                XMPPLogWarn(@"publishBundle error: %@ %@", iq, responseIq);
                [weakMulticast omemo:weakSelf failedToPublishBundle:bundle errorIq:responseIq outgoingIq:iq];
                return;
            }
            [weakMulticast omemo:weakSelf publishedBundle:bundle responseIq:responseIq outgoingIq:iq];
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
        XMPPIQ *iq = [XMPPIQ omemo_iqFetchBundleForDeviceId:deviceId jid:jid elementId:eid xmlNamespace:self.xmlNamespace];
        [self.tracker addElement:iq block:^(XMPPIQ *responseIq, id<XMPPTrackingInfo> info) {
            if (!responseIq || [responseIq isErrorIQ]) {
                // timeout
                XMPPLogWarn(@"fetchBundleForDeviceId error: %@ %@", iq, responseIq);
                [weakMulticast omemo:weakSelf failedToFetchBundleForDeviceId:deviceId fromJID:jid errorIq:responseIq outgoingIq:iq];
                return;
            }
            OMEMOBundle *bundle = [responseIq omemo_bundle:self.xmlNamespace];
            if (bundle) {
                [weakMulticast omemo:weakSelf fetchedBundle:bundle fromJID:jid responseIq:responseIq outgoingIq:iq];
            } else {
                XMPPLogWarn(@"fetchBundleForDeviceId bundle parsing error: %@ %@", iq, responseIq);
                [weakMulticast omemo:weakSelf failedToFetchBundleForDeviceId:deviceId fromJID:jid errorIq:responseIq outgoingIq:iq];
            }
        } timeout:30];
        [xmppStream sendElement:iq];
    }];
}


- (void) removeBundleForDevice:(uint32_t)deviceId elementId:(NSString *)elementId {
    __weak typeof(self) weakSelf = self;
    __weak id weakMulticast = multicastDelegate;
    [self performBlock:^{
        NSString *eid = [weakSelf fixElementId:elementId];
        XMPPIQ *iq = [XMPPIQ omemo_iqRemoveBundleForDeviceId:deviceId elementId:eid xmlNamespace:self.xmlNamespace];
        [self.tracker addElement:iq block:^(XMPPIQ *responseIq, id<XMPPTrackingInfo> info) {
            if (!responseIq || [responseIq isErrorIQ]) {
                // timeout
                XMPPLogWarn(@"removeBundleForDevice error: %@ %@", iq, responseIq);
                [weakMulticast omemo:weakSelf failedToRemoveBundleId:deviceId errorIq:responseIq outgoingIq:iq];
                return;
            } else {
                [weakMulticast omemo:weakSelf removedBundleId:deviceId responseIq:responseIq outgoingIq:iq];
            }
        } timeout:30];
        [xmppStream sendElement:iq];
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
    NSXMLElement *omemo = [message omemo_encryptedElement:self.xmlNamespace];
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
