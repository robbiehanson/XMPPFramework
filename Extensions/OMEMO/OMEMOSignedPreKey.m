//
//  OMEMOSignedPreKey.m
//  Pods
//
//  Created by Chris Ballinger on 9/20/16.
//
//

#import "OMEMOSignedPreKey.h"

@implementation OMEMOSignedPreKey

- (instancetype) initWithPreKeyId:(uint32_t)preKeyId
                        publicKey:(NSData*)publicKey {
    NSAssert(NO, @"Use designated initializer.");
    return nil;
}

- (instancetype) initWithPreKeyId:(uint32_t)preKeyId
                        publicKey:(NSData*)publicKey
                        signature:(NSData*)signature {
    if (self = [super initWithPreKeyId:preKeyId publicKey:publicKey]) {
        _signature = [signature copy];
    }
    return self;
}

@end
