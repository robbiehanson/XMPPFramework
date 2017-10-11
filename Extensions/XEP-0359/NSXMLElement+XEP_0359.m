//
//  NSXMLElement+XEP_0359.m
//  XMPPFramework
//
//  Created by Chris Ballinger on 10/10/17.
//  Copyright © 2017 robbiehanson. All rights reserved.
//

#import "NSXMLElement+XEP_0359.h"
#import "NSXMLElement+XMPP.h"

@implementation NSXMLElement (XEP_0359)

+ (instancetype) originIdElement {
    return [self originIdElementWithUniqueId:nil];
}

+ (instancetype) originIdElementWithUniqueId:(nullable NSString*)uniqueId {
    if (!uniqueId) {
        uniqueId = [NSUUID UUID].UUIDString;
    }
    NSXMLElement *element = [NSXMLElement elementWithName:XMPPOriginIdElementName xmlns:XMPPStanzaIdXmlns];
    
    return element;
}


+ (instancetype) stanzaIdElementWithJID:(XMPPJID*)JID {
    return [self stanzaIdElementWithJID:JID uniqueId:nil];
}

+ (instancetype) stanzaIdElementWithJID:(XMPPJID*)JID uniqueId:(nullable NSString*)uniqueId {
    NSXMLElement *element = [NSXMLElement elementWithName:XMPPStanzaIdElementName xmlns:XMPPStanzaIdXmlns];
    if (!uniqueId.length) {
        uniqueId = [NSUUID UUID].UUIDString;
    }
    NSString *by = JID.bare;
    
    [element addAttributeWithName:@"id"
                      stringValue:uniqueId];
    [element addAttributeWithName:@"by" stringValue:by];
    
    return element;
}

@end
