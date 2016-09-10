//
//  XMPPMessage+OMEMO.m
//  XMPPFramework
//
//  Created by Chris Ballinger on 4/21/16.
//
//

#import <Foundation/Foundation.h>
#import "XMPPMessage+OMEMO.h"
#import "OMEMOModule.h"
#import "XMPPMessage+XEP_0334.h"
#import "NSXMLElement+XMPP.h"

@implementation XMPPMessage (OMEMO)

- (nullable NSArray<NSNumber *>*)omemo_deviceList
{
    NSXMLElement * itemsList = [[self elementForName:@"event" xmlns:@"http://jabber.org/protocol/pubsub#event"] elementForName:@"items"];
    if ([[itemsList attributeStringValueForName:@"node"] isEqualToString:@"urn:xmpp:omemo:0:devicelist"]) {
        NSXMLElement * devicesList = [[itemsList elementForName:@"item"] elementForName:@"list" xmlns:@"urn:xmpp:omemo:0"];
        if (devicesList) {
            NSArray *children = [devicesList children];
            NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:children.count];
            [children enumerateObjectsUsingBlock:^(NSXMLElement * _Nonnull node, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([node.name isEqualToString:@"device"]) {
                    NSNumber *number = [node attributeNumberUInt32ValueForName:@"id"];
                    if (number){
                        [result addObject:number];
                    }
                }
            }];
            return result;
        }
    }
    
    return nil;
}

/**
 In order to send a chat message, its <body> first has to be encrypted. The client MUST use fresh, randomly generated key/IV pairs with AES-128 in Galois/Counter Mode (GCM). For each intended recipient device, i.e. both own devices as well as devices associated with the contact, this key is encrypted using the corresponding long-standing axolotl session. Each encrypted payload key is tagged with the recipient device's ID. This is all serialized into a MessageElement, which is transmitted in a <message> as follows:
 
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
 */

+ (XMPPMessage*) omemo_messageToJID:(XMPPJID*)jid
                          elementID:(NSString*)eid
                           deviceId:(NSNumber*)deviceId
                 receivingDeviceIds:(NSDictionary<NSNumber*,NSString*>*)receivingDeviceIds
                                 iv:(NSString*)iv
                            payload:(NSString*)payload {
    NSXMLElement *encryptedElement = [NSXMLElement omemo_keyTransportElementForDeviceId:deviceId receivingDeviceIds:receivingDeviceIds iv:iv];
    if (payload) {
        NSXMLElement *payloadElement = [NSXMLElement elementWithName:@"payload" stringValue:payload];
        [encryptedElement addChild:payloadElement];
    }
    XMPPMessage *messageElement = [XMPPMessage messageWithType:nil to:jid elementID:eid];
    [messageElement addStorageHint:XMPPMessageStorageStore];
    [messageElement addChild:encryptedElement];
    return messageElement;
}

@end


@implementation NSXMLElement (OMEMO)

/**
 * The client may wish to transmit keying material to the contact. This first has to be generated. The client MUST generate a fresh, randomly generated key/IV pair. For each intended recipient device, i.e. both own devices as well as devices associated with the contact, this key is encrypted using the corresponding long-standing axolotl session. Each encrypted payload key is tagged with the recipient device's ID. This is all serialized into a KeyTransportElement, omitting the <payload> as follows:
 
<encrypted xmlns='urn:xmpp:omemo:0'>
  <header sid='27183'>
    <key rid='31415'>BASE64ENCODED...</key>
    <key rid='12321'>BASE64ENCODED...</key>
    <!-- ... -->
    <iv>BASE64ENCODED...</iv>
  </header>
</encrypted>
 */

+ (NSXMLElement*) omemo_keyTransportElementForDeviceId:(NSNumber*)deviceId
                                    receivingDeviceIds:(NSDictionary<NSNumber*,NSString*>*)receivingDeviceIds
                                                    iv:(NSString*)iv {
    NSXMLElement *keyTransportElement = [NSXMLElement elementWithName:@"encrypted" xmlns:XMLNS_OMEMO];
    NSXMLElement *headerElement = [NSXMLElement elementWithName:@"header"];
    [receivingDeviceIds enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
        NSXMLElement *keyElement = [NSXMLElement elementWithName:@"key" stringValue:obj];
        [keyElement addAttributeWithName:@"rid" numberValue:key];
        [headerElement addChild:keyElement];
    }];
    NSXMLElement *ivElement = [NSXMLElement elementWithName:@"iv" stringValue:iv];
    [headerElement addChild:ivElement];
    [keyTransportElement addChild:headerElement];
    return keyTransportElement;
}

@end