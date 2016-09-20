//
//  OMEMOPreKey.h
//  Pods
//
//  Created by Chris Ballinger on 9/20/16.
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface OMEMOPreKey : NSObject

@property (nonatomic, readonly) uint32_t preKeyId;
@property (nonatomic, copy, readonly) NSData *publicKey;

- (instancetype) initWithPreKeyId:(uint32_t)preKeyId
                        publicKey:(NSData*)publicKey NS_DESIGNATED_INITIALIZER;

@end
NS_ASSUME_NONNULL_END
