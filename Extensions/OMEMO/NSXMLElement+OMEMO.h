//
//  NSXMLElement+OMEMO.h
//  Pods
//
//  Created by Chris Ballinger on 9/20/16.
//
//

#import <Foundation/Foundation.h>
#import "NSXMLElement+XMPP.h"

NS_ASSUME_NONNULL_BEGIN
@interface NSXMLElement (OMEMO)

/** If element contains <encrypted xmlns='urn:xmpp:omemo:0'> */
- (BOOL) omemo_hasEncryptedElement;
/** If element IS <encrypted xmlns='urn:xmpp:omemo:0'> */
- (BOOL) omemo_isEncryptedElement;
/** Child element <encrypted xmlns='urn:xmpp:omemo:0'> */
- (nullable NSXMLElement*) omemo_encryptedElement;


/** The Device ID is a randomly generated integer between 1 and 2^31 - 1. If zero it means the element was not found. Only works within <encrypted> element. <header sid='27183'> */
- (uint32_t) omemo_senderDeviceId;
/** key data is keyed to receiver deviceIds. Only works within <encrypted> element.  <key rid='31415'>BASE64ENCODED...</key> .. */
- (nullable NSDictionary<NSNumber*,NSData*>*) omemo_keyData;
/** Only works within <encrypted> element. <payload>BASE64ENCODED</payload> */
- (nullable NSData*) omemo_payload;


/**
 * The client may wish to transmit keying material to the contact. This first has to be generated. The client MUST generate a fresh, randomly generated key/IV pair. For each intended recipient device, i.e. both own devices as well as devices associated with the contact, this key is encrypted using the corresponding long-standing axolotl session. Each encrypted payload key is tagged with the recipient device's ID. This is all serialized into a KeyTransportElement, omitting the <payload>.
 
 <encrypted xmlns='urn:xmpp:omemo:0'>
 <header sid='27183'>
 <key rid='31415'>BASE64ENCODED...</key>
 <key rid='12321'>BASE64ENCODED...</key>
 <!-- ... -->
 <iv>BASE64ENCODED...</iv>
 </header>
 </encrypted>
 */

+ (NSXMLElement*) omemo_keyTransportElementForDeviceId:(uint32_t)deviceId
                                               keyData:(NSDictionary<NSNumber*,NSData*>*)keyData
                                                    iv:(NSData*)iv;



@end
NS_ASSUME_NONNULL_END
