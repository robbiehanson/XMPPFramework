//
//  OMEMOKeyData.h
//  XMPPFramework
//
//  Created by Chris Ballinger on 10/10/16.
//
//  XEP-0384: OMEMO Encryption
//  https://xmpp.org/extensions/xep-0384.html
//
//  This specification defines a protocol for end-to-end encryption
//  in one-on-one chats that may have multiple clients per account.

#import <Foundation/Foundation.h>
#import <stdint.h>

NS_ASSUME_NONNULL_BEGIN
@interface OMEMOKeyData : NSObject

@property (nonatomic, readonly, copy) NSData *data;
@property (nonatomic, readonly) uint32_t deviceId;

/** 
 * This propery might be `NO` when using the legacy Converastions
 * namespace because the original draft did not distinguish between
 * PreKeyMessages and OMEMOMessages.
 */
@property (nonatomic, readonly) BOOL isPreKey;

- (instancetype) initWithDeviceId:(uint32_t)deviceId
                             data:(NSData*)data
                         isPreKey:(BOOL)isPreKey NS_DESIGNATED_INITIALIZER;

/** Not available, use designated initializer */
- (instancetype) init NS_UNAVAILABLE;

@end
NS_ASSUME_NONNULL_END
