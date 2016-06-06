//
//  XMPPMessage+XEP_0313.m
//  XEP-0313 Message Archive Management
//
//  Created by Arslan Pervaiz on 03/6/16.
//  Copyright 2016 Vopium A/S. All rights reserved.
//

#import "XMPPMessage+XEP_0313.h"

@implementation XMPPMessage (XEP_0313)

- (BOOL)hasForwardedMessage
{
    NSXMLElement* hasForwardedMessage = [[self elementForName:@"result" xmlns:@"urn:xmpp:mam:1"] elementForName:@"forwarded" xmlns:@"urn:xmpp:forward:0"];
    
    return (hasForwardedMessage != nil);
}

- (NSString *)getResult
{
    return [[self elementForName:@"result" xmlns:@"urn:xmpp:mam:1"] stringValue];
}

- (XMPPMessage *) getforwardedMessage
{
    NSXMLElement* forwardedElement = [[self elementForName:@"result" xmlns:@"urn:xmpp:mam:1"] elementForName:@"forwarded" xmlns:@"urn:xmpp:forward:0"];
    
    NSXMLElement* messageElement = [forwardedElement elementForName:@"message" xmlns: @"jabber:client"];
    
    return [XMPPMessage messageFromElement: messageElement];
}

@end