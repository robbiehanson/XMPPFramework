#import "NSXMLElement+XEP_0059.h"
#import "NSXMLElement+XMPP.h"
#import "XMPPResultSet.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif


#define XMLNS_XMPP_RESULT_SET @"http://jabber.org/protocol/rsm"
#define NAME_XMPP_RESULT_SET @"set"

@implementation NSXMLElement (XEP_0059)


- (BOOL)isResultSet
{    
    if([[self name] isEqualToString:NAME_XMPP_RESULT_SET] && [[self xmlns] isEqualToString:XMLNS_XMPP_RESULT_SET])
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

- (BOOL)hasResultSet
{
    if([self resultSet])
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

- (XMPPResultSet *)resultSet
{
    NSXMLElement *resultSetElement = [self elementForName:NAME_XMPP_RESULT_SET xmlns:XMLNS_XMPP_RESULT_SET];
    XMPPResultSet *resultSet = [XMPPResultSet resultSetFromElement:resultSetElement];
    return resultSet;    
}

@end
