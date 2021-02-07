//
//  OMEMOTestStorage.m
//  XMPPFrameworkTests
//
//  Created by Christopher Ballinger on 9/23/16.
//
//

#import "OMEMOTestStorage.h"
@import XMPPFramework;
@import KissXML;

@interface OMEMOTestStorage()
@property (nonatomic, strong, readonly) NSMutableDictionary <XMPPJID*,NSArray<NSNumber*>*> *deviceIdStorage;
@end

@implementation OMEMOTestStorage

- (instancetype) initWithMyBundle:(OMEMOBundle*)myBundle {
    NSParameterAssert(myBundle != nil);
    if (self = [super init]) {
        _myBundle = myBundle;
        _deviceIdStorage = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark OMEMOStorageDelegate

- (BOOL)configureWithParent:(OMEMOModule *)aParent queue:(dispatch_queue_t)queue {
    _omemoModule = aParent;
    return YES;
}

- (void)storeDeviceIds:(NSArray<NSNumber*>*)deviceIds forJID:(XMPPJID*)jid {
    NSParameterAssert(deviceIds != nil);
    NSParameterAssert(jid != nil);
    if (!deviceIds || !jid) { return; }
    [self.deviceIdStorage setObject:deviceIds forKey:jid];
}

- (NSArray<NSNumber*>*)fetchDeviceIdsForJID:(XMPPJID*)jid {
    NSParameterAssert(jid != nil);
    if (!jid) { return @[]; }
    NSArray *deviceIds = [self.deviceIdStorage objectForKey:jid];
    if (!deviceIds) {
        deviceIds = @[];
    }
    return deviceIds;
}

/** This should return your fully populated bundle with >= 100 prekeys */
- (OMEMOBundle*)fetchMyBundle {
    return self.myBundle;
}

/** Normally this should check if your session is actually valid. Here we just see if the deviceId exists in storage. */
- (BOOL) isSessionValid:(XMPPJID*)jid deviceId:(uint32_t)deviceId {
    NSArray<NSNumber*> *deviceIds = [self.deviceIdStorage objectForKey:jid];
    return [deviceIds containsObject:@(deviceId)];
}

#pragma mark Utility

+ (XMPPIQ*) iq_SetBundleWithEid:(NSString*)eid xmlNamespace:(OMEMOModuleNamespace)xmlNamespace {
    NSXMLElement *inner = [self innerBundleElement:xmlNamespace];
    XMPPIQ *setIq = [XMPPIQ iqWithType:@"set" elementID:eid child:inner];
    return setIq;
}

+ (XMPPIQ*) iq_resultBundleFromJID:(XMPPJID*)fromJID eid:(NSString*)eid xmlNamespace:(OMEMOModuleNamespace)xmlNamespace {
    NSXMLElement *inner = [self innerBundleElement:xmlNamespace];
    XMPPIQ *iq = [self iq_testIQFromJID:fromJID eid:eid type:@"result"];
    [iq addChild:inner];
    return iq;
}

+ (XMPPIQ*) iq_errorFromJID:(XMPPJID*)fromJID eid:(NSString*)eid {
    return [self iq_testIQFromJID:fromJID eid:eid type:@"error"];
}

+ (XMPPIQ*) iq_testIQFromJID:(XMPPJID*)fromJID eid:(NSString*)eid type:(NSString*)type {
    NSString *expectedString = @" \
    <iq> \
    </iq> \
    ";
    NSXMLElement *element = [[NSXMLElement alloc] initWithXMLString:expectedString error:nil];
    if (eid) {
        [element addAttributeWithName:@"id" stringValue:eid];
    }
    if (type) {
        [element addAttributeWithName:@"type" stringValue:type];
    }
    if (fromJID) {
        [element addAttributeWithName:@"from" stringValue:[fromJID full]];
    }
    XMPPIQ *iq = [XMPPIQ iqFromElement:element];
    return iq;
}

+ (NSXMLElement*)innerBundleElement:(OMEMOModuleNamespace)ns {

    NSString *expectedString = [NSString stringWithFormat:@" \
    <pubsub xmlns='http://jabber.org/protocol/pubsub'> \
    <items node='%@:31415'> \
    <item> \
    <bundle xmlns='%@'> \
    <signedPreKeyPublic signedPreKeyId='1'>c2lnbmVkUHJlS2V5UHVibGlj</signedPreKeyPublic> \
    <signedPreKeySignature>c2lnbmVkUHJlS2V5U2lnbmF0dXJl</signedPreKeySignature> \
    <identityKey>aWRlbnRpdHlLZXk=</identityKey> \
    <prekeys> \
    <preKeyPublic preKeyId='1'>cHJlS2V5MQ==</preKeyPublic> \
    <preKeyPublic preKeyId='2'>cHJlS2V5Mg==</preKeyPublic> \
    <preKeyPublic preKeyId='3'>cHJlS2V5Mw==</preKeyPublic> \
    </prekeys> \
    </bundle> \
    </item> \
    </items> \
    </pubsub> \
    ", [OMEMOModule xmlnsOMEMODeviceList:ns], [OMEMOModule xmlnsOMEMO:ns]];

    NSXMLElement *element = [[NSXMLElement alloc] initWithXMLString:expectedString error:nil];
    return element;
}

+ (OMEMOBundle*) testBundle:(OMEMOModuleNamespace)ns {
    [self innerBundleElement:ns];
    OMEMOBundle *bundle = [[self iq_SetBundleWithEid:@"announce1" xmlNamespace:ns] omemo_bundle:ns];
    return bundle;
}




@end
