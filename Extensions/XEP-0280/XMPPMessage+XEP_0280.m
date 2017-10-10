#import "XMPPMessage+XEP_0280.h"
#import "XMPPJID.h"
#import "NSXMLElement+XMPP.h"
#import "NSXMLElement+XEP_0297.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#define XMLNS_XMPP_MESSAGE_CARBONS @"urn:xmpp:carbons:2"

@implementation XMPPMessage (XEP_0280)

- (NSXMLElement *)receivedMessageCarbon
{
    return [self elementForName:@"received" xmlns:XMLNS_XMPP_MESSAGE_CARBONS];
}

- (NSXMLElement *)sentMessageCarbon
{
    return [self elementForName:@"sent" xmlns:XMLNS_XMPP_MESSAGE_CARBONS];
}


- (BOOL)isMessageCarbon
{    
    if([self isReceivedMessageCarbon] || [self isSentMessageCarbon])
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

- (BOOL)isReceivedMessageCarbon
{
    if([self receivedMessageCarbon])
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

- (BOOL)isSentMessageCarbon
{
    if([self sentMessageCarbon])
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

- (BOOL)isTrustedMessageCarbon
{
    BOOL isTrustedMessageCarbon = NO;
    XMPPMessage *messageCarbonForwardedMessage = [self messageCarbonForwardedMessage];
    if (!messageCarbonForwardedMessage) {
        return NO;
    }

    if([self isSentMessageCarbon])
    {
        if([[self from] isEqualToJID:[messageCarbonForwardedMessage from] options:XMPPJIDCompareBare])
        {
            isTrustedMessageCarbon = YES;
        }

    }
    else if([self isReceivedMessageCarbon])
    {
        if([[self from] isEqualToJID:[messageCarbonForwardedMessage to] options:XMPPJIDCompareBare])
        {
            isTrustedMessageCarbon = YES;
        }
    }

    return isTrustedMessageCarbon;
}

- (BOOL)isTrustedMessageCarbonForMyJID:(XMPPJID *)jid
{
    if([self isTrustedMessageCarbon] && [[jid bareJID] isEqualToJID:self.from])
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

- (XMPPMessage *)messageCarbonForwardedMessage
{
    NSXMLElement *carbon = nil;
    
    if([self receivedMessageCarbon])
    {
        carbon = [self receivedMessageCarbon];
    }
    else if([self sentMessageCarbon])
    {
        carbon = [self sentMessageCarbon];
    }
    
    return [carbon forwardedMessage];
}

- (void)addPrivateMessageCarbons
{
    [self addChild:[NSXMLElement elementWithName:@"private" xmlns:XMLNS_XMPP_MESSAGE_CARBONS]];
}

@end
