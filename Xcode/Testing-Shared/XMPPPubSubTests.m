#import <XCTest/XCTest.h>
#import "XMPPMockStream.h"

@interface XMPPPubSubTests : XCTestCase <XMPPPubSubDelegate>

@property (nonatomic, strong) XMPPMockStream *testStream;
@property (nonatomic, strong) XMPPPubSub *pepPubSub;
@property (nonatomic, strong) NSMutableArray<XMPPMessage *> *delegateMessages;

@end

@implementation XMPPPubSubTests

- (void)setUp {
    [super setUp];

    self.testStream = [[XMPPMockStream alloc] init];
    
    self.pepPubSub = [[XMPPPubSub alloc] initWithServiceJID:nil];
    [self.pepPubSub addDelegate:self delegateQueue:self.pepPubSub.moduleQueue];
    [self.pepPubSub activate:self.testStream];
    
    self.delegateMessages = [[NSMutableArray alloc] init];
}

- (void)testPEPPublisherFiltering {
    NSString *allowedPublisherJIDString = @"test.user@erlang-solutions.com";
    NSString *filteredPublisherJIDString = @"unknown@erlang-solutions.com";
    
    self.pepPubSub.pepPublisherJIDs = @[[XMPPJID jidWithString:allowedPublisherJIDString]];
    
    XCTestExpectation *delegateExpectation = [self expectationWithDescription:@"PEP publisher filter expectation"];
    
    [self fakePEPEventMessageWithPublisherJIDString:allowedPublisherJIDString node:@"pep_node"];
    [self fakePEPEventMessageWithPublisherJIDString:filteredPublisherJIDString node:@"pep_node"];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        XCTAssertEqual(self.delegateMessages.count, 1);
        XCTAssertEqualObjects([[self.delegateMessages.firstObject from] full], allowedPublisherJIDString);
        [delegateExpectation fulfill];
    });
    
    [self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error: %@", error);
        }
    }];
}

- (void)testPEPNodeFiltering {
    NSString *allowedNode = @"pep_node";
    NSString *allowedNodePublisherJIDString = @"test.user@erlang-solutions.com";
    NSString *filteredNode = @"unknown_node";
    
    self.pepPubSub.pepNodes = @[allowedNode];
    
    XCTestExpectation *delegateExpectation = [self expectationWithDescription:@"PEP node filter expectation"];
    
    [self fakePEPEventMessageWithPublisherJIDString:allowedNodePublisherJIDString node:allowedNode];
    [self fakePEPEventMessageWithPublisherJIDString:@"unknown@erlang-solutions.com" node:filteredNode];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        XCTAssertEqual(self.delegateMessages.count, 1);
        XCTAssertEqualObjects([[self.delegateMessages.firstObject from] full], allowedNodePublisherJIDString);
        [delegateExpectation fulfill];
    });
    
    [self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error: %@", error);
        }
    }];
}

- (void)xmppPubSub:(XMPPPubSub *)sender didReceiveMessage:(XMPPMessage *)message
{
    [self.delegateMessages addObject:message];
}

- (void)fakePEPEventMessageWithPublisherJIDString:(NSString *)publisherJIDString node:(NSString *)node {
    NSMutableString *s = [NSMutableString string];
    [s appendFormat:@"<message from='%@'>", publisherJIDString];
    [s appendString:@"   <event xmlns='http://jabber.org/protocol/pubsub#event'>"];
    [s appendFormat:@"      <items node='%@'>", node];
    [s appendString:@"         <item/>"];
    [s appendString:@"      </items>"];
    [s appendString:@"   </event>"];
    [s appendString:@"</message>"];
    
    NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:NULL];
    [self.testStream fakeMessageResponse:[XMPPMessage messageFromElement:[doc rootElement]]];
}

@end
