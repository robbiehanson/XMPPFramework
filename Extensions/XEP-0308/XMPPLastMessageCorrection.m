#import "XMPPLastMessageCorrection.h"
#import "XMPPCapabilities.h"
#import "XMPPRoom.h"
#import "XMPPMUCLight.h"
#import "XMPPMessage+XEP_0308.h"
//#import "XMPPJID.h"
#import "XMPPLogging.h"

// Log levels: off, error, warn, info, verbose
// Log flags: trace
#if DEBUG
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;
#else
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

static NSString * const XMPPLastMessageCorrectionNamespace = @"urn:xmpp:message-correct:0";

@interface XMPPLastMessageCorrection ()

@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, NSString *> *sentMessageIDIndex;

@end

@implementation XMPPLastMessageCorrection

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
    self = [super initWithDispatchQueue:queue];
    if (self) {
        _sentMessageIDIndex = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (BOOL)canCorrectSentMessageWithID:(NSString *)messageID
{
    __block BOOL result;
    dispatch_block_t block = ^{
        result =  [self.sentMessageIDIndex.allValues containsObject:messageID];
    };
    
    if (dispatch_get_specific(moduleQueueTag))
        block();
    else
        dispatch_sync(moduleQueue, block);
    
    return result;
}

- (void)didActivate
{
    XMPPLogTrace();
    
    [self.xmppStream autoAddDelegate:self delegateQueue:self.moduleQueue toModulesOfClass:[XMPPCapabilities class]];
    [self.xmppStream autoAddDelegate:self delegateQueue:self.moduleQueue toModulesOfClass:[XMPPRoom class]];
    [self.xmppStream autoAddDelegate:self delegateQueue:self.moduleQueue toModulesOfClass:[XMPPMUCLight class]];
}

- (void)willDeactivate
{
    XMPPLogTrace();
    
    [self.sentMessageIDIndex removeAllObjects];
    [self.xmppStream removeAutoDelegate:self delegateQueue:self.moduleQueue fromModulesOfClass:[XMPPCapabilities class]];
    [self.xmppStream removeAutoDelegate:self delegateQueue:self.moduleQueue fromModulesOfClass:[XMPPRoom class]];
    [self.xmppStream removeAutoDelegate:self delegateQueue:self.moduleQueue fromModulesOfClass:[XMPPMUCLight class]];
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
    XMPPLogTrace();
    
    if (![message isMessageCorrection]) {
        return;
    }
    
    XMPPLogInfo(@"Received correction for message with ID: %@", [message correctedMessageID]);
    [multicastDelegate xmppLastMessageCorrection:self didReceiveCorrectedMessage:message];
}

- (void)xmppStream:(XMPPStream *)sender didSendMessage:(XMPPMessage *)message
{
    XMPPLogTrace();
    
    self.sentMessageIDIndex[[[message to] bare]] = [message elementID];
    XMPPLogInfo(@"Updated last sent message ID for %@", [[message to] bare]);
}

- (void)xmppStreamDidChangeMyJID:(XMPPStream *)xmppStream
{
    XMPPLogTrace();
    
    [self.sentMessageIDIndex removeAllObjects];
    XMPPLogInfo(@"My JID changed, resetting sent message ID index");
}

- (void)xmppCapabilities:(XMPPCapabilities *)sender collectingMyCapabilities:(NSXMLElement *)query
{
    XMPPLogTrace();
    
    NSXMLElement *lastMessageCorrectionFeatureElement = [NSXMLElement elementWithName:@"feature"];
    [lastMessageCorrectionFeatureElement addAttributeWithName:@"var" stringValue:XMPPLastMessageCorrectionNamespace];
    [query addChild:lastMessageCorrectionFeatureElement];
}

- (void)xmppRoomDidJoin:(XMPPRoom *)sender
{
    XMPPLogTrace();
    [self.sentMessageIDIndex removeObjectForKey:[sender.roomJID bare]];
    XMPPLogInfo(@"Reset last sent message ID for MUC room %@", [sender.roomJID bare]);
}

- (void)xmppMUCLight:(XMPPMUCLight *)sender changedAffiliation:(NSString *)affiliation userJID:(XMPPJID *)userJID roomJID:(XMPPJID *)roomJID
{
    XMPPLogTrace();
    
    if ([affiliation isEqualToString:@"none"]) {
        return;
    }
    
    // TODO: member->owner and owner->member transitions should not break message correction continuity
    if (![userJID isEqualToJID:sender.xmppStream.myJID options:XMPPJIDCompareBare]) {
        return;
    }
    
    [self.sentMessageIDIndex removeObjectForKey:[roomJID bare]];
    XMPPLogInfo(@"Reset last sent message ID for MUC Light room %@", [roomJID bare]);
}

@end
