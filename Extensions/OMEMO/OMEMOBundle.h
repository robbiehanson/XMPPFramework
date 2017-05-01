//
//  OMEMOBundle.h
//  XMPPFramework
//
//  Created by Chris Ballinger on 9/9/16.
//
//  XEP-0384: OMEMO Encryption
//  https://xmpp.org/extensions/xep-0384.html
//
//  This specification defines a protocol for end-to-end encryption
//  in one-on-one chats that may have multiple clients per account.

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
@property (nonatomic, copy, readonly) NSArray<OMEMOPreKey*> *preKeys;

- (instancetype) initWithDeviceId:(uint32_t)deviceId
                      identityKey:(NSData*)identityKey
                     signedPreKey:(OMEMOSignedPreKey*)signedPreKey
                          preKeys:(NSArray<OMEMOPreKey*>*)preKeys NS_DESIGNATED_INITIALIZER;

/** Not available, use designated initializer */
- (instancetype) init NS_UNAVAILABLE;

- (BOOL) isEqualToBundle:(OMEMOBundle*)bundle;

@end
NS_ASSUME_NONNULL_END
