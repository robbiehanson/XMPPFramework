//
//  XMPPMessage+XEP_0313.m
//  XMPPFramework
//
//  Created by Chris Ballinger on 10/23/17.
//  Copyright © 2017 Chris Ballinger. All rights reserved.
//

#import "XMPPMessage+XEP_0313.h"
#import "XMPPMessageArchiveManagement.h"
#import "NSXMLElement+XMPP.h"

@implementation XMPPMessage (XEP_0313)

- (NSXMLElement*) mamResult {
    NSXMLElement *result = [self elementForName:@"result" xmlns:XMLNS_XMPP_MAM];
    return result;
}

@end
