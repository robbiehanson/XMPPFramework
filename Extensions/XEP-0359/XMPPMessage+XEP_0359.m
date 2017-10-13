//
//  XMPPMessage+XEP_0359.m
//  XMPPFramework
//
//  Created by Chris Ballinger on 10/10/17.
//  Copyright © 2017 Chris Ballinger. All rights reserved.
//

#import "XMPPMessage+XEP_0359.h"
#import "NSXMLElement+XEP_0359.h"
#import "NSXMLElement+XMPP.h"

@implementation XMPPMessage (XEP_0359)

- (NSString*) originId {
    NSXMLElement *oid = [self elementForName:XMPPOriginIdElementName xmlns:XMPPStanzaIdXmlns];
    return [oid attributeStringValueForName:@"id"];
}

- (void) addOriginId:(nullable NSString*)originId {
    NSXMLElement *oid = [NSXMLElement originIdElementWithUniqueId:originId];
    [self addChild:oid];
}

- (NSDictionary<XMPPJID*,NSString*>*) stanzaIds {
    NSArray<NSXMLElement*> *stanzaIdElements = [self elementsForLocalName:XMPPStanzaIdElementName URI:XMPPStanzaIdXmlns];
    if (!stanzaIdElements.count) { return @{}; }
    
    NSMutableDictionary<XMPPJID*,NSString*> *stanzaIds = [NSMutableDictionary dictionaryWithCapacity:stanzaIdElements.count];
    
    [stanzaIdElements enumerateObjectsUsingBlock:^void(NSXMLElement * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *sid = [obj attributeStringValueForName:@"id"];
        if (!sid) { return; }
        NSString *by = [obj attributeStringValueForName:@"by"];
        if (!by.length) { return; }
        XMPPJID *jid = [XMPPJID jidWithString:by];
        if (!jid) { return; }
        [stanzaIds setObject:sid forKey:jid];
    }];
    
    return stanzaIds;
}

@end
