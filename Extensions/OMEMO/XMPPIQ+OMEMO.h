//
//  XMPPIQ+OMEMO.h
//  XMPPFramework
//
//  Created by Chris Ballinger on 4/21/16.
//
//

#import <Foundation/Foundation.h>
#import "XMPPIQ.h"
#import "OMEMOBundle.h"

NS_ASSUME_NONNULL_BEGIN
@interface XMPPIQ (OMEMO)

/** iq stanza for publishing your device ids */
+ (XMPPIQ*) omemo_iqForDeviceIds:(NSArray<NSNumber*>*)deviceIds
                       elementId:(nullable NSString*)elementId;

/** iq stanza for publishing bundle for device */
+ (XMPPIQ*) omemo_iqBundle:(OMEMOBundle*)bundle
                 elementId:(nullable NSString*)elementId;

/** iq stanza for fetching remote bundle */
+ (XMPPIQ*) omemo_iqfetchBundleForDevice:(NSNumber*)deviceId
                                     jid:(XMPPJID*)jid;

/** iq stanza for feetching devices */
+ (XMPPIQ*) omemo_iqfetchDevices:(XMPPJID *)jid;


@end
NS_ASSUME_NONNULL_END
