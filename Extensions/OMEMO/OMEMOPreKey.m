//
//  OMEMOPreKey.m
//  Pods
//
//  Created by Chris Ballinger on 9/20/16.
//
//

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

@end
