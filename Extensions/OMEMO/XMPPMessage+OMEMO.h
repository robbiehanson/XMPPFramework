//
//  XMPPMessage+OMEMO.h
//  XMPPFramework
//
//  Created by Chris Ballinger on 4/21/16.
//
//

#import <Foundation/Foundation.h>
#import "XMPPMessage.h"

NS_ASSUME_NONNULL_BEGIN
@interface XMPPMessage (OMEMO)


- (nullable NSArray<NSNumber *>*)omemo_deviceList;

/**
 In order to send a chat message, its <body> first has to be encrypted. The client MUST use fresh, randomly generated key/IV pairs with AES-128 in Galois/Counter Mode (GCM). For each intended recipient device, i.e. both own devices as well as devices associated with the contact, this key is encrypted using the corresponding long-standing axolotl session. Each encrypted payload key is tagged with the recipient device's ID. This is all serialized into a MessageElement.
 
 If payload is nil, this message will contain a KeyTransportElement.
 */
+ (XMPPMessage*) omemo_messageToJID:(XMPPJID*)jid
                          elementID:(NSString*)eid
                           deviceId:(NSNumber*)deviceId
                 receivingDeviceIds:(NSDictionary<NSNumber*,NSString*>*)receivingDeviceIds
                                 iv:(NSString*)iv
                            payload:(nullable NSString*)payload;

@end
NS_ASSUME_NONNULL_END

NS_ASSUME_NONNULL_BEGIN
@interface NSXMLElement (OMEMO)

/**
 * The client may wish to transmit keying material to the contact. This first has to be generated. The client MUST generate a fresh, randomly generated key/IV pair. For each intended recipient device, i.e. both own devices as well as devices associated with the contact, this key is encrypted using the corresponding long-standing axolotl session. Each encrypted payload key is tagged with the recipient device's ID. This is all serialized into a KeyTransportElement, omitting the <payload>.
 */

+ (NSXMLElement*) omemo_keyTransportElementForDeviceId:(NSNumber*)deviceId
                 receivingDeviceIds:(NSDictionary<NSNumber*,NSString*>*)receivingDeviceIds
                                 iv:(NSString*)iv;

@end
NS_ASSUME_NONNULL_END