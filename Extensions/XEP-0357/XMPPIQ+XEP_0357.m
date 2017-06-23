//
//  NSXMLElement+NSXMLElement_XEP_0357.m
//  Pods
//
//  Created by David Chiles on 2/9/16.
//
//

#import "XMPPIQ+XEP_0357.h"
#import "XMPPJID.h"
#import "NSXMLElement+XMPP.h"
#import "XMPPStream.h"

NSString *const XMPPPushXMLNS = @"urn:xmpp:push:0";

@implementation XMPPIQ (XEP0357)

+ (instancetype)enableNotificationsElementWithJID:(XMPPJID *)jid node:(NSString *)node options:(nullable NSDictionary<NSString *,NSString *> *)options {
    return [self enableNotificationsElementWithJID:jid node:node options:options elementId:nil];
}

+ (instancetype)enableNotificationsElementWithJID:(XMPPJID *)jid node:(NSString *)node options:(nullable NSDictionary<NSString *,NSString *> *)options elementId:(NSString *)elementId
{
    if (!elementId) {
        elementId = [XMPPStream generateUUID];
    }
    NSXMLElement *enableElement = [self elementWithName:@"enable" xmlns:XMPPPushXMLNS];
    [enableElement addAttributeWithName:@"jid" stringValue:[jid full]];
    if ([node length]) {
        [enableElement addAttributeWithName:@"node" stringValue:node];
    }
    
    if ([options count]) {
        NSXMLElement *dataForm = [self elementWithName:@"x" xmlns:@"jabber:x:data"];
        [dataForm addAttributeWithName:@"type" stringValue:@"submit"];
        NSXMLElement *formTypeField = [NSXMLElement elementWithName:@"field"];
        [formTypeField addAttributeWithName:@"var" stringValue:@"FORM_TYPE"];
        [formTypeField addChild:[NSXMLElement elementWithName:@"value" stringValue:@"http://jabber.org/protocol/pubsub#publish-options"]];
        [dataForm addChild:formTypeField];
        
        [options enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
            NSXMLElement *formField = [NSXMLElement elementWithName:@"field"];
            [formField addAttributeWithName:@"var" stringValue:key];
            [formField addChild:[NSXMLElement elementWithName:@"value" stringValue:obj]];
            [dataForm addChild:formField];
        }];
        [enableElement addChild:dataForm];
    }
    
    return [self iqWithType:@"set" elementID:elementId child:enableElement];
    
}

+ (instancetype)disableNotificationsElementWithJID:(XMPPJID *)jid node:(NSString *)node {
    return [self disableNotificationsElementWithJID:jid node:node elementId:nil];
}

+ (instancetype)disableNotificationsElementWithJID:(XMPPJID *)jid node:(NSString *)node elementId:(nullable NSString *)elementId
{
    if (!elementId) {
        elementId = [XMPPStream generateUUID];
    }
    NSXMLElement *disableElement = [self elementWithName:@"disable" xmlns:XMPPPushXMLNS];
    [disableElement addAttributeWithName:@"jid" stringValue:[jid full]];
    if ([node length]) {
        [disableElement addAttributeWithName:@"node" stringValue:node];
    }
    return [self iqWithType:@"set" elementID:elementId child:disableElement];
}

@end
