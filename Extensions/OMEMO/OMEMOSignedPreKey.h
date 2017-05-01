//
//  OMEMOSignedPreKey.h
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

NS_ASSUME_NONNULL_BEGIN
@interface OMEMOSignedPreKey : OMEMOPreKey

@property (nonatomic, copy, readonly) NSData *signature;

- (instancetype) initWithPreKeyId:(uint32_t)preKeyId
                        publicKey:(NSData*)publicKey
                        signature:(NSData*)signature NS_DESIGNATED_INITIALIZER;

/** Not available, use designated initializer */
- (instancetype) initWithPreKeyId:(uint32_t)preKeyId
                        publicKey:(NSData*)publicKey NS_UNAVAILABLE;

- (BOOL) isEqualToSignedPreKey:(OMEMOSignedPreKey*)signedPreKey;

@end
NS_ASSUME_NONNULL_END
