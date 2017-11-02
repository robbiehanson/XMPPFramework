#import "XMPPDelayedDelivery.h"
#import "XMPPLogging.h"
#import "NSXMLElement+XEP_0203.h"

// Log levels: off, error, warn, info, verbose
// Log flags: trace
#if DEBUG
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;
#else
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

@implementation XMPPDelayedDelivery

- (void)didActivate
{
    XMPPLogTrace();
}

- (void)willDeactivate
{
    XMPPLogTrace();
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
    XMPPLogTrace();
    
    if (![message wasDelayed]) {
        return;
    }
    
    XMPPLogInfo(@"Received delayed delivery message with date: %@, origin: %@, reason description: %@",
                [message delayedDeliveryDate],
                [message delayedDeliveryFrom] ?: @"unspecified",
                [message delayedDeliveryReasonDescription] ?: @"unspecified");
    
    [multicastDelegate xmppDelayedDelivery:self didReceiveDelayedMessage:message];
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
    XMPPLogTrace();
    
    if (![presence wasDelayed]) {
        return;
    }
    
    XMPPLogInfo(@"Received delayed delivery presence with date: %@, origin: %@, reason description: %@",
                [presence delayedDeliveryDate],
                [presence delayedDeliveryFrom] ?: @"unspecified",
                [presence delayedDeliveryReasonDescription] ?: @"unspecified");
    
    [multicastDelegate xmppDelayedDelivery:self didReceiveDelayedPresence:presence];
}

@end
