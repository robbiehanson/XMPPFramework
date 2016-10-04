//
//  NSXMLElement+OMEMO.m
//  Pods
//
//  Created by Chris Ballinger on 9/20/16.
//
//

#import "NSXMLElement+OMEMO.h"
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
- (nullable NSDictionary<NSNumber*,NSData*>*) omemo_keyData {
    NSArray<NSXMLElement*> *keys = [[self omemo_headerElement] elementsForName:@"key"];
    if (!keys) { return nil; }
    NSMutableDictionary *keyData = [[NSMutableDictionary alloc] initWithCapacity:keys.count];
    [keys enumerateObjectsUsingBlock:^(NSXMLElement * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        uint32_t rid = [obj attributeUInt32ValueForName:@"rid"];
        NSString *b64 = [obj stringValue];
        NSData *data = nil;
        if (b64) {
            data = [[NSData alloc] initWithBase64EncodedString:b64 options:0];
        }
        if (rid > 0 && data) {
            
            [keyData setObject:data forKey:@(rid)];
        }
    }];
    return [keyData copy];
}
/** Only works within <encrypted> element. <payload>BASE64ENCODED</payload> */
- (nullable NSData*) omemo_payload {
    NSString *b64 = [[self elementForName:@"payload"] stringValue];
    if (!b64) { return nil; }
    return [[NSData alloc] initWithBase64EncodedString:b64 options:0];
}

- (nullable NSData*) omemo_iv {
    NSXMLElement *header = [self omemo_headerElement];
    NSString *iv = [[header elementForName:@"iv"] stringValue];
    if (!iv) { return nil; }
    return [[NSData alloc] initWithBase64EncodedString:iv options:0];
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

+ (NSXMLElement*) omemo_keyTransportElementWithKeyData:(NSDictionary<NSNumber*,NSData*>*)keyData
                                                    iv:(NSData*)iv
                                        senderDeviceId:(uint32_t)senderDeviceId xmlNamespace:(OMEMOModuleNamespace)xmlNamespace {
    NSXMLElement *keyTransportElement = [NSXMLElement elementWithName:@"encrypted" xmlns:[OMEMOModule xmlnsOMEMO:xmlNamespace]];
    NSXMLElement *headerElement = [NSXMLElement elementWithName:@"header"];
    [headerElement addAttributeWithName:@"sid" unsignedIntegerValue:senderDeviceId];
    [keyData enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull key, NSData * _Nonnull obj, BOOL * _Nonnull stop) {
        NSXMLElement *keyElement = [NSXMLElement elementWithName:@"key" stringValue:[obj base64EncodedStringWithOptions:0]];
        [keyElement addAttributeWithName:@"rid" numberValue:key];
        [headerElement addChild:keyElement];
    }];
    NSXMLElement *ivElement = [NSXMLElement elementWithName:@"iv" stringValue:[iv base64EncodedStringWithOptions:0]];
    [headerElement addChild:ivElement];
    [keyTransportElement addChild:headerElement];
    return keyTransportElement;
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
    }
    return nil;
}

@end
