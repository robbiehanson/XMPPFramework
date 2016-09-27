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

- (instancetype) initWithOMEMOStorage:(id<OMEMOStorageDelegate>)omemoStorage {
    return [self initWithOMEMOStorage:omemoStorage dispatchQueue:self.moduleQueue];
}

- (instancetype) initWithDispatchQueue:(dispatch_queue_t)queue {
    NSAssert(NO, @"Use designated initializer.");
    return nil;
}

- (instancetype) initWithOMEMOStorage:(id<OMEMOStorageDelegate>)omemoStorage dispatchQueue:(nullable dispatch_queue_t)queue {
    if (self = [super initWithDispatchQueue:queue]) {
        if ([omemoStorage configureWithParent:self queue:moduleQueue]) {
            _omemoStorage = omemoStorage;
        }
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
            OMEMOBundle *myBundle = [self.omemoStorage fetchMyBundle];
            [self addMyDeviceIdToLocalDeviceList:myBundle];
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
    [self performBlock:^{
        NSString *eid = [self fixElementId:elementId];
        XMPPIQ *iq = [XMPPIQ omemo_iqForDeviceIds:deviceIds elementId:eid];
        [self.tracker addElement:iq block:^(XMPPIQ *responseIq, id<XMPPTrackingInfo> info) {
            if (!responseIq || [responseIq isErrorIQ]) {
                // timeout
                XMPPLogWarn(@"publishDeviceIds error: %@ %@", iq, responseIq);
                [multicastDelegate omemo:self failedToPublishDeviceIds:deviceIds errorIq:responseIq outgoingIq:iq];
                return;
            }
            [multicastDelegate omemo:self publishedDeviceIds:deviceIds responseIq:responseIq outgoingIq:iq];
        } timeout:30];
        [xmppStream sendElement:iq];
    }];
}

- (void) publishBundle:(OMEMOBundle*)bundle
             elementId:(nullable NSString*)elementId {
    NSParameterAssert(bundle);
    if (!bundle) { return; }
    [self performBlock:^{
        NSString *eid = [self fixElementId:elementId];
        XMPPIQ *iq = [XMPPIQ omemo_iqBundle:bundle elementId:eid];
        [self.tracker addElement:iq block:^(XMPPIQ *responseIq, id<XMPPTrackingInfo> info) {
            if (!responseIq || [responseIq isErrorIQ]) {
                // timeout
                XMPPLogWarn(@"publishBundle error: %@ %@", iq, responseIq);
                [multicastDelegate omemo:self failedToPublishBundle:bundle errorIq:responseIq outgoingIq:iq];
                return;
            }
            [multicastDelegate omemo:self publishedBundle:bundle responseIq:responseIq outgoingIq:iq];
        } timeout:30];
        [xmppStream sendElement:iq];
    }];
}

- (void) fetchBundleForDeviceId:(uint32_t)deviceId
                            jid:(XMPPJID*)jid
                      elementId:(nullable NSString*)elementId {
    NSParameterAssert(jid);
    if (!jid) { return; }
    [self performBlock:^{
        NSString *eid = [self fixElementId:elementId];
        XMPPIQ *iq = [XMPPIQ omemo_iqFetchBundleForDeviceId:deviceId jid:jid elementId:eid];
        [self.tracker addElement:iq block:^(XMPPIQ *responseIq, id<XMPPTrackingInfo> info) {
            if (!responseIq || [responseIq isErrorIQ]) {
                // timeout
                XMPPLogWarn(@"fetchBundleForDeviceId error: %@ %@", iq, responseIq);
                [multicastDelegate omemo:self failedToFetchBundleForDeviceId:deviceId fromJID:jid errorIq:responseIq outgoingIq:iq];
                return;
            }
            OMEMOBundle *bundle = [responseIq omemo_bundle];
            if (bundle) {
                [multicastDelegate omemo:self fetchedBundle:bundle fromJID:jid responseIq:responseIq outgoingIq:iq];
            } else {
                XMPPLogWarn(@"fetchBundleForDeviceId bundle parsing error: %@ %@", iq, responseIq);
                [multicastDelegate omemo:self failedToFetchBundleForDeviceId:deviceId fromJID:jid errorIq:responseIq outgoingIq:iq];
            }
        } timeout:30];
        [xmppStream sendElement:iq];
    }];
}

- (void) sendKeyData:(NSDictionary<NSNumber*,NSData*>*)keyData
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
        XMPPMessage *message = [XMPPMessage omemo_messageWithKeyData:keyData iv:iv senderDeviceId:myBundle.deviceId toJID:toJID payload:payload elementId:eid];
        [xmppStream sendElement:message];
    }];
}

#pragma mark XMPPStreamDelegate methods

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message {
    
    // Check for incoming device list updates
    NSArray<NSNumber *> *deviceIds = [message omemo_deviceList];
    if (deviceIds.count > 0) {
        // Notify delegates
        [multicastDelegate omemo:self deviceListUpdate:deviceIds fromJID:[message from] message:message];
        // This may temporarily remove your own deviceId until we can update (below)
        [self.omemoStorage storeDeviceIds:deviceIds forJID:[[message from] bare]];
        
        // Check if your device is contained in the update
        if ([[message from] isEqualToJID:xmppStream.myJID options:XMPPJIDCompareBare]) {
            OMEMOBundle *myBundle = [self.omemoStorage fetchMyBundle];
            if (!myBundle) {
                return;
            }
            if([deviceIds containsObject:@(myBundle.deviceId)]) {
                return;
            }
            // Republish deviceIds with your deviceId
            NSArray *appended = [deviceIds arrayByAddingObject:@(myBundle.deviceId)];
            [self.omemoStorage storeDeviceIds:deviceIds forJID:[[message from] bare]];
            [self publishDeviceIds:appended elementId:[[NSUUID UUID] UUIDString]];
        }
        return;
    }
    NSXMLElement *omemo = [message omemo_encryptedElement];
    if (omemo) {
        uint32_t deviceId = [omemo omemo_senderDeviceId];
        NSDictionary<NSNumber*,NSData*>* keyData = [omemo omemo_keyData];
        NSData *iv = [omemo omemo_iv];
        NSData *payload = [omemo omemo_payload];
        if (deviceId > 0 && keyData.count > 0 && iv) {
            [multicastDelegate omemo:self receivedKeyData:keyData iv:iv fromJID:[message from] payload:payload message:message];
        }
    }
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq {
    return [self.tracker invokeForElement:iq withObject:iq];
}

#pragma mark XMPPCapabilitiesDelegate methods

- (NSArray<NSString*>*) myFeaturesForXMPPCapabilities:(XMPPCapabilities *)sender {
    return @[XMLNS_OMEMO_DEVICELIST, XMLNS_OMEMO_DEVICELIST_NOTIFY];
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

- (void) addMyDeviceIdToLocalDeviceList:(OMEMOBundle*)myBundle {
    if (!myBundle) { return; }
    XMPPJID *myJID = xmppStream.myJID;
    NSArray *devices = [self.omemoStorage fetchDeviceIdsForJID:xmppStream.myJID];
    if(devices.count == 0 || [devices containsObject:@(myBundle.deviceId)]) {
        return;
    }
    NSArray *appended = [devices arrayByAddingObject:@(myBundle.deviceId)];
    [self.omemoStorage storeDeviceIds:appended forJID:myJID];
}

@end
