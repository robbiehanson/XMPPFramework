//
//  OMEMOKeyData.h
//  Pods
//
//  Created by Chris Ballinger on 10/10/16.
//
//

#import <Foundation/Foundation.h>
#import <stdint.h>

NS_ASSUME_NONNULL_BEGIN
@interface OMEMOKeyData : NSObject

@property (nonatomic, readonly, copy) NSData *data;
@property (nonatomic, readonly) uint32_t deviceId;

- (instancetype) initWithDeviceId:(uint32_t)deviceId
                             data:(NSData*)data NS_DESIGNATED_INITIALIZER;

/** Not available, use designated initializer */
- (instancetype) init NS_UNAVAILABLE;

@end
NS_ASSUME_NONNULL_END
