//
//  OMEMOPreKey.h
//  Pods
//
//  Created by Chris Ballinger on 9/20/16.
//
//  XEP-0384: OMEMO Encryption
//  https://xmpp.org/extensions/xep-0384.html
//
//  This specification defines a protocol for end-to-end encryption
//  in one-on-one chats that may have multiple clients per account.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface OMEMOPreKey : NSObject

@property (nonatomic, readonly) uint32_t preKeyId;
@property (nonatomic, copy, readonly) NSData *publicKey;

- (instancetype) initWithPreKeyId:(uint32_t)preKeyId
                        publicKey:(NSData*)publicKey NS_DESIGNATED_INITIALIZER;

/** Not available, use designated initializer */
- (instancetype) init NS_UNAVAILABLE;

- (BOOL) isEqualToPreKey:(OMEMOPreKey*)preKey;

@end
NS_ASSUME_NONNULL_END
