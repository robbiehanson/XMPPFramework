//
//  XMPPvCardTests.m
//  XMPPFrameworkTests
//
//  Created by Chris Ballinger on 6/22/16.
//
//

#import <XCTest/XCTest.h>
#import "XMPPMockStream.h"
#import "XMPPvCardTempModule.h"
#import "XMPPvCardCoreDataStorage.h"

@interface XMPPvCardTests : XCTestCase
@property (nonatomic, strong) XCTestExpectation *expectation;
@end

@implementation XMPPvCardTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testVcardFetchFailure {
    self.expectation = [self expectationWithDescription:@"vCard Fetch Failure"];
    
    NSString *jidString = @"test@example.com/house";
    XMPPJID *myJID = [XMPPJID jidWithString:jidString];
    XMPPMockStream *stream = [[XMPPMockStream alloc] init];
    stream.myJID = myJID;
    XMPPvCardCoreDataStorage *storage = [[XMPPvCardCoreDataStorage alloc] initWithInMemoryStore];
    XMPPvCardTempModule *vcardModule = [[XMPPvCardTempModule alloc] initWithvCardStorage:storage];
    [vcardModule addDelegate:self delegateQueue:dispatch_get_main_queue()];
    [vcardModule activate:stream];
    
    __weak typeof(XMPPMockStream) *weakStreamTest = stream;
    stream.elementReceived = ^void(NSXMLElement *element) {
        NSLog(@"received element: %@", element);
        XMPPIQ *iq = [XMPPIQ iqFromElement:element];
        NSString *eid = [iq elementID];
        XMPPIQ *response = [self fakeFetchErrorWithElementId:eid jidString:jidString];
        NSLog(@"sending response: %@", response);
        [weakStreamTest fakeIQResponse:response];
    };
    
    [vcardModule fetchvCardTempForJID:myJID];
    
    [self waitForExpectationsWithTimeout:60 handler:^(NSError * _Nullable error) {
        if(error){
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

- (XMPPIQ*) fakeFetchErrorWithElementId:(NSString*)elementId jidString:(NSString*)jidString {
    NSString * errorString =
    [NSString stringWithFormat:@"<iq id='%@'\
    to='%@'\
    type='error'>\
    <vCard xmlns='vcard-temp'/>\
    <error type='cancel'>\
    <service-unavailable xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>\
    </error>\
     </iq>", elementId, jidString];
    NSError *error = nil;
    NSXMLElement *element = [[NSXMLElement alloc] initWithXMLString:errorString error:&error];
    if (error) {
        XCTFail(@"Error: %@", error);
    }
    XMPPIQ *iq = [XMPPIQ iqFromElement:element];
    return iq;
}

#pragma mark XMPPvCardTempModuleDelegate methods

- (void)xmppvCardTempModule:(XMPPvCardTempModule *)vCardTempModule
   failedToFetchvCardForJID:(XMPPJID *)jid
                      error:(NSXMLElement*)error {
    NSLog(@"failedToFetchvCardForJID %@ %@", jid, error);
    [self.expectation fulfill];
}

@end
