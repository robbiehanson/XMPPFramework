#import "XMPPOneToOneChat.h"
#import "XMPPMessage.h"
#import "XMPPStream.h"
#import "XMPPLogging.h"

// Log levels: off, error, warn, info, verbose
// Log flags: trace
#if DEBUG
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;
#else
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

@implementation XMPPOneToOneChat

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
    XMPPLogTrace();
    
    if (![message isChatMessage]) {
        return;
    }
    
    XMPPLogInfo(@"Received chat message from %@", [message from]);
    [multicastDelegate xmppOneToOneChat:self didReceiveChatMessage:message];
}

- (void)xmppStream:(XMPPStream *)sender didSendMessage:(XMPPMessage *)message
{
    XMPPLogTrace();
    
    if (![message isChatMessage]) {
        return;
    }
    
    XMPPLogInfo(@"Sent chat message to %@", [message to]);
    [multicastDelegate xmppOneToOneChat:self didSendChatMessage:message];
}

@end
