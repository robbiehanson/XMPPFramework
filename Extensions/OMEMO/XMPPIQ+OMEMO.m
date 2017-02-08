//
//  XMPPIQ+OMEMO.m
//  XMPPFramework
//
//  Created by Chris Ballinger on 4/21/16.
//
//  XEP-0384: OMEMO Encryption
//  https://xmpp.org/extensions/xep-0384.html
//
//  This specification defines a protocol for end-to-end encryption
//  in one-on-one chats that may have multiple clients per account.

#import "XMPPIQ+OMEMO.h"
#import "XMPPIQ+XEP_0060.h"
#import "OMEMOModule.h"

@implementation XMPPIQ (OMEMO)


/**
    <iq to='juliet@capulet.lit' type='get' id='fetch1'>
      <pubsub xmlns='http://jabber.org/protocol/pubsub'>
        <items node='urn:xmpp:omemo:0:devicelist'/>
      </pubsub>
    </iq>
 */
+ (XMPPIQ*) omemo_iqFetchDeviceIdsForJID:(XMPPJID*)jid
                               elementId:(nullable NSString*)elementId
                            xmlNamespace:(OMEMOModuleNamespace)xmlNamespace {
    NSXMLElement *items = [NSXMLElement elementWithName:@"items"];
    [items addAttributeWithName:@"node" stringValue:[OMEMOModule xmlnsOMEMODeviceList:xmlNamespace]];
    NSXMLElement *pubsub = [NSXMLElement elementWithName:@"pubsub" xmlns:XMLNS_PUBSUB];
    [pubsub addChild:items];
    
    XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:jid.bareJID elementID:elementId];
    [iq addChild:pubsub];
    return iq;
}


/**
    <iq from='juliet@capulet.lit' type='set' id='announce1'>
      <pubsub xmlns='http://jabber.org/protocol/pubsub'>
        <publish node='urn:xmpp:omemo:0:devicelist'>
          <item>
            <list xmlns='urn:xmpp:omemo:0'>
              <device id='12345' />
              <device id='4223' />
              <device id='31415' />
            </list>
          </item>
        </publish>
      </pubsub>
    </iq>
 */
+ (XMPPIQ*) omemo_iqPublishDeviceIds:(NSArray<NSNumber*>*)deviceIds elementId:(nullable NSString*)elementId xmlNamespace:(OMEMOModuleNamespace)xmlNamespace {
    NSXMLElement *listElement = [NSXMLElement elementWithName:@"list" xmlns:[OMEMOModule xmlnsOMEMO:xmlNamespace]];
    [deviceIds enumerateObjectsUsingBlock:^(NSNumber * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSXMLElement *device = [NSXMLElement elementWithName:@"device"];
        [device addAttributeWithName:@"id" numberValue:obj];
        [listElement addChild:device];
    }];
    
    NSXMLElement *item = [NSXMLElement elementWithName:@"item"];
    [item addChild:listElement];
    
    NSXMLElement *publish = [NSXMLElement elementWithName:@"publish"];
    [publish addAttributeWithName:@"node" stringValue:[OMEMOModule xmlnsOMEMODeviceList:xmlNamespace]];
    [publish addChild:item];
    
    NSXMLElement *pubsub = [NSXMLElement elementWithName:@"pubsub" xmlns:XMLNS_PUBSUB];
    [pubsub addChild:publish];
    
    XMPPIQ *iq = [XMPPIQ iqWithType:@"set" elementID:elementId];
    [iq addChild:pubsub];
    
    return iq;
}

/** iq stanza for publishing bundle for device 
 
 <iq from='juliet@capulet.lit' type='set' id='announce2'>
  <pubsub xmlns='http://jabber.org/protocol/pubsub'>
    <publish node='urn:xmpp:omemo:0:bundles:31415'>
      <item>
        <bundle xmlns='urn:xmpp:omemo:0'>
          <signedPreKeyPublic signedPreKeyId='1'>
            BASE64ENCODED...
          </signedPreKeyPublic>
          <signedPreKeySignature>
            BASE64ENCODED...
          </signedPreKeySignature>
          <identityKey>
            BASE64ENCODED...
          </identityKey>
          <prekeys>
            <preKeyPublic preKeyId='1'>
              BASE64ENCODED...
            </preKeyPublic>
            <preKeyPublic preKeyId='2'>
              BASE64ENCODED...
            </preKeyPublic>
            <preKeyPublic preKeyId='3'>
              BASE64ENCODED...
            </preKeyPublic>
            <!-- ... -->
          </prekeys>
        </bundle>
      </item>
    </publish>
  </pubsub>
</iq>
 
 */
+ (XMPPIQ*) omemo_iqPublishBundle:(OMEMOBundle*)bundle
                 elementId:(nullable NSString*)elementId
                     xmlNamespace:(OMEMOModuleNamespace)xmlNamespace {
    NSXMLElement *signedPreKeyElement = nil;
    if (bundle.signedPreKey.publicKey) {
        signedPreKeyElement = [NSXMLElement elementWithName:@"signedPreKeyPublic" stringValue:[bundle.signedPreKey.publicKey base64EncodedStringWithOptions:0]];
        [signedPreKeyElement addAttributeWithName:@"signedPreKeyId" unsignedIntegerValue:bundle.signedPreKey.preKeyId];
    }
    NSXMLElement *signedPreKeySignatureElement = nil;
    if (bundle.signedPreKey.signature) {
        signedPreKeySignatureElement = [NSXMLElement elementWithName:@"signedPreKeySignature" stringValue:[bundle.signedPreKey.signature base64EncodedStringWithOptions:0]];
    }
    NSXMLElement *identityKeyElement = nil;
    if (bundle.identityKey) {
        identityKeyElement = [NSXMLElement elementWithName:@"identityKey" stringValue:[bundle.identityKey base64EncodedStringWithOptions:0]];
    }
    NSXMLElement *preKeysElement = [NSXMLElement elementWithName:@"prekeys"];
    [bundle.preKeys enumerateObjectsUsingBlock:^(OMEMOPreKey * _Nonnull preKey, NSUInteger idx, BOOL * _Nonnull stop) {
        NSXMLElement *preKeyElement = [NSXMLElement elementWithName:@"preKeyPublic" stringValue:[preKey.publicKey base64EncodedStringWithOptions:0]];
        [preKeyElement addAttributeWithName:@"preKeyId" unsignedIntegerValue:preKey.preKeyId];
        [preKeysElement addChild:preKeyElement];
    }];
    NSXMLElement *bundleElement = [XMPPElement elementWithName:@"bundle" xmlns:[OMEMOModule xmlnsOMEMO:xmlNamespace]];
    if (signedPreKeyElement) {
        [bundleElement addChild:signedPreKeyElement];
    }
    if (signedPreKeySignatureElement) {
        [bundleElement addChild:signedPreKeySignatureElement];
    }
    if (identityKeyElement) {
        [bundleElement addChild:identityKeyElement];
    }
    [bundleElement addChild:preKeysElement];
    NSXMLElement *itemElement = [NSXMLElement elementWithName:@"item"];
    [itemElement addChild:bundleElement];
    
    NSXMLElement *publish = [NSXMLElement elementWithName:@"publish"];
    NSString *nodeName = [OMEMOModule xmlnsOMEMOBundles:xmlNamespace deviceId:bundle.deviceId];
    [publish addAttributeWithName:@"node" stringValue:nodeName];
    [publish addChild:itemElement];
    
    NSXMLElement *pubsub = [NSXMLElement elementWithName:@"pubsub" xmlns:XMLNS_PUBSUB];
    [pubsub addChild:publish];
    
    XMPPIQ *iq = [XMPPIQ iqWithType:@"set" elementID:elementId];
    [iq addChild:pubsub];
    return iq;
}


+ (XMPPIQ *) omemo_iqFetchNode:(NSString *)node to:(XMPPJID *)toJID elementId:(nullable NSString*)elementId {
    XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:toJID elementID:elementId];
    NSXMLElement *pubsub = [NSXMLElement elementWithName:@"pubsub" xmlns:XMLNS_PUBSUB];
    NSXMLElement *itemsElement = [NSXMLElement elementWithName:@"items"];
    [itemsElement addAttributeWithName:@"node" stringValue:node];
    
    [pubsub addChild:itemsElement];
    [iq addChild:pubsub];
    
    return iq;
}

+ (XMPPIQ *) omemo_iqDeleteNode:(NSString *)node elementId:(nullable NSString *)elementId {
    XMPPIQ *iq = [XMPPIQ iqWithType:@"set" elementID:elementId];
    NSXMLElement *pubsub = [NSXMLElement elementWithName:@"pubsub" xmlns:XMLNS_PUBSUB];
    NSXMLElement *deleteElement = [NSXMLElement elementWithName:@"retract"];
    [deleteElement addAttributeWithName:@"node" stringValue:node];
    
    [pubsub addChild:deleteElement];
    [iq addChild:pubsub];
    
    return iq;
}
/**
 * iq stanza for fetching remote bundle
 
 <iq type='get'
    from='romeo@montague.lit'
    to='juliet@capulet.lit'
    id='fetch1'>
  <pubsub xmlns='http://jabber.org/protocol/pubsub'>
    <items node='urn:xmpp:omemo:0:bundles:31415'/>
  </pubsub>
</iq>
 
 */
+ (XMPPIQ*) omemo_iqFetchBundleForDeviceId:(uint32_t)deviceId
                                       jid:(XMPPJID*)jid
                                 elementId:(nullable NSString*)elementId
                              xmlNamespace:(OMEMOModuleNamespace)xmlNamespace {
    NSString *nodeName = [OMEMOModule xmlnsOMEMOBundles:xmlNamespace deviceId:deviceId];
    return [self omemo_iqFetchNode:nodeName to:jid elementId:elementId];
}


- (nullable OMEMOBundle*) omemo_bundle:(OMEMOModuleNamespace)ns {
    NSXMLElement *pubsub = [self elementForName:@"pubsub" xmlns:XMLNS_PUBSUB];
    if (!pubsub) { return nil; }
    NSXMLElement *items = [pubsub elementForName:@"items"];
    // If !items, this is a <publish> bundle and used for testing
    if (!items) {
        items = [pubsub elementForName:@"publish"];
    }
    if (!items) { return nil; }
    NSString *node = [items attributeForName:@"node"].stringValue;
    if (!node) { return nil; }
    if (![node containsString:[OMEMOModule xmlnsOMEMOBundles:ns]]) {
        return nil;
    }
    NSString *separator = [[OMEMOModule xmlnsOMEMOBundles:ns] stringByAppendingString:@":"];
    NSArray<NSString*> *components = [node componentsSeparatedByString:separator];
    NSString *deviceIdString = [components lastObject];
    uint32_t deviceId = (uint32_t)[deviceIdString integerValue];
    
    NSXMLElement *itemElement = [items elementForName:@"item"];
    if (!itemElement) { return nil; }
    NSXMLElement *bundleElement = [itemElement elementForName:@"bundle" xmlns:[OMEMOModule xmlnsOMEMO:ns]];
    if (!bundleElement) { return nil; }
    NSXMLElement *signedPreKeyElement = [bundleElement elementForName:@"signedPreKeyPublic"];
    if (!signedPreKeyElement) { return nil; }
    uint32_t signedPreKeyId = [signedPreKeyElement attributeUInt32ValueForName:@"signedPreKeyId"];
    NSString *signedPreKeyPublicBase64 = [signedPreKeyElement stringValue];
    if (!signedPreKeyPublicBase64) { return nil; }
    NSData *signedPreKeyPublic = [[NSData alloc] initWithBase64EncodedString:signedPreKeyPublicBase64 options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if (!signedPreKeyPublic) { return nil; }
    NSString *signedPreKeySignatureBase64 = [[bundleElement elementForName:@"signedPreKeySignature"] stringValue];
    if (!signedPreKeySignatureBase64) { return nil; }
    NSData *signedPreKeySignature = [[NSData alloc] initWithBase64EncodedString:signedPreKeySignatureBase64 options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if (!signedPreKeySignature) { return nil; }
    NSString *identityKeyBase64 = [[bundleElement elementForName:@"identityKey"] stringValue];
    if (!identityKeyBase64) { return nil; }
    NSData *identityKey = [[NSData alloc] initWithBase64EncodedString:identityKeyBase64 options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if (!identityKey) { return nil; }
    NSXMLElement *preKeysElement = [bundleElement elementForName:@"prekeys"];
    if (!preKeysElement) { return nil; }
    NSArray<NSXMLElement*> *preKeyElements = [preKeysElement elementsForName:@"preKeyPublic"];
    NSMutableArray<OMEMOPreKey*> *preKeys = [NSMutableArray arrayWithCapacity:preKeyElements.count];
    [preKeyElements enumerateObjectsUsingBlock:^(NSXMLElement * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        uint32_t preKeyId = [obj attributeUInt32ValueForName:@"preKeyId"];
        NSString *b64 = [obj stringValue];
        NSData *data = nil;
        if (b64) {
            data = [[NSData alloc] initWithBase64EncodedString:b64 options:NSDataBase64DecodingIgnoreUnknownCharacters];
        }
        if (data) {
            OMEMOPreKey *preKey = [[OMEMOPreKey alloc] initWithPreKeyId:preKeyId publicKey:data];
            [preKeys addObject:preKey];
        }
    }];
    OMEMOSignedPreKey *signedPreKey = [[OMEMOSignedPreKey alloc] initWithPreKeyId:signedPreKeyId publicKey:signedPreKeyPublic signature:signedPreKeySignature];
    OMEMOBundle *bundle = [[OMEMOBundle alloc] initWithDeviceId:deviceId identityKey:identityKey signedPreKey:signedPreKey preKeys:preKeys];
    return bundle;
}

@end
