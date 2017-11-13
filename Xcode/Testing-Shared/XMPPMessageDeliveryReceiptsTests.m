#import <XCTest/XCTest.h>
#import "XMPPMockStream.h"

@interface XMPPMessageDeliveryReceiptsTests : XCTestCase <XMPPMessageDeliveryReceiptsDelegate>

@property (strong, nonatomic) XMPPMockStream *mockStream;
@property (strong, nonatomic) XMPPMessageDeliveryReceipts *messageDeliveryReceipts;
@property (strong, nonatomic) XCTestExpectation *delegateCallbackExpectation;

@end

@implementation XMPPMessageDeliveryReceiptsTests

- (void)setUp
{
    [super setUp];
    self.mockStream = [[XMPPMockStream alloc] init];
    self.messageDeliveryReceipts = [[XMPPMessageDeliveryReceipts alloc] init];
    [self.messageDeliveryReceipts addDelegate:self delegateQueue:dispatch_get_main_queue()];
    [self.messageDeliveryReceipts activate:self.mockStream];
}

- (void)testReceiptResponseDelegateCallback
{
    self.delegateCallbackExpectation = [self expectationWithDescription:@"Delegate callback expectation"];
    
    [self.mockStream fakeMessageResponse:
     [[XMPPMessage alloc] initWithXMLString:
      @"<message"
      @"    from='kingrichard@royalty.england.lit/throne'"
      @"    id='bi29sg183b4v'"
      @"    to='northumberland@shakespeare.lit/westminster'>"
      @"  <received xmlns='urn:xmpp:receipts' id='richard2-4.1.247'/>"
      @"</message>"
                                      error:nil]];
    
    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)xmppMessageDeliveryReceipts:(XMPPMessageDeliveryReceipts *)xmppMessageDeliveryReceipts didReceiveReceiptResponseMessage:(XMPPMessage *)message
{
    if ([message hasReceiptResponse]) {
        [self.delegateCallbackExpectation fulfill];
    }
}

@end
