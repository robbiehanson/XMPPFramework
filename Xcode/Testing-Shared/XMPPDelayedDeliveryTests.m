#import <XCTest/XCTest.h>
#import "XMPPMockStream.h"

@class XMPPDelayedDeliveryTestCallbackResult;

@interface XMPPDelayedDeliveryTests : XCTestCase <XMPPDelayedDeliveryDelegate>

@property (nonatomic, strong) XMPPMockStream *mockStream;
@property (nonatomic, strong) XMPPDelayedDelivery *delayedDelivery;
@property (nonatomic, strong) XCTestExpectation *delegateCallbackExpectation;

@end

@implementation XMPPDelayedDeliveryTests

- (void)setUp {
    [super setUp];
    
    self.mockStream = [[XMPPMockStream alloc] init];
    
    self.delayedDelivery = [[XMPPDelayedDelivery alloc] init];
    [self.delayedDelivery addDelegate:self delegateQueue:dispatch_get_main_queue()];
    [self.delayedDelivery activate:self.mockStream];
}

- (void)testMessageDelegateCallback
{
    self.delegateCallbackExpectation = [self expectationWithDescription:@"Test message delegate callback expectation"];
    
    [self fakeDelayedDeliveryMessage];
    
    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testPresenceDelegateCallback
{
    self.delegateCallbackExpectation = [self expectationWithDescription:@"Test presence delegate callback expectation"];
    
    [self fakeDelayedDeliveryPresence];
    
    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testStanzaSkipping
{
    self.delegateCallbackExpectation = [self expectationWithDescription:@"Test skipped delegate callback expectation"];
    self.delegateCallbackExpectation.inverted = YES;
    
    [self fakePlainMessage];
    [self fakePlainPresence];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)xmppDelayedDelivery:(XMPPDelayedDelivery *)xmppDelayedDelivery didReceiveDelayedMessage:(XMPPMessage *)delayedMessage
{
    if ([self.delegateCallbackExpectation isInverted] ||
        ([[delayedMessage delayedDeliveryDate] isEqualToDate:[NSDate dateWithXmppDateTimeString:@"2002-09-10T23:08:25Z"]]
         && [[delayedMessage delayedDeliveryFrom] isEqualToJID:[XMPPJID jidWithString:@"capulet.com"]]
         && [[delayedMessage delayedDeliveryReasonDescription] isEqualToString:@"Offline Storage"])) {
            [self.delegateCallbackExpectation fulfill];
        }
}

- (void)xmppDelayedDelivery:(XMPPDelayedDelivery *)xmppDelayedDelivery didReceiveDelayedPresence:(XMPPPresence *)delayedPresence
{
    if ([self.delegateCallbackExpectation isInverted] ||
        ([[delayedPresence delayedDeliveryDate] isEqualToDate:[NSDate dateWithXmppDateTimeString:@"2002-09-10T23:41:07Z"]]
         && [[delayedPresence delayedDeliveryFrom] isEqualToJID:[XMPPJID jidWithString:@"juliet@capulet.com/balcony"]]
         && [[delayedPresence delayedDeliveryReasonDescription] isEqualToString:@""])) {
            [self.delegateCallbackExpectation fulfill];
        }
}

- (void)fakeDelayedDeliveryMessage
{
    [self.mockStream fakeMessageResponse:
     [[XMPPMessage alloc] initWithXMLString:
      @"<message from='romeo@montague.net/orchard' to='juliet@capulet.com' type='chat'>"
      @"<body>"
      @"O blessed, blessed night! I am afeard."
      @"Being in night, all this is but a dream,"
      @"Too flattering-sweet to be substantial."
      @"</body>"
      @"<delay xmlns='urn:xmpp:delay' from='capulet.com' stamp='2002-09-10T23:08:25Z'>"
      @"Offline Storage"
      @"</delay>"
      @"</message>"
                                      error:nil]];
}

- (void)fakeDelayedDeliveryPresence
{
    [self.mockStream fakeResponse:
     [[XMPPPresence alloc] initWithXMLString:
      @"<presence from='juliet@capulet.com/balcony' to='romeo@montague.net'>"
      @"<status>anon!</status>"
      @"<show>xa</show>"
      @"<priority>1</priority>"
      @"<delay xmlns='urn:xmpp:delay' from='juliet@capulet.com/balcony' stamp='2002-09-10T23:41:07Z'/>"
      @"</presence>"
                                       error:nil]];
}

- (void)fakePlainMessage
{
    [self.mockStream fakeMessageResponse:
     [[XMPPMessage alloc] initWithXMLString:
      @"<message from='romeo@montague.net/orchard' to='juliet@capulet.com' type='chat'>"
      @"<body>"
      @"O blessed, blessed night! I am afeard."
      @"Being in night, all this is but a dream,"
      @"Too flattering-sweet to be substantial."
      @"</body>"
      @"</message>"
                                      error:nil]];
}

- (void)fakePlainPresence
{
    [self.mockStream fakeResponse:
     [[XMPPPresence alloc] initWithXMLString:
      @"<presence from='juliet@capulet.com/balcony' to='romeo@montague.net'>"
      @"<status>anon!</status>"
      @"<show>xa</show>"
      @"<priority>1</priority>"
      @"</presence>"
                                       error:nil]];
}

@end
