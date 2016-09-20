//
//  OMEMOBundle.m
//  Pods
//
//  Created by Chris Ballinger on 9/9/16.
//
//

#import "OMEMOBundle.h"

@implementation OMEMOBundle

- (instancetype) initWithDeviceId:(NSNumber*)deviceId
                      identityKey:(NSData*)identityKey
                     signedPreKey:(NSData*)signedPreKey
                   signedPreKeyId:(NSNumber*)signedPreKeyId
            signedPreKeySignature:(NSData*)signedPreKeySignature
                          preKeys:(NSDictionary<NSNumber*,NSData*>*)preKeys {
    if (self = [super init]) {
        _deviceId = deviceId;
        _identityKey = identityKey;
        _signedPreKey = signedPreKey;
        _signedPreKeyId = signedPreKeyId;
        _signedPreKeySignature = signedPreKeySignature;
        _preKeys = preKeys;
    }
    return self;
}

@end
