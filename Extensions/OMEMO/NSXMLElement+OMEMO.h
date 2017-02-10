//
//  NSXMLElement+OMEMO.h
//  XMPPFramework
//
//  Created by Chris Ballinger on 9/20/16.
//
//  XEP-0384: OMEMO Encryption
//  https://xmpp.org/extensions/xep-0384.html
//
//  This specification defines a protocol for end-to-end encryption
//  in one-on-one chats that may have multiple clients per account.

#import <Foundation/Foundation.h>
#import "NSXMLElement+XMPP.h"
#import "OMEMOModule.h"

NS_ASSUME_NONNULL_BEGIN
@interface NSXMLElement (OMEMO)

/** If element contains <encrypted xmlns='urn:xmpp:omemo:0'> */
- (BOOL) omemo_hasEncryptedElement:(OMEMOModuleNamespace)ns;
/** If element IS <encrypted xmlns='urn:xmpp:omemo:0'> */
- (BOOL) omemo_isEncryptedElement:(OMEMOModuleNamespace)ns;
/** Child element <encrypted xmlns='urn:xmpp:omemo:0'> */
- (nullable NSXMLElement*) omemo_encryptedElement:(OMEMOModuleNamespace)ns;


/** The Device ID is a randomly generated integer between 1 and 2^31 - 1. If zero it means the element was not found. Only works within <encrypted> element. <header sid='27183'> */
- (uint32_t) omemo_senderDeviceId;
/** key data is keyed to receiver deviceIds. Only works within <encrypted> element.  <key rid='31415'>BASE64ENCODED...</key> .. */
- (nullable NSArray<OMEMOKeyData*>*) omemo_keyData;
/** Only works within <encrypted> element. <payload>BASE64ENCODED</payload> */
- (nullable NSData*) omemo_payload;
/** Encryption IV. Only works within <encrypted> element. <iv>BASE64ENCODED</iv> */
- (nullable NSData*) omemo_iv;


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

+ (NSXMLElement*) omemo_keyTransportElementWithKeyData:(NSArray<OMEMOKeyData*>*)keyData
                                                    iv:(NSData*)iv
                                        senderDeviceId:(uint32_t)senderDeviceId
                                          xmlNamespace:(OMEMOModuleNamespace)xmlNamespace;


/** Extracts device list from PEP <items> element */
- (nullable NSArray<NSNumber *>*)omemo_deviceListFromItems:(OMEMOModuleNamespace)ns;
/** Extracts device list from PEP iq respnse */
- (nullable NSArray<NSNumber *>*)omemo_deviceListFromIqResponse:(OMEMOModuleNamespace)ns;


@end
NS_ASSUME_NONNULL_END
