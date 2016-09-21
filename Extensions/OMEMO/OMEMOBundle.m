//
//  OMEMOBundle.m
//  Pods
//
//  Created by Chris Ballinger on 9/9/16.
//
//

#import "OMEMOBundle.h"

@implementation OMEMOBundle

- (instancetype) init {
    NSAssert(NO, @"Use designated initializer.");
    return nil;
}

- (instancetype) initWithDeviceId:(uint32_t)deviceId
                      identityKey:(NSData*)identityKey
                     signedPreKey:(OMEMOSignedPreKey*)signedPreKey
                          preKeys:(NSArray<OMEMOPreKey*>*)preKeys {
    if (self = [super init]) {
        _deviceId = deviceId;
        _identityKey = [identityKey copy];
        _signedPreKey = signedPreKey;
        _preKeys = [preKeys copy];
    }
    return self;
}

@end
