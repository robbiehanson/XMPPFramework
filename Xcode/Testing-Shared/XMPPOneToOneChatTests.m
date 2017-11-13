#import <XCTest/XCTest.h>
#import "XMPPMockStream.h"

@interface XMPPOneToOneChatTests : XCTestCase <XMPPOneToOneChatDelegate>

@property (nonatomic, strong) XMPPMockStream *mockStream;
@property (nonatomic, strong) XMPPOneToOneChat *oneToOneChat;
@property (nonatomic, strong) XCTestExpectation *delegateCallbackExpectation;

@end

@implementation XMPPOneToOneChatTests

- (void)setUp
{
    [super setUp];
    self.mockStream = [[XMPPMockStream alloc] init];
    self.oneToOneChat = [[XMPPOneToOneChat alloc] init];
    [self.oneToOneChat addDelegate:self delegateQueue:dispatch_get_main_queue()];
    [self.oneToOneChat activate:self.mockStream];
}

- (void)testIncomingMessageHandling
{
    self.delegateCallbackExpectation = [self expectationWithDescription:@"Incoming message delegate callback expectation"];
    
    XMPPMessage *chatMessage = [[XMPPMessage alloc] initWithXMLString:
                                @"<message from='juliet@example.com'"
                                @"         to='romeo@example.net'"
                                @"         type='chat'>"
                                @"  <body>Art thou not Romeo, and a Montague?</body>"
                                @"</message>"
                                                                error:nil];
    
    XMPPMessage *emptyMessage = [[XMPPMessage alloc] initWithXMLString:
                                 @"<message from='juliet@example.com' to='romeo@example.net'/>"
                                                                 error:nil];
    
    [self.mockStream fakeMessageResponse:chatMessage];
    [self.mockStream fakeMessageResponse:emptyMessage];
    
    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testOutgoingMessageHandling
{
    self.delegateCallbackExpectation = [self expectationWithDescription:@"Sent message delegate callback expectation"];
    
    XMPPMessage *chatMessage = [[XMPPMessage alloc] initWithXMLString:
                                @"<message to='romeo@example.net'"
                                @"         type='chat'>"
                                @"  <body>Art thou not Romeo, and a Montague?</body>"
                                @"</message>"
                                                                error:nil];
    
    XMPPMessage *emptyMessage = [[XMPPMessage alloc] initWithXMLString:
                                 @"<message to='romeo@example.net'/>"
                                                                 error:nil];
    
    [self.mockStream sendElement:chatMessage];
    [self.mockStream sendElement:emptyMessage];
    
    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)xmppOneToOneChat:(XMPPOneToOneChat *)xmppOneToOneChat didReceiveChatMessage:(XMPPMessage *)message
{
    [self.delegateCallbackExpectation fulfill];
}

- (void)xmppOneToOneChat:(XMPPOneToOneChat *)xmppOneToOneChat didSendChatMessage:(XMPPMessage *)message
{
    [self.delegateCallbackExpectation fulfill];
}

@end
