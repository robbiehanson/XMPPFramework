//
//  OMEMOSignedPreKey.h
//  Pods
//
//  Created by Chris Ballinger on 9/20/16.
//
//

#import "OMEMOPreKey.h"

NS_ASSUME_NONNULL_BEGIN
@interface OMEMOSignedPreKey : OMEMOPreKey

@property (nonatomic, copy, readonly) NSData *signature;

- (instancetype) initWithPreKeyId:(uint32_t)preKeyId
                        publicKey:(NSData*)publicKey
                        signature:(NSData*)signature NS_DESIGNATED_INITIALIZER;

@end
NS_ASSUME_NONNULL_END
