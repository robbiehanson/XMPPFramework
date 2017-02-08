//
//  OMEMOKeyData.m
//  XMPPFramework
//
//  Created by Chris Ballinger on 10/10/16.
//
//  XEP-0384: OMEMO Encryption
//  https://xmpp.org/extensions/xep-0384.html
//
//  This specification defines a protocol for end-to-end encryption
//  in one-on-one chats that may have multiple clients per account.

#import "OMEMOKeyData.h"

@implementation OMEMOKeyData

- (instancetype) init {
    NSAssert(NO, @"Use designated initializer.");
    return nil;
}

- (instancetype) initWithDeviceId:(uint32_t)deviceId
                             data:(NSData*)data
                         isPreKey:(BOOL)isPreKey {
    NSParameterAssert(deviceId != 0);
    NSParameterAssert(data.length > 0);
    if (self = [super init]) {
        _deviceId = deviceId;
        _data = [data copy];
        _isPreKey = isPreKey;
    }
    return self;
}

@end
