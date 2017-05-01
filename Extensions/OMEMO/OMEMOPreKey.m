//
//  OMEMOPreKey.m
//  Pods
//
//  Created by Chris Ballinger on 9/20/16.
//
//  XEP-0384: OMEMO Encryption
//  https://xmpp.org/extensions/xep-0384.html
//
//  This specification defines a protocol for end-to-end encryption
//  in one-on-one chats that may have multiple clients per account.

#import "OMEMOPreKey.h"

@implementation OMEMOPreKey

- (instancetype) init {
    NSAssert(NO, @"Use designated initializer.");
    return nil;
}

- (instancetype) initWithPreKeyId:(uint32_t)preKeyId
                        publicKey:(NSData*)publicKey {
    if (self = [super init]) {
        _preKeyId = preKeyId;
        _publicKey = [publicKey copy];
    }
    return self;
}

- (BOOL) isEqual:(id)object {
    if ([object isKindOfClass:[OMEMOPreKey class]]) {
        return [self isEqualToPreKey:object];
    }
    return NO;
}

- (BOOL) isEqualToPreKey:(OMEMOPreKey*)preKey {
    return self.preKeyId == preKey.preKeyId &&
    [self.publicKey isEqualToData:preKey.publicKey];
}

@end
