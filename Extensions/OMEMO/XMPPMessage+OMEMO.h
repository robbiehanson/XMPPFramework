//
//  XMPPMessage+OMEMO.h
//  XMPPFramework
//
//  Created by Chris Ballinger on 4/21/16.
//
//

#import <Foundation/Foundation.h>
#import "XMPPMessage.h"
#import "NSXMLElement+OMEMO.h"

NS_ASSUME_NONNULL_BEGIN
@interface XMPPMessage (OMEMO)

/** Extracts device list from PEP update */
- (nullable NSArray<NSNumber *>*)omemo_deviceList;

/**
 In order to send a chat message, its <body> first has to be encrypted. The client MUST use fresh, randomly generated key/IV pairs with AES-128 in Galois/Counter Mode (GCM). For each intended recipient device, i.e. both own devices as well as devices associated with the contact, this key is encrypted using the corresponding long-standing axolotl session. Each encrypted payload key is tagged with the recipient device's ID. This is all serialized into a MessageElement.
 
 <message to='juliet@capulet.lit' from='romeo@montague.lit' id='send1'>
  <encrypted xmlns='urn:xmpp:omemo:0'>
    <header sid='27183'>
      <key rid='31415'>BASE64ENCODED...</key>
      <key rid='12321'>BASE64ENCODED...</key>
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
+ (XMPPMessage*) omemo_messageWithPayload:(nullable NSData*)payload
                                    toJID:(XMPPJID*)jid
                           deviceId:(uint32_t)deviceId
                            keyData:(NSDictionary<NSNumber*,NSData*>*)keyData
                                 iv:(NSData*)iv
                          elementId:(nullable NSString*)elementId;

@end
NS_ASSUME_NONNULL_END

