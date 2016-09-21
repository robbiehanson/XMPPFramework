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

/** iq stanza for publishing your device ids. The Device IDs are integers between 1 and 2^31 - 1 */
+ (XMPPIQ*) omemo_iqForDeviceIds:(NSArray<NSNumber*>*)deviceIds
                       elementId:(nullable NSString*)elementId;

/** iq stanza for publishing bundle for device */
+ (XMPPIQ*) omemo_iqBundle:(OMEMOBundle*)bundle
                 elementId:(nullable NSString*)elementId;

/** iq stanza for fetching remote bundle */
+ (XMPPIQ*) omemo_iqFetchBundleForDeviceId:(uint32_t)deviceId
                                       jid:(XMPPJID*)jid
                                 elementId:(nullable NSString*)elementId;

/** iq stanza for fetching devices. This should be handled automatically by PEP.
+ (XMPPIQ*) omemo_iqFetchDevices:(XMPPJID *)jid;
*/

- (nullable OMEMOBundle*) omemo_bundle;

@end
NS_ASSUME_NONNULL_END
