#import <XCTest/XCTest.h>
#import "XMPPMockStream.h"

@interface XMPPOutOfBandResourceMessagingTests : XCTestCase <XMPPOutOfBandResourceMessagingDelegate>

@property (strong, nonatomic) XMPPMockStream *mockStream;
@property (strong, nonatomic) XMPPOutOfBandResourceMessaging *outOfBandResourceMessaging;
@property (strong, nonatomic) XCTestExpectation *delegateCallbackExpectation;

@end

@implementation XMPPOutOfBandResourceMessagingTests

- (void)setUp
{
    [super setUp];
    self.mockStream = [[XMPPMockStream alloc] init];
    self.outOfBandResourceMessaging = [[XMPPOutOfBandResourceMessaging alloc] init];
    [self.outOfBandResourceMessaging addDelegate:self delegateQueue:dispatch_get_main_queue()];
    [self.outOfBandResourceMessaging activate:self.mockStream];
}

- (void)testDelegateCallback
{
    self.delegateCallbackExpectation = [self expectationWithDescription:@"Delegate callback received"];
    
    [self fakeOutOfBandResourceMessage];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testURLSchemeFiltering
{
    self.outOfBandResourceMessaging.relevantURLSchemes = [NSSet setWithObject:@"ftp"];
    self.delegateCallbackExpectation = [self expectationWithDescription:@"Delegate callback not received"];
    self.delegateCallbackExpectation.inverted = YES;
    
    [self fakeOutOfBandResourceMessage];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)xmppOutOfBandResourceMessaging:(XMPPOutOfBandResourceMessaging *)xmppOutOfBandResourceMessaging didReceiveOutOfBandResourceMessage:(XMPPMessage *)message
{
    if ([[message body] isEqualToString:@"Yeah, but do you have a license to Jabber?"]) {
        [self.delegateCallbackExpectation fulfill];
    }
}

- (void)fakeOutOfBandResourceMessage
{
    [self.mockStream fakeMessageResponse:
     [[XMPPMessage alloc] initWithXMLString:
      @"<message from='stpeter@jabber.org/work'"
      @"           to='MaineBoy@jabber.org/home'>"
      @"  <body>Yeah, but do you have a license to Jabber?</body>"
      @"  <x xmlns='jabber:x:oob'>"
      @"    <url>http://www.jabber.org/images/psa-license.jpg</url>"
      @"    <desc>A license to Jabber!</desc>"
      @"  </x>"
      @"</message>"
                                      error:nil]];
}

@end
