//
//  NSXMLElement+OMEMO.m
//  XMPPFramework
//
//  Created by Chris Ballinger on 9/20/16.
//
//  XEP-0384: OMEMO Encryption
//  https://xmpp.org/extensions/xep-0384.html
//
//  This specification defines a protocol for end-to-end encryption
//  in one-on-one chats that may have multiple clients per account.

#import "NSXMLElement+OMEMO.h"
#import "XMPPIQ+XEP_0060.h"
#import "OMEMOModule.h"

@implementation NSXMLElement (OMEMO)

/** If element contains <encrypted xmlns='urn:xmpp:omemo:0'> */
- (BOOL) omemo_hasEncryptedElement:(OMEMOModuleNamespace)ns {
    return [self omemo_encryptedElement:ns] != nil;
}

/** If element IS <encrypted xmlns='urn:xmpp:omemo:0'> */
- (BOOL) omemo_isEncryptedElement:(OMEMOModuleNamespace)ns {
    return [[self name] isEqualToString:@"encrypted"] && [[self xmlns] isEqualToString:[OMEMOModule xmlnsOMEMO:ns]];
}

/** Child element <encrypted xmlns='urn:xmpp:omemo:0'> */
- (nullable NSXMLElement*) omemo_encryptedElement:(OMEMOModuleNamespace)ns {
    return [self elementForName:@"encrypted" xmlns:[OMEMOModule xmlnsOMEMO:ns]];
}

- (NSXMLElement*) omemo_headerElement {
    return [self elementForName:@"header"];
}

/** The Device ID is a randomly generated integer between 1 and 2^31 - 1. If zero it means the element was not found. Only works within <encrypted> element. <header sid='27183'> */
- (uint32_t) omemo_senderDeviceId {
    return [[self omemo_headerElement] attributeUInt32ValueForName:@"sid"];
}

/** key data is keyed to receiver deviceIds. Only works within <encrypted> element.  <key rid='31415'>BASE64ENCODED...</key> .. */
- (nullable NSArray<OMEMOKeyData*>*) omemo_keyData {
    NSArray<NSXMLElement*> *keys = [[self omemo_headerElement] elementsForName:@"key"];
    if (!keys) { return nil; }
    NSMutableArray *keyDataArray = [[NSMutableArray alloc] initWithCapacity:keys.count];
    [keys enumerateObjectsUsingBlock:^(NSXMLElement * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        uint32_t rid = [obj attributeUInt32ValueForName:@"rid"];
        NSString *b64 = [obj stringValue];
        NSData *data = nil;
        if (b64) {
            data = [[NSData alloc] initWithBase64EncodedString:b64 options:NSDataBase64DecodingIgnoreUnknownCharacters];
        }
        BOOL isPreKey = [obj attributeBoolValueForName:@"prekey"];
        if (rid > 0 && data) {
            OMEMOKeyData *keyData = [[OMEMOKeyData alloc] initWithDeviceId:rid data:data isPreKey:isPreKey];
            [keyDataArray addObject:keyData];
        }
    }];
    return [keyDataArray copy];
}
/** Only works within <encrypted> element. <payload>BASE64ENCODED</payload> */
- (nullable NSData*) omemo_payload {
    NSString *b64 = [[self elementForName:@"payload"] stringValue];
    if (!b64) { return nil; }
    return [[NSData alloc] initWithBase64EncodedString:b64 options:NSDataBase64DecodingIgnoreUnknownCharacters];
}

- (nullable NSData*) omemo_iv {
    NSXMLElement *header = [self omemo_headerElement];
    NSString *iv = [[header elementForName:@"iv"] stringValue];
    if (!iv) { return nil; }
    return [[NSData alloc] initWithBase64EncodedString:iv options:NSDataBase64DecodingIgnoreUnknownCharacters];
}


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

+ (NSXMLElement*) omemo_keyTransportElementWithKeyData:(NSArray<OMEMOKeyData*>*)keyData
                                                    iv:(NSData*)iv
                                        senderDeviceId:(uint32_t)senderDeviceId xmlNamespace:(OMEMOModuleNamespace)xmlNamespace {
    NSXMLElement *keyTransportElement = [NSXMLElement elementWithName:@"encrypted" xmlns:[OMEMOModule xmlnsOMEMO:xmlNamespace]];
    NSXMLElement *headerElement = [NSXMLElement elementWithName:@"header"];
    [headerElement addAttributeWithName:@"sid" unsignedIntegerValue:senderDeviceId];

    [keyData enumerateObjectsUsingBlock:^(OMEMOKeyData * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSXMLElement *keyElement = [NSXMLElement elementWithName:@"key" stringValue:[obj.data base64EncodedStringWithOptions:0]];
        [keyElement addAttributeWithName:@"rid" unsignedIntegerValue:obj.deviceId];
        if (obj.isPreKey) {
            [keyElement addAttributeWithName:@"prekey" boolValue:YES];
        }
        [headerElement addChild:keyElement];
    }];
    NSXMLElement *ivElement = [NSXMLElement elementWithName:@"iv" stringValue:[iv base64EncodedStringWithOptions:0]];
    [headerElement addChild:ivElement];
    [keyTransportElement addChild:headerElement];
    return keyTransportElement;
}

/*
 <iq xmlns="jabber:client" id="AEA43C1D-DA7D-448F-8F41-268D1A14FF3F" type="result" to="test@example.com/b9038fb3-0575-47bf-b8bb-cd1073f972c6" from="conversations@example.com">
    <pubsub xmlns="http://jabber.org/protocol/pubsub">
        <items node="eu.siacs.conversations.axolotl.devicelist">
            <item id="1">
                <list xmlns="eu.siacs.conversations.axolotl">
                    <device id="1259777401"/>
                </list>
            </item>
        </items>
    </pubsub>
 </iq>
 */
- (nullable NSArray<NSNumber *>*)omemo_deviceListFromIqResponse:(OMEMOModuleNamespace)ns {
    NSXMLElement *pubsub = [self elementForName:@"pubsub" xmlns:XMLNS_PUBSUB];
    NSXMLElement *items = [pubsub elementForName:@"items"];
    return [items omemo_deviceListFromItems:ns];
}

- (nullable NSArray<NSNumber *>*)omemo_deviceListFromItems:(OMEMOModuleNamespace)ns {
    if ([[self attributeStringValueForName:@"node"] isEqualToString:[OMEMOModule xmlnsOMEMODeviceList:ns]]) {
        NSXMLElement * devicesList = [[self elementForName:@"item"] elementForName:@"list" xmlns:[OMEMOModule xmlnsOMEMO:ns]];
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
        return @[];
    }
    return nil;
}

@end
