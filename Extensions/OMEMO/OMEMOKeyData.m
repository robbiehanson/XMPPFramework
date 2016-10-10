//
//  OMEMOKeyData.m
//  Pods
//
//  Created by Chris Ballinger on 10/10/16.
//
//

#import "OMEMOKeyData.h"

@implementation OMEMOKeyData

- (instancetype) init {
    NSAssert(NO, @"Use designated initializer.");
    return nil;
}

- (instancetype) initWithDeviceId:(uint32_t)deviceId
                             data:(NSData*)data {
    NSParameterAssert(deviceId != 0);
    NSParameterAssert(data.length > 0);
    if (self = [super init]) {
        _deviceId = deviceId;
        _data = [data copy];
    }
    return self;
}

@end
