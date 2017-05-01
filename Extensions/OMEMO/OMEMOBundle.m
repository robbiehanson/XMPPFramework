//
//  OMEMOBundle.m
//  XMPPFramework
//
//  Created by Chris Ballinger on 9/9/16.
//
//  XEP-0384: OMEMO Encryption
//  https://xmpp.org/extensions/xep-0384.html
//
//  This specification defines a protocol for end-to-end encryption
//  in one-on-one chats that may have multiple clients per account.

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

- (BOOL) isEqual:(id)object {
    if ([object isKindOfClass:[OMEMOBundle class]]) {
        return [self isEqualToBundle:object];
    }
    return NO;
}

- (BOOL) isEqualToBundle:(OMEMOBundle*)bundle {
    return self.deviceId == bundle.deviceId &&
    [self.identityKey isEqualToData:bundle.identityKey] &&
    [self.signedPreKey isEqualToSignedPreKey:bundle.signedPreKey] &&
    [self.preKeys isEqualToArray:bundle.preKeys];
}

@end
