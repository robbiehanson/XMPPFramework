//
//  XMPPvCardTests.m
//  XMPPFrameworkTests
//
//  Created by Chris Ballinger on 6/22/16.
//
//

#import <XCTest/XCTest.h>
#import "XMPPMockStream.h"

@interface XMPPvCardTests : XCTestCase
@property (nonatomic, strong) XCTestExpectation *failureExpectation;
@property (nonatomic, strong) XCTestExpectation *successExpectation;

@property (nonatomic, strong) XMPPMockStream *stream;
@property (nonatomic, strong) XMPPvCardTempModule *vcardModule;
@end

@implementation XMPPvCardTests

- (void)setUp {
    [super setUp];
    NSString *jidString = @"test@example.com/house";
    XMPPJID *myJID = [XMPPJID jidWithString:jidString];
    self.stream = [[XMPPMockStream alloc] init];
    self.stream.myJID = myJID;
    XMPPvCardCoreDataStorage *storage = [[XMPPvCardCoreDataStorage alloc] initWithInMemoryStore];
    self.vcardModule = [[XMPPvCardTempModule alloc] initWithvCardStorage:storage];
    [self.vcardModule addDelegate:self delegateQueue:dispatch_get_main_queue()];
    [self.vcardModule activate:self.stream];
}

- (void)tearDown {
    [self.vcardModule removeDelegate:self];
    [self.vcardModule deactivate];
    self.vcardModule = nil;
    self.stream = nil;
    [super tearDown];
}

- (void)testVcardSelfItemNotFound {
    self.failureExpectation = [self expectationWithDescription:@"testVcardItemNotFound"];
    
    __weak typeof(XMPPMockStream) *weakStreamTest = self.stream;
    __weak typeof(self) weakSelf = self;

    self.stream.elementReceived = ^void(NSXMLElement *element) {
        NSLog(@"received element: %@", element);
        XMPPIQ *iq = [XMPPIQ iqFromElement:element];
        NSString *eid = [iq elementID];
        XMPPIQ *response = [weakSelf fakeItemSelfNotFoundWithElementId:eid toJID:weakStreamTest.myJID.bare];
        NSLog(@"sending response: %@", response);
        [weakStreamTest fakeIQResponse:response];
    };
    
    [self.vcardModule fetchvCardTempForJID:self.stream.myJID];
    
    [self waitForExpectationsWithTimeout:60 handler:^(NSError * _Nullable error) {
        if(error){
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

- (void)testVcardSelfEmpty {
    self.failureExpectation = [self expectationWithDescription:@"testVcardEmpty"];
    
    __weak typeof(XMPPMockStream) *weakStreamTest = self.stream;
    __weak typeof(self) weakSelf = self;
    
    self.stream.elementReceived = ^void(NSXMLElement *element) {
        NSLog(@"received element: %@", element);
        XMPPIQ *iq = [XMPPIQ iqFromElement:element];
        NSString *eid = [iq elementID];
        XMPPIQ *response = [weakSelf fakeEmptySelfvCardWithElementId:eid toJID:weakStreamTest.myJID.bare];
        NSLog(@"sending response: %@", response);
        [weakStreamTest fakeIQResponse:response];
    };
    
    [self.vcardModule fetchvCardTempForJID:self.stream.myJID];
    
    [self waitForExpectationsWithTimeout:60 handler:^(NSError * _Nullable error) {
        if(error){
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

- (void) testVcardSelfSuccess {
    self.successExpectation = [self expectationWithDescription:@"testVcardSelfSuccess"];
    
    __weak typeof(XMPPMockStream) *weakStreamTest = self.stream;
    __weak typeof(self) weakSelf = self;
    
    self.stream.elementReceived = ^void(NSXMLElement *element) {
        NSLog(@"received element: %@", element);
        XMPPIQ *iq = [XMPPIQ iqFromElement:element];
        NSString *eid = [iq elementID];
        XMPPIQ *response = [weakSelf fakeSelfvCardWithElementId:eid toJID:weakStreamTest.myJID.bare];
        NSLog(@"sending response: %@", response);
        [weakStreamTest fakeIQResponse:response];
    };
    
    [self.vcardModule fetchvCardTempForJID:self.stream.myJID];
    
    [self waitForExpectationsWithTimeout:60 handler:^(NSError * _Nullable error) {
        if(error){
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

- (void) testVcardContactSuccess {
    self.successExpectation = [self expectationWithDescription:@"testVcardContactSuccess"];
    
    __weak typeof(XMPPMockStream) *weakStreamTest = self.stream;
    __weak typeof(self) weakSelf = self;
    
    XMPPJID *contact = [XMPPJID jidWithString:@"bob@com.com/res"];
    
    self.stream.elementReceived = ^void(NSXMLElement *element) {
        NSLog(@"received element: %@", element);
        XMPPIQ *iq = [XMPPIQ iqFromElement:element];
        NSString *eid = [iq elementID];
        XMPPIQ *response = [weakSelf fakeContactvCardWithElementId:eid toJID:weakStreamTest.myJID.bare fromJID:contact.bare];
        NSLog(@"sending response: %@", response);
        [weakStreamTest fakeIQResponse:response];
    };
    
    [self.vcardModule fetchvCardTempForJID:contact];
    
    [self waitForExpectationsWithTimeout:60 handler:^(NSError * _Nullable error) {
        if(error){
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

- (void) testVcardContactFailure {
    self.failureExpectation = [self expectationWithDescription:@"testVcardContactFailure"];
    
    __weak typeof(XMPPMockStream) *weakStreamTest = self.stream;
    __weak typeof(self) weakSelf = self;
    
    XMPPJID *contact = [XMPPJID jidWithString:@"bob@com.com/res"];
    
    self.stream.elementReceived = ^void(NSXMLElement *element) {
        NSLog(@"received element: %@", element);
        XMPPIQ *iq = [XMPPIQ iqFromElement:element];
        NSString *eid = [iq elementID];
        XMPPIQ *response = [weakSelf fakeContactFailurevCardWithElementId:eid toJID:weakStreamTest.myJID.bare];
        NSLog(@"sending response: %@", response);
        [weakStreamTest fakeIQResponse:response];
    };
    
    [self.vcardModule fetchvCardTempForJID:contact];
    
    [self waitForExpectationsWithTimeout:60 handler:^(NSError * _Nullable error) {
        if(error){
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

#pragma mark IQ Generators

- (XMPPIQ*) fakeItemSelfNotFoundWithElementId:(NSString*)elementId toJID:(NSString*)toJID {
    NSString * errorString =
    [NSString stringWithFormat:@"<iq xmlns=\"jabber:client\" id=\"%@\" type=\"error\" to=\"%@\"><error type=\"cancel\"><item-not-found xmlns=\"urn:ietf:params:xml:ns:xmpp-stanzas\"/></error></iq>", elementId, toJID];
    NSError *error = nil;
    NSXMLElement *element = [[NSXMLElement alloc] initWithXMLString:errorString error:&error];
    if (error) {
        XCTFail(@"Error: %@", error);
    }
    XMPPIQ *iq = [XMPPIQ iqFromElement:element];
    return iq;
}

- (XMPPIQ*) fakeEmptySelfvCardWithElementId:(NSString*)elementId toJID:(NSString*)toJID {
    NSString * errorString =
    [NSString stringWithFormat:@"<iq id='%@'\
     to='%@'\
     type='result'>\
     <vCard xmlns='vcard-temp'/>\
     </iq>", elementId, toJID];
    NSError *error = nil;
    NSXMLElement *element = [[NSXMLElement alloc] initWithXMLString:errorString error:&error];
    if (error) {
        XCTFail(@"Error: %@", error);
    }
    XMPPIQ *iq = [XMPPIQ iqFromElement:element];
    return iq;
}

- (XMPPIQ*) fakeSelfvCardWithElementId:(NSString*)elementId toJID:(NSString*)toJID {
    NSString * errorString =
    [NSString stringWithFormat:@"<iq id='%@'\
     to='%@'\
     type='result'>\
     <vCard xmlns='vcard-temp'>\
     <NICKNAME>stpeter</NICKNAME>\
     </vCard>\
     </iq>", elementId, toJID];
    NSError *error = nil;
    NSXMLElement *element = [[NSXMLElement alloc] initWithXMLString:errorString error:&error];
    if (error) {
        XCTFail(@"Error: %@", error);
    }
    XMPPIQ *iq = [XMPPIQ iqFromElement:element];
    return iq;
}

- (XMPPIQ*) fakeContactvCardWithElementId:(NSString*)elementId toJID:(NSString*)toJID fromJID:(NSString*)fromJID {
    NSString * errorString =
    [NSString stringWithFormat:@"<iq from='%@' \
     to='%@' \
     type='result'\
     id='%@'>\
     <vCard xmlns='vcard-temp'>\
     <FN>JeremieMiller</FN>\
     </vCard>\
     </iq>", fromJID, toJID, elementId];
    NSError *error = nil;
    NSXMLElement *element = [[NSXMLElement alloc] initWithXMLString:errorString error:&error];
    if (error) {
        XCTFail(@"Error: %@", error);
    }
    XMPPIQ *iq = [XMPPIQ iqFromElement:element];
    return iq;
}

- (XMPPIQ*) fakeContactFailurevCardWithElementId:(NSString*)elementId toJID:(NSString*)toJID {
    NSString * errorString =
    [NSString stringWithFormat:@"<iq id='%@'\
     to='%@'\
     type='error'>\
     <vCard xmlns='vcard-temp'/>\
     <error type='cancel'>\
     <service-unavailable xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>\
     </error>\
     </iq>", elementId, toJID];
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
    [self.failureExpectation fulfill];
    
    if (self.successExpectation) {
        XCTFail(@"Expecting success and got failure");
        [self.successExpectation fulfill];
    }
}

- (void)xmppvCardTempModule:(XMPPvCardTempModule *)vCardTempModule
        didReceivevCardTemp:(XMPPvCardTemp *)vCardTemp
                     forJID:(XMPPJID *)jid {
    NSLog(@"didReceivevCardTemp %@ %@", vCardTemp, jid);
    [self.successExpectation fulfill];
}

@end
