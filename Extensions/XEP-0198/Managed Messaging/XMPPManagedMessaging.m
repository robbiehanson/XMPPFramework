#import "XMPPManagedMessaging.h"
#import "XMPPStreamManagement.h"
#import "XMPPLogging.h"

// Log levels: off, error, warn, info, verbose
// Log flags: trace
#if DEBUG
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;
#else
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

static NSString * const XMPPManagedMessagingURLScheme = @"xmppmanagedmessage";

@implementation XMPPManagedMessaging

- (void)didActivate
{
    XMPPLogTrace();
    [self.xmppStream autoAddDelegate:self delegateQueue:self.moduleQueue toModulesOfClass:[XMPPStreamManagement class]];
}

- (void)willDeactivate
{
    XMPPLogTrace();
    [self.xmppStream removeAutoDelegate:self delegateQueue:self.moduleQueue fromModulesOfClass:[XMPPStreamManagement class]];
}

- (void)xmppStream:(XMPPStream *)sender didSendMessage:(XMPPMessage *)message
{
    XMPPLogTrace();
    
    if (![message elementID]) {
        XMPPLogWarn(@"Sent message without an ID excluded from managed messaging");
        return;
    }
    
    XMPPLogInfo(@"Registering message with ID=%@ for managed messaging", [message elementID]);
    [multicastDelegate xmppManagedMessaging:self didBeginMonitoringOutgoingMessage:message];
}

- (id)xmppStreamManagement:(XMPPStreamManagement *)sender stanzaIdForSentElement:(XMPPElement *)element
{
    if (![element isKindOfClass:[XMPPMessage class]] || ![element elementID]) {
        return nil;
    }
    
    NSURLComponents *managedMessageURLComponents = [[NSURLComponents alloc] init];
    managedMessageURLComponents.scheme = XMPPManagedMessagingURLScheme;
    managedMessageURLComponents.path = [element elementID];
    
    return managedMessageURLComponents.URL;
}

- (void)xmppStreamManagement:(XMPPStreamManagement *)sender didReceiveAckForStanzaIds:(NSArray *)stanzaIds
{
    XMPPLogTrace();
    
    NSArray *resumeStanzaIDs;
    [sender didResumeWithAckedStanzaIds:&resumeStanzaIDs serverResponse:nil];
    if ([resumeStanzaIDs isEqualToArray:stanzaIds]) {
        // Handled in -xmppStreamDidAuthenticate:
        return;
    }
    
    [self processStreamManagementAcknowledgementForStanzaIDs:stanzaIds];
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
    XMPPLogTrace();
    
    dispatch_group_t stanzaAcknowledgementGroup = dispatch_group_create();
    
    [sender enumerateModulesOfClass:[XMPPStreamManagement class] withBlock:^(XMPPModule *module, NSUInteger idx, BOOL *stop) {
        NSArray *acknowledgedStanzaIDs;
        [(XMPPStreamManagement *)module didResumeWithAckedStanzaIds:&acknowledgedStanzaIDs serverResponse:nil];
        if (acknowledgedStanzaIDs.count == 0) {
            return;
        }
        
        dispatch_group_async(stanzaAcknowledgementGroup, self.moduleQueue, ^{
            [self processStreamManagementAcknowledgementForStanzaIDs:acknowledgedStanzaIDs];
        });
    }];
    
    dispatch_group_notify(stanzaAcknowledgementGroup, self.moduleQueue, ^{
        [multicastDelegate xmppManagedMessagingDidFinishProcessingPreviousStreamConfirmations:self];
    });
}

- (void)processStreamManagementAcknowledgementForStanzaIDs:(NSArray *)stanzaIDs
{
    NSMutableArray *managedMessageIDs = [NSMutableArray array];
    for (id stanzaID in stanzaIDs) {
        if (![stanzaID isKindOfClass:[NSURL class]] || ![((NSURL *)stanzaID).scheme isEqualToString:XMPPManagedMessagingURLScheme]) {
            continue;
        }
        // Extracting path directly from NSURL does not work if it doesn't start with "/"
        NSURLComponents *managedMessageURLComponents = [[NSURLComponents alloc] initWithURL:stanzaID resolvingAgainstBaseURL:NO];
        [managedMessageIDs addObject:managedMessageURLComponents.path];
    }
    
    if (managedMessageIDs.count == 0) {
        return;
    }
    
    XMPPLogInfo(@"Confirming managed messages with IDs={%@}", [managedMessageIDs componentsJoinedByString:@","]);
    [multicastDelegate xmppManagedMessaging:self didConfirmSentMessagesWithIDs:managedMessageIDs];
}

@end
