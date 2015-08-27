
#import "NSXMLElement+XEP_0352.h"

#define XMLNS_XMPP_CLIENT_STATE_INDICATION @"urn:xmpp:csi:0"

@implementation NSXMLElement (XEP0352)

+ (instancetype)indicateActiveElement
{
    return [NSXMLElement elementWithName:@"active" xmlns:XMLNS_XMPP_CLIENT_STATE_INDICATION];
}

+ (instancetype)indicateInactiveElement
{
    return [NSXMLElement elementWithName:@"inactive" xmlns:XMLNS_XMPP_CLIENT_STATE_INDICATION];
}

@end
