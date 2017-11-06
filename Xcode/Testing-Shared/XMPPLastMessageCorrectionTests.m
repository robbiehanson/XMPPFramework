#import <XCTest/XCTest.h>
#import "XMPPMockStream.h"

@interface XMPPLastMessageCorrectionTests : XCTestCase <XMPPStreamDelegate, XMPPLastMessageCorrectionDelegate>

@property (nonatomic, strong) XMPPMockStream *mockStream;
@property (nonatomic, strong) XMPPLastMessageCorrection *lastMessageCorrection;
@property (nonatomic, strong) XCTestExpectation *delegateCallbackExpectation;
@property (nonatomic, strong) XCTestExpectation *outgoingMessageModuleProcessingScheduledExpectation;

@end

@implementation XMPPLastMessageCorrectionTests

- (void)setUp
{
    [super setUp];
    
    self.mockStream = [[XMPPMockStream alloc] init];
    self.mockStream.myJID = [XMPPJID jidWithString:@"romeo@montague.net/home"];
    [self.mockStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
    self.lastMessageCorrection = [[XMPPLastMessageCorrection alloc] init];
    [self.lastMessageCorrection addDelegate:self delegateQueue:dispatch_get_main_queue()];
    [self.lastMessageCorrection activate:self.mockStream];
}

- (void)testIncomingMessageCorrection
{
    self.delegateCallbackExpectation = [self expectationWithDescription:@"Incoming message correction filtering delegate callback expectation"];
    
    [self fakeIncomingMessageWithID:@"bad"
                               body:@"O Romeo, Romeo! wherefore art thee Romeo?"
                 correctedMessageID:nil
                          senderJID:[XMPPJID jidWithString:@"juliet@capulet.net/balcony1"]];
    
    [self fakeIncomingMessageWithID:@"good"
                               body:@"O Romeo, Romeo! wherefore art thou Romeo?"
                 correctedMessageID:@"bad"
                          senderJID:[XMPPJID jidWithString:@"juliet@capulet.net/balcony1"]];
    
    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)xmppLastMessageCorrection:(XMPPLastMessageCorrection *)xmppLastMessageCorrection didReceiveCorrectedMessage:(XMPPMessage *)correctedMessage
{
    if ([[correctedMessage elementID] isEqualToString:@"good"]) {
        [self.delegateCallbackExpectation fulfill];
    }
}

- (void)testOutgoingMessageCorrectionEligibilty
{
    self.outgoingMessageModuleProcessingScheduledExpectation = [self expectationWithDescription:@"Fake messages sent"];
    self.outgoingMessageModuleProcessingScheduledExpectation.expectedFulfillmentCount = 3;
    
    [self fakeSendingMessageWithID:@"bad1" recipientJID:[XMPPJID jidWithString:@"juliet@capulet.net/balcony1"]];
    [self fakeSendingMessageWithID:@"bad2" recipientJID:[XMPPJID jidWithString:@"juliet@capulet.net/balcony2"]];
    [self fakeSendingMessageWithID:@"bad3" recipientJID:[XMPPJID jidWithString:@"nurse@capulet.net/balcony"]];
    [self waitForExpectationsWithTimeout:5 handler:nil];
    
    XCTAssertFalse([self.lastMessageCorrection canCorrectSentMessageWithID:@"bad1"]);
    XCTAssertTrue([self.lastMessageCorrection canCorrectSentMessageWithID:@"bad2"]);
    XCTAssertTrue([self.lastMessageCorrection canCorrectSentMessageWithID:@"bad3"]);
}

- (void)testMUCPostRejoinOutgoingMessageCorrectionEligibilty
{
    self.outgoingMessageModuleProcessingScheduledExpectation = [self expectationWithDescription:@"Fake message sent"];
    
    [self fakeSendingMessageWithID:@"bad1" recipientJID:[XMPPJID jidWithString:@"coven@chat.shakespeare.lit"]];
    [self waitForExpectationsWithTimeout:5 handler:nil];
    
    [self fakeRejoiningMUCRoomWithJID:[XMPPJID jidWithString:@"coven@chat.shakespeare.lit"]];
    
    XCTAssertFalse([self.lastMessageCorrection canCorrectSentMessageWithID:@"bad1"]);
}

- (void)testMUCLightPostRejoinOutgoingMessageCorrectionEligibilty
{
    self.outgoingMessageModuleProcessingScheduledExpectation = [self expectationWithDescription:@"Fake message sent"];
    
    [self fakeSendingMessageWithID:@"bad1" recipientJID:[XMPPJID jidWithString:@"coven@muclight.shakespeare.lit"]];
    [self waitForExpectationsWithTimeout:5 handler:nil];
    
    [self fakeRejoiningMUCLightRoomWithJID:[XMPPJID jidWithString:@"coven@muclight.shakespeare.lit"]];
    
    XCTAssertFalse([self.lastMessageCorrection canCorrectSentMessageWithID:@"bad1"]);
}

- (void)xmppStream:(XMPPStream *)sender didSendMessage:(XMPPMessage *)message
{
    dispatch_async(sender.xmppQueue, ^{
        [self.outgoingMessageModuleProcessingScheduledExpectation fulfill];
    });
}

- (void)testCapabilitiesReporting
{
    NSXMLElement *capabilitiesQuery = [self fakeCapabilitiesQuery];
    
    NSInteger messageCorrectionFeatureElementCount = 0;
    for (NSXMLElement *child in capabilitiesQuery.children) {
        if ([child.name isEqualToString:@"feature"] &&
            [[child attributeForName:@"var"].stringValue isEqualToString:@"urn:xmpp:message-correct:0"]) {
            ++messageCorrectionFeatureElementCount;
        }
    }
    
    XCTAssertEqual(messageCorrectionFeatureElementCount, 1);
}

- (void)fakeSendingMessageWithID:(NSString *)messageID recipientJID:(XMPPJID *)toJID
{
    [self.mockStream sendElement:
     [[XMPPMessage alloc] initWithXMLString:
      [NSString stringWithFormat:
       @"<message to='%@' id='%@'>"
       @"  <body>But soft, what light through yonder airlock breaks?</body>"
       @"</message>", [toJID full], messageID]
                                      error:nil]];
}

- (void)fakeIncomingMessageWithID:(NSString *)messageID body:(NSString *)body correctedMessageID:(NSString *)correctedMessageID senderJID:(XMPPJID *)senderJID
{
    XMPPMessage *fakeMessage = [[XMPPMessage alloc] initWithXMLString:
                                [NSString stringWithFormat:
                                 @"<message from='%@' to='romeo@montague.net/home' id='%@'>"
                                 @"  <body>O Romeo, Romeo! wherefore art thou Romeo?</body>"
                                 @"</message>", [senderJID full], messageID]
                                                                error:nil];
    if (correctedMessageID) {
        [fakeMessage addChild:[[NSXMLElement alloc] initWithXMLString:
                               [NSString stringWithFormat:
                                @"<replace id='%@' xmlns='urn:xmpp:message-correct:0'/>", correctedMessageID]
                                                                error:nil]];
    }
    [self.mockStream fakeMessageResponse:fakeMessage];
}

- (void)fakeRejoiningMUCRoomWithJID:(XMPPJID *)roomJID
{
    XMPPRoom *fakeRoom = [[XMPPRoom alloc] initWithRoomStorage:[[XMPPRoomMemoryStorage alloc] init] jid:roomJID];
    [fakeRoom activate:self.mockStream];
    
    dispatch_sync(self.mockStream.xmppQueue, ^{
        [(id)fakeRoom.multicastDelegate xmppRoomDidJoin:fakeRoom];
    });
}

- (void)fakeRejoiningMUCLightRoomWithJID:(XMPPJID *)roomJID
{
    XMPPMUCLight *fakeMUCLight = [[XMPPMUCLight alloc] init];
    [fakeMUCLight activate:self.mockStream];
    
    dispatch_sync(self.mockStream.xmppQueue, ^{
        [[fakeMUCLight valueForKey:@"multicastDelegate"] xmppMUCLight:fakeMUCLight
                                                   changedAffiliation:@"member"
                                                              userJID:[self.mockStream.myJID bareJID]
                                                              roomJID:roomJID];
    });
}

- (NSXMLElement *)fakeCapabilitiesQuery
{
    XMPPCapabilities *testCapabilities = [[XMPPCapabilities alloc] initWithCapabilitiesStorage:[[XMPPCapabilitiesCoreDataStorage alloc] initWithInMemoryStore]];
    [testCapabilities activate:self.mockStream];
    
    NSXMLElement *query = [[NSXMLElement alloc] initWithXMLString:@"<query xmlns='http://jabber.org/protocol/disco#info'/>" error:nil];
    
    dispatch_sync(self.mockStream.xmppQueue, ^{
        GCDMulticastDelegateEnumerator *delegateEnumerator = [[testCapabilities valueForKey:@"multicastDelegate"] delegateEnumerator];
        id delegate;
        dispatch_queue_t delegateQueue;
        while ([delegateEnumerator getNextDelegate:&delegate delegateQueue:&delegateQueue forSelector:@selector(xmppCapabilities:collectingMyCapabilities:)]) {
            dispatch_sync(delegateQueue, ^{
                [delegate xmppCapabilities:testCapabilities collectingMyCapabilities:query];
            });
        }
    });
    
    return query;
}

@end
