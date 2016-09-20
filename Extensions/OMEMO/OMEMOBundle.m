//
//  OMEMOBundle.m
//  Pods
//
//  Created by Chris Ballinger on 9/9/16.
//
//

#import "OMEMOBundle.h"

@implementation OMEMOBundle

- (instancetype) initWithDeviceId:(uint32_t)deviceId
                      identityKey:(NSData*)identityKey
                     signedPreKey:(OMEMOSignedPreKey*)signedPreKey
                          preKeys:(NSArray<OMEMOPreKey*>*)preKeys {
    if (self = [super init]) {
        _deviceId = deviceId;
        _identityKey = [identityKey copy];
        _signedPreKey = signedPreKey;
        _preKeys = preKeys;
    }
    return self;
}

@end
