#import "XMPPOutOfBandResourceMessaging.h"
#import "XMPPMessage+XEP_0066.h"
#import "XMPPStream.h"
#import "XMPPLogging.h"

// Log levels: off, error, warn, info, verbose
// Log flags: trace
#if DEBUG
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;
#else
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

@implementation XMPPOutOfBandResourceMessaging

@synthesize relevantURLSchemes = _relevantURLSchemes;

- (NSSet<NSString *> *)relevantURLSchemes
{
    __block NSSet *result;
    dispatch_block_t block = ^{
        result = _relevantURLSchemes;
    };
    
    if (dispatch_get_specific(moduleQueueTag))
        block();
    else
        dispatch_sync(moduleQueue, block);
    
    return result;
}

- (void)setRelevantURLSchemes:(NSSet<NSString *> *)relevantURLSchemes
{
    NSSet *newValue = [relevantURLSchemes copy];
    dispatch_block_t block = ^{
        _relevantURLSchemes = newValue;
    };
    
    if (dispatch_get_specific(moduleQueueTag))
        block();
    else
        dispatch_async(moduleQueue, block);
}

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
    
    if (![message hasOutOfBandData]) {
        return;
    }
    
    NSString *resourceURIString = [message outOfBandURI];
    if (self.relevantURLSchemes) {
        NSURL *resourceURL = [NSURL URLWithString:resourceURIString];
        if (!resourceURL.scheme || ![self.relevantURLSchemes containsObject:resourceURL.scheme]) {
            return;
        }
    }
    
    XMPPLogInfo(@"Received out of band resource message");
    [multicastDelegate xmppOutOfBandResourceMessaging:self didReceiveOutOfBandResourceMessage:message];
}

@end
