#import "NSXMLElement+XEP_0297.h"
#import "NSXMLElement+XMPP.h"
#import "NSXMLElement+XEP_0203.h"
#import "XMPPIQ.h"
#import "XMPPMessage.h"
#import "XMPPPresence.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#define NAME_XMPP_STANZA_FORWARDING @"forwarded"
#define XMLNS_XMPP_STANZA_FORWARDING @"urn:xmpp:forward:0"

@implementation NSXMLElement (XEP_0297)

#pragma mark Forwarded Stanza 

- (NSXMLElement *)forwardedStanza
{
    return [self elementForName:NAME_XMPP_STANZA_FORWARDING xmlns:XMLNS_XMPP_STANZA_FORWARDING];
}

- (BOOL)hasForwardedStanza
{
    if([self forwardedStanza])
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

- (BOOL)isForwardedStanza
{
    if([[self name] isEqualToString:NAME_XMPP_STANZA_FORWARDING] && [[self xmlns] isEqualToString:XMLNS_XMPP_STANZA_FORWARDING])
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

#pragma mark Delayed Delivery Date

- (NSDate *)forwardedStanzaDelayedDeliveryDate
{
    if([self isForwardedStanza])
    {
        return [self delayedDeliveryDate];
    }
    else
    {
        return [[self forwardedStanza] delayedDeliveryDate];     
    }
}


#pragma mark XMPPElement

- (XMPPIQ *)forwardedIQ
{
    if([self isForwardedStanza])
    {
        return [XMPPIQ iqFromElement:[self elementForName:@"iq"]];
    }
    else
    {
        return [XMPPIQ iqFromElement:[[self forwardedStanza] elementForName:@"iq"]];
    }
}

- (BOOL)hasForwardedIQ
{
    if([self forwardedIQ])
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

- (XMPPMessage *)forwardedMessage
{
    if([self isForwardedStanza])
    {
        return [XMPPMessage messageFromElement:[self elementForName:@"message"]];
    }
    else
    {
        return [XMPPMessage messageFromElement:[[self forwardedStanza] elementForName:@"message"]];
    }
}

- (BOOL)hasForwardedMessage
{
    if([self forwardedMessage])
    {
        return YES;
    }
    else
    {
        return NO;
    }
}


- (XMPPPresence *)forwardedPresence
{
    if([self isForwardedStanza])
    {
        return [XMPPPresence presenceFromElement:[self elementForName:@"presence"]];
    }
    else
    {
        return [XMPPPresence presenceFromElement:[[self forwardedStanza] elementForName:@"presence"]];
    }
}

- (BOOL)hasForwardedPresence
{
    if([self forwardedPresence])
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

@end
