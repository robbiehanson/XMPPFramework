//
//  OMEMOBundle.h
//  Pods
//
//  Created by Chris Ballinger on 9/9/16.
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface OMEMOBundle : NSObject

@property (nonatomic, strong, readonly) NSNumber *deviceId;
@property (nonatomic, strong, readonly) NSData *identityKey;
@property (nonatomic, strong, readonly) NSData *signedPreKey;
@property (nonatomic, strong, readonly) NSNumber *signedPreKeyId;
@property (nonatomic, strong, readonly) NSData *signedPreKeySignature;
@property (nonatomic, strong, readonly) NSDictionary<NSNumber*,NSData*> *preKeys;

- (instancetype) initWithDeviceId:(NSNumber*)deviceId
                      identityKey:(NSData*)identityKey
                     signedPreKey:(NSData*)signedPreKey
                   signedPreKeyId:(NSNumber*)signedPreKeyId
            signedPreKeySignature:(NSData*)signedPreKeySignature
                          preKeys:(NSDictionary<NSNumber*,NSData*>*)preKeys;

@end
NS_ASSUME_NONNULL_END