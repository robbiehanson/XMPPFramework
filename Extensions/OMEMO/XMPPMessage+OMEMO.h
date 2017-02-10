//
//  XMPPMessage+OMEMO.h
//  XMPPFramework
//
//  Created by Chris Ballinger on 4/21/16.
//
//  XEP-0384: OMEMO Encryption
//  https://xmpp.org/extensions/xep-0384.html
//
//  This specification defines a protocol for end-to-end encryption
//  in one-on-one chats that may have multiple clients per account.

#import <Foundation/Foundation.h>
#import "XMPPMessage.h"
#import "NSXMLElement+OMEMO.h"

NS_ASSUME_NONNULL_BEGIN
@interface XMPPMessage (OMEMO)

/** Extracts device list from PEP update */
- (nullable NSArray<NSNumber *>*)omemo_deviceListFromPEPUpdate:(OMEMOModuleNamespace)ns;

/**
 In order to send a chat message, its <body> first has to be encrypted. The client MUST use fresh, randomly generated key/IV pairs with AES-128 in Galois/Counter Mode (GCM). For each intended recipient device, i.e. both own devices as well as devices associated with the contact, this key is encrypted using the corresponding long-standing axolotl session. Each encrypted payload key is tagged with the recipient device's ID. This is all serialized into a MessageElement.
 
 <message to='juliet@capulet.lit' from='romeo@montague.lit' id='send1'>
  <encrypted xmlns='urn:xmpp:omemo:0'>
    <header sid='27183'>
      <key rid='31415'>BASE64ENCODED...</key>
      <key prekey="true" rid='12321'>BASE64ENCODED...</key>
      <!-- ... -->
      <iv>BASE64ENCODED...</iv>
    </header>
    <payload>BASE64ENCODED</payload>
  </encrypted>
  <store xmlns='urn:xmpp:hints'/>
</message>
 
 If payload is nil, this message will contain a KeyTransportElement.
 
 keyData is keyed to the receiving deviceIds
 */
+ (XMPPMessage*) omemo_messageWithKeyData:(NSArray<OMEMOKeyData*>*)keyData
                                       iv:(NSData*)iv
                           senderDeviceId:(uint32_t)senderDeviceId
                                    toJID:(XMPPJID*)toJID
                                  payload:(nullable NSData*)payload
                                elementId:(nullable NSString*)elementId
                             xmlNamespace:(OMEMOModuleNamespace)xmlNamespace;

@end
NS_ASSUME_NONNULL_END

