//
//  XMPPStream+StreamManagement.m
//  iPhoneXMPP
//
//  Created by Vitaly on 03.03.14.
//
//

#import "XMPPStreamManagement.h"

#import "XMPP.h"
#import "XMPPInternal.h"
#import "XMPPLogging.h"
#import "NSData+XMPP.h"
#import "NSXMLElement+XMPP.h"


#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
#if DEBUG
static const int xmppLogLevel = XMPP_LOG_LEVEL_INFO; // | XMPP_LOG_FLAG_TRACE;
#else
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

@implementation XMPPStreamManagement

-(void) xmppStreamDidAuthenticate:(XMPPStream *)sender {
    if ([sender isStreamManagementSupported]) {
        XMPPElement *enable = [[XMPPElement alloc] initWithName:@"enable" xmlns:@"urn:xmpp:sm:3"];
        [enable addAttributeWithName:@"resume" stringValue:[self allowResumeSession] ? @"true" : @"false"];
        [sender sendElement:enable];
    }
}

@end