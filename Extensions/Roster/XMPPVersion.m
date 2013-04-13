//
//  XMPPVersion.m
//  SMSPlus
//
//  Created by admin on 11-02-05.
//  Copyright 2011 Baseva Inc. All rights reserved.
//

#import "XMPPVersion.h"
#import "XMPP.h"

#define INTEGRATE_WITH_CAPABILITIES 1

#if INTEGRATE_WITH_CAPABILITIES
#import "XMPPCapabilities.h"
#endif

#if TARGET_OS_IPHONE  
#import <UIKit/UIKit.h>
#endif
@interface XMPPVersion ()
{
    NSString *versionTag;
}
@end

@implementation XMPPVersion


- (id)init
{
    return [self initWithDispatchQueue:NULL withVersionTag:@"iPhone/App"];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue withVersionTag:(NSString *)aversion;
{
    if ((self = [super initWithDispatchQueue:queue]))
    {
        versionTag = [aversion copy];
    }
    return self;
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

- (id)initWithXMPPStream:(XMPPStream *)aXmppStream withVersionTag:(NSString *)aversion
{
    if ((self = [self init]))
    {
        versionTag = [aversion copy];
        
    }
    return self;
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
    NSString *type = [[iq attributeForName:@"type"] stringValue];
    
    if ([type isEqualToString:@"result"] || [type isEqualToString:@"error"])
    {
        NSXMLElement *version = [iq elementForName:@"query" xmlns:@"jabber:iq:version"];
        if (version)
        {
            [multicastDelegate xmppVersion:self didReceiveVersion:iq];
        }
    }
    else if ([type isEqualToString:@"get"])
    {
        
        NSXMLElement *version = [iq elementForName:@"query" xmlns:@"jabber:iq:version"];
        if (version)
        {
            NSString *applicationVersion = versionTag;
            // Format current device description
            UIDevice *deviceInfo = [UIDevice currentDevice];
            NSMutableString *deviceDescription = [NSMutableString stringWithCapacity: 0];
            [deviceDescription appendString: [deviceInfo model]];
            [deviceDescription appendString: @" {"];
            [deviceDescription appendString: [deviceInfo systemName]];
            [deviceDescription appendString: @" "];
            [deviceDescription appendString: [deviceInfo systemVersion]];
            [deviceDescription appendString: @"}"];
            
            // Build query element
            NSXMLElement *queryElement = [NSXMLElement elementWithName: @"query" xmlns: @"jabber:iq:version"];
            [queryElement addChild: [NSXMLElement elementWithName: @"name" stringValue: applicationVersion]];
            [queryElement addChild: [NSXMLElement elementWithName: @"version" stringValue: @"2.0"]];
            [queryElement addChild: [NSXMLElement elementWithName: @"os" stringValue: deviceDescription]];
            
            // Build feature discovery IQ result
            NSXMLElement *iqStanza = [NSXMLElement elementWithName: @"iq"];
            [iqStanza addAttributeWithName: @"to" stringValue: [iq toStr]];
            [iqStanza addAttributeWithName: @"type" stringValue: @"result"];
            
            NSString *iqId = [iq elementID];
            
            if (iqId) {
                [iqStanza addAttributeWithName: @"id" stringValue: iqId];
            }
            
            [iqStanza addChild: queryElement];
            
            
            [sender sendElement: iqStanza];
            return YES;
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
    [feature addAttributeWithName:@"var" stringValue:@"jabber:iq:version"];
    
    [query addChild:feature];
}
#endif


@end
