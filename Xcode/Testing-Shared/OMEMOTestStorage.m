//
//  OMEMOTestStorage.m
//  XMPPFrameworkTests
//
//  Created by Christopher Ballinger on 9/23/16.
//
//

#import "OMEMOTestStorage.h"

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


@end
