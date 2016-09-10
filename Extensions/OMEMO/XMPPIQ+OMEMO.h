//
//  XMPPIQ+OMEMO.h
//  XMPPFramework
//
//  Created by Chris Ballinger on 4/21/16.
//
//

#import <Foundation/Foundation.h>
#import "XMPPIQ.h"

NS_ASSUME_NONNULL_BEGIN
@interface XMPPIQ (OMEMO)

/** iq stanza for publishing your device ids */
+ (XMPPIQ*) omemo_iqForDeviceIds:(NSArray<NSNumber*>*)deviceIds;

/** iq stanza for publishing bundle for device */
+ (XMPPIQ*) omemo_iqBundleForDevice:(NSNumber*)deviceId
                        identityKey:(NSString*)identityKey
                       signedPreKey:(nullable NSString*)signedPreKey
                     signedPreKeyId:(nullable NSNumber*)signedPreKeyId
              signedPreKeySignature:(nullable NSString*)signedPreKeySignature
                            preKeys:(NSDictionary<NSNumber*,NSString*>*)preKeys;

/** iq stanza for fetching remote bundle */
+ (XMPPIQ*) omemo_iqfetchBundleForDevice:(NSNumber*)deviceId
                                     jid:(XMPPJID*)jid;

/** iq stanza for feetching devices */
+ (XMPPIQ*) omemo_iqfetchDevices:(XMPPJID *)jid;


@end
NS_ASSUME_NONNULL_END