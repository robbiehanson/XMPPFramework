//
//  XMPPIQ+OMEMO.m
//  XMPPFramework
//
//  Created by Chris Ballinger on 4/21/16.
//
//
#import "XMPPIQ+OMEMO.h"
#import "XMPPIQ+XEP_0060.h"
#import "OMEMOModule.h"

@implementation XMPPIQ (OMEMO)


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
+ (XMPPIQ*) omemo_iqForDeviceIds:(NSArray<NSNumber*>*)deviceIds {
    NSXMLElement *listElement = [NSXMLElement elementWithName:@"list" xmlns:XMLNS_OMEMO];
    [deviceIds enumerateObjectsUsingBlock:^(NSNumber * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSXMLElement *device = [NSXMLElement elementWithName:@"device"];
        [device addAttributeWithName:@"id" numberValue:obj];
        [listElement addChild:device];
    }];
    
    NSXMLElement *item = [NSXMLElement elementWithName:@"item"];
    [item addChild:listElement];
    
    NSXMLElement *publish = [NSXMLElement elementWithName:@"publish"];
    [publish addAttributeWithName:@"node" stringValue:XMLNS_OMEMO_DEVICELIST];
    [publish addChild:item];
    
    NSXMLElement *pubsub = [NSXMLElement elementWithName:@"pubsub" xmlns:XMLNS_PUBSUB];
    [pubsub addChild:publish];
    
    XMPPIQ *iq = [XMPPIQ iqWithType:@"set"];
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
+ (XMPPIQ*) omemo_iqBundleForDevice:(NSNumber*)deviceId
                        identityKey:(NSString*)identityKey
                       signedPreKey:(NSString*)signedPreKey
                     signedPreKeyId:(NSNumber*)signedPreKeyId
              signedPreKeySignature:(NSString*)signedPreKeySignature
                            preKeys:(NSDictionary<NSNumber*,NSString*>*)preKeys {
    NSXMLElement *signedPreKeyElement = nil;
    if (signedPreKeyId && signedPreKey) {
        signedPreKeyElement = [NSXMLElement elementWithName:@"signedPreKeyPublic" stringValue:signedPreKey];
        [signedPreKeyElement addAttributeWithName:@"signedPreKeyId" numberValue:deviceId];
    }
    NSXMLElement *signedPreKeySignatureElement = nil;
    if (signedPreKeySignature) {
        signedPreKeySignatureElement = [NSXMLElement elementWithName:@"signedPreKeySignature" stringValue:signedPreKeySignature];
    }
    NSXMLElement *preKeysElement = [NSXMLElement elementWithName:@"prekeys"];
    [preKeys enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull preKeyId, NSString * _Nonnull preKey, BOOL * _Nonnull stop) {
        NSXMLElement *preKeyElement = [NSXMLElement elementWithName:@"preKeyPublic" stringValue:preKey];
        [preKeyElement addAttributeWithName:@"preKeyId" numberValue:preKeyId];
        [preKeysElement addChild:preKeyElement];
    }];
    NSXMLElement *bundleElement = [XMPPElement elementWithName:@"bundle" xmlns:XMLNS_OMEMO];
    if (signedPreKeyElement) {
        [bundleElement addChild:signedPreKeyElement];
    }
    if (signedPreKeySignatureElement) {
        [bundleElement addChild:signedPreKeySignatureElement];
    }
    [bundleElement addChild:preKeysElement];
    NSXMLElement *itemElement = [NSXMLElement elementWithName:@"item"];
    [itemElement addChild:bundleElement];
    
    NSXMLElement *publish = [NSXMLElement elementWithName:@"publish"];
    NSString *nodeName = [NSString stringWithFormat:@"%@:%@",XMLNS_OMEMO_BUNDLES,deviceId.stringValue];
    [publish addAttributeWithName:@"node" stringValue:nodeName];
    [publish addChild:itemElement];
    
    NSXMLElement *pubsub = [NSXMLElement elementWithName:@"pubsub" xmlns:XMLNS_PUBSUB];
    [pubsub addChild:publish];
    
    XMPPIQ *iq = [XMPPIQ iqWithType:@"set"];
    [iq addChild:pubsub];
    return iq;
}


+ (XMPPIQ *) omemo_iqFetchNode:(NSString *)node to:(XMPPJID *)toJID {
    XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:toJID];
    NSXMLElement *pubsub = [NSXMLElement elementWithName:@"pubsub" xmlns:XMLNS_PUBSUB];
    NSXMLElement *itemsElement = [NSXMLElement elementWithName:@"items"];
    [itemsElement addAttributeWithName:@"node" stringValue:node];
    
    [pubsub addChild:itemsElement];
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
+ (XMPPIQ*) omemo_iqfetchBundleForDevice:(NSNumber*)deviceId
                                     jid:(XMPPJID*)jid {
    NSString *nodeName = [NSString stringWithFormat:@"%@:%@",XMLNS_OMEMO_BUNDLES,deviceId.stringValue];
    return [self omemo_iqFetchNode:nodeName to:jid];
}

/** 
 * iq stanza for feetching devices
 
 <iq type='get'
    from='romeo@montague.lit'
    to='juliet@capulet.lit'
    id='fetch1'>
 <pubsub xmlns='http://jabber.org/protocol/pubsub'>
    <items node='urn:xmpp:omemo:0:bundles:31415'/>
 </pubsub>
 </iq>
 
 */
+ (XMPPIQ*) omemo_iqfetchDevices:(XMPPJID *)jid
{
    NSString *nodeName = XMLNS_OMEMO_DEVICELIST;
    return [self omemo_iqFetchNode:nodeName to:jid];
}

@end