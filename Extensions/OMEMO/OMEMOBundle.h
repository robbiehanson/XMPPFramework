//
//  OMEMOBundle.h
//  Pods
//
//  Created by Chris Ballinger on 9/9/16.
//
//

#import <Foundation/Foundation.h>
#import "OMEMOPreKey.h"
#import "OMEMOSignedPreKey.h"

NS_ASSUME_NONNULL_BEGIN
@interface OMEMOBundle : NSObject

/** The Device ID is a randomly generated integer between 1 and 2^31 - 1 */
@property (nonatomic, readonly) uint32_t deviceId;
/** public part of identity key */
@property (nonatomic, copy, readonly) NSData *identityKey;
@property (nonatomic, strong, readonly) OMEMOSignedPreKey *signedPreKey;
@property (nonatomic, strong, readonly) NSArray<OMEMOPreKey*> *preKeys;

- (instancetype) initWithDeviceId:(uint32_t)deviceId
                      identityKey:(NSData*)identityKey
                     signedPreKey:(OMEMOSignedPreKey*)signedPreKey
                          preKeys:(NSArray<OMEMOPreKey*>*)preKeys NS_DESIGNATED_INITIALIZER;

@end
NS_ASSUME_NONNULL_END
