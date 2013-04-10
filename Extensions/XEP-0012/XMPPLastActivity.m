//
//  XMPPLastActivity.m
//  XMPPFramework
//
//  Created by Sean Batson on 12-07-01.
//  Copyright (c) 2012 Baseva, Inc. All rights reserved.
//

#import "XMPPLastActivity.h"
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

#define kModuleNameSpace  @"jabber:iq:last"

@implementation XMPPLastActivity


- (void)requestWhenLastSeen:(XMPPJID *)jid
{
    NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:kModuleNameSpace];
    
    XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:jid elementID:[xmppStream generateUUID]];
    [iq addChild:query];
    
    [xmppStream sendElement:iq];
}
 

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



- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
    NSString *type = [[iq attributeForName:@"type"] stringValue];
    
    if ([type isEqualToString:@"result"])
    {
        NSXMLElement *lastseen = [iq elementForName:@"query" xmlns:kModuleNameSpace];
        if (lastseen)
        {
            [multicastDelegate xmppLastSeen:self didResponseWithLastSeenIQ:iq];
        }
        
    }
    else if ([type isEqualToString:@"get"])
    {
        NSXMLElement *lastseen = [iq elementForName:@"query" xmlns:kModuleNameSpace];
        if (lastseen)
        {
            NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:kModuleNameSpace];
            
            [query addAttributeWithName:@"seconds" stringValue:@"0"];
            XMPPIQ *iqresult = [XMPPIQ iqWithType:@"result" to:[iq from] elementID:[iq elementID]];
            [iqresult addChild:query];
            [sender sendElement:iqresult]; 

            return YES;
        }
        
    } 
    else if ([type isEqualToString:@"error"]) {
        NSXMLElement *lastseen = [iq elementForName:@"query" xmlns:kModuleNameSpace];
        if (lastseen)
        {
            [multicastDelegate xmppLastSeen:self didResponseWithLastSeenError:iq];
        }
    }
    
    return NO;
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
    [feature addAttributeWithName:@"var" stringValue:kModuleNameSpace];
    [query addChild:feature];
    
}
#endif

@end
