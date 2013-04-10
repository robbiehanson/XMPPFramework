//
//  XMPPOutOfBand.m
//  XMPPFramework
//
//  Created by Sean Batson on 12-06-29.
//  Copyright (c) 2012 Baseva, Inc. All rights reserved.
//

#import "XMPPOutOfBand.h"
#import "XMPP.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif
#define INTEGRATE_WITH_CAPABILITIES 1

#if INTEGRATE_WITH_CAPABILITIES
#import "XMPPCapabilities.h"
#endif

#if TARGET_OS_IPHONE  
#import <UIKit/UIKit.h>
#endif

@implementation XMPPOutOfBand


- (BOOL)activate:(XMPPStream *)aXmppStream
{
    if ([super activate:aXmppStream])
    {
#if INTEGRATE_WITH_CAPABILITIES
        [xmppStream autoAddDelegate:self delegateQueue:moduleQueue toModulesOfClass:[XMPPCapabilities class]];
#endif
        
        return YES;
    }
    
    return NO;
}

- (void)deactivate
{
#if INTEGRATE_WITH_CAPABILITIES
    [xmppStream removeAutoDelegate:self delegateQueue:moduleQueue fromModulesOfClass:[XMPPCapabilities class]];
#endif
    
    dispatch_block_t block = ^{
        
    };
    
    if (dispatch_get_specific(moduleQueueTag))
        block();
    else
        dispatch_sync(moduleQueue, block);
    
    [super deactivate];
}


- (BOOL)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
    NSXMLElement *xtag =[message elementForName:@"x" xmlns:@"jabber:x:oob"];

    if (xtag)
    {
        NSXMLElement *url = [xtag elementForName:@"url"];
        
        if (url)
        {
            [multicastDelegate xmppOutOfBand:self didReceiveMessageWithURL:message];
            return YES;
        }                     
    }
    return NO;
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
    NSString *type = [[iq attributeForName:@"type"] stringValue];
    
    if ([type isEqualToString:@"result"])
    {
        NSXMLElement *obb = [iq elementForName:@"query" xmlns:@"jabber:iq:oob"];
        if (obb)
        {
            [multicastDelegate xmppOutOfBand:self didResultInSuccess:iq];
        }
        
    }
    else if ([type isEqualToString:@"get"])
    {
        NSXMLElement *obb = [iq elementForName:@"query" xmlns:@"jabber:iq:oob"];
        if (obb)
        {
            XMPPIQ *iqresult = [XMPPIQ iqWithType:@"result" to:[iq from] elementID:[iq elementID]];
            [sender sendElement:iqresult];  

        }
       return YES;
    } 
    else if ([type isEqualToString:@"error"]) {
        
        NSXMLElement *serviceUnavailable = [[iq elementForName:@"error" xmlns:@"jabber:iq:oob"] elementForName:@"service-unavailable" xmlns:@"urn:ietf:params:xml:ns:xmpp-stanzas"];
        if (serviceUnavailable) {
            
            [multicastDelegate xmppOutOfBand:self didReceiveServiceUnavailable:iq];
        } else if ([iq elementForName:@"error" xmlns:@"jabber:iq:oob"]){
            [multicastDelegate xmppOutOfBand:self didResultInError:iq];
        }
        
    }
    else if ([type isEqualToString:@"set"]) {

        NSXMLElement *obb = [iq elementForName:@"query" xmlns:@"jabber:iq:oob"];
        if (obb)
        {
        NSXMLElement *urlXML  = [[iq elementForName:@"query"] elementForName:@"url"];
        NSXMLElement *descXML = [[iq elementForName:@"query"] elementForName:@"desc"];
        


            NSString *url  = [urlXML stringValue];
            NSString *desc = [descXML stringValue];
            
            if(!urlXML) {
                XMPPIQ *iqresult = [XMPPIQ iqWithType:@"error" to:[iq from] elementID:[iq elementID]];
                
                NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:oob"];
                NSXMLElement *urlXML   = [NSXMLElement elementWithName:@"url" stringValue:url];
                NSXMLElement *descXML  = [NSXMLElement elementWithName:@"desc" stringValue:desc];
                
                [query addChild:urlXML];
                [query addChild:descXML];
                [iqresult addChild:query];
                
                NSXMLElement *error = [NSXMLElement elementWithName:@"error"];
                [error addAttributeWithName:@"type" stringValue:@"cancel"];
                [error addAttributeWithName:@"code" stringValue:@"404"];
                
                NSXMLElement *item = [NSXMLElement elementWithName:@"item-not-found" xmlns:@"urn:ietf:params:xml:ns:xmpp-stanzas"]; 
                [error addChild:item];
                
                [iqresult addChild:error];
                [sender sendElement:iqresult];
                
            } else {
                XMPPIQ *iqresult = [XMPPIQ iqWithType:@"result" to:[iq from] elementID:[iq elementID]];
                [sender sendElement:iqresult];  
                [multicastDelegate xmppOutOfBand:self didReceiveURL:iq];
                
            }
        }
        
       return YES;   
    }
    return NO;
}

- (void)sendOOBRequest:(XMPPJID *)tojid withURL:(NSString *)URL withDesc:(NSString *)desc
{
    NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:oob"];
    NSXMLElement *urlXML   = [NSXMLElement elementWithName:@"url" stringValue:URL];
    NSXMLElement *descXML  = [NSXMLElement elementWithName:@"desc" stringValue:desc];
    
    [query addChild:urlXML];
    [query addChild:descXML];
    
    XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:tojid elementID:[xmppStream generateUUID]];
    [iq addChild:query];
    
    [xmppStream sendElement:iq];
    
}

#if INTEGRATE_WITH_CAPABILITIES
/**
 * If an XMPPCapabilites instance is used we want to advertise our support for vcards.
 **/
- (void)xmppCapabilities:(XMPPCapabilities *)sender collectingMyCapabilities:(NSXMLElement *)query
{
    // <query xmlns="http://jabber.org/protocol/disco#info">
    //   ...
    //   <feature var="jabber:iq:version"/>
    //   ...
    // </query>
    
    NSXMLElement *feature = [NSXMLElement elementWithName:@"feature"];
    [feature addAttributeWithName:@"var" stringValue:@"jabber:x:oob"];
    [query addChild:feature];
    
    feature = [NSXMLElement elementWithName:@"feature"];
    [feature addAttributeWithName:@"var" stringValue:@"jabber:iq:oob"];
    [query addChild:feature];
    
}
#endif


@end
