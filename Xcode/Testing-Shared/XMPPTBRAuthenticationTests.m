//
//  XMPPTBRAuthenticationTests.m
//  XMPPFrameworkTests
//
//  Created by Andres Canal on 7/6/16.
//
//

#import <XCTest/XCTest.h>
#import "XMPPMockStream.h"
#import "XMPPTBReconnection.h"
#import "XMPPTBRAuthentication.h"
#import "XMPPJID.h"
#import "XMPPStream+XMPPTBRAuthentication.h"

@interface XMPPTBRAuthenticationTests : XCTestCase <XMPPStreamDelegate>
@property (nonatomic, strong) XCTestExpectation *delegateExpectation;
@end

@implementation XMPPTBRAuthenticationTests

- (void)testTBRNotSupported {
	NSError *error;

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	streamTest.supportsTBR = NO;
	[streamTest authenticateWithTBR:@"token-token-token" error:&error];

	XCTAssertEqualObjects(error.domain, XMPPStreamErrorDomain);
	XCTAssertEqual(error.code, XMPPStreamUnsupportedAction);
	XCTAssertEqualObjects(error.userInfo[NSLocalizedDescriptionKey], @"The server does not support Token-based reconnection.");
}

- (void)testSuccessTBR {
	self.delegateExpectation = [self expectationWithDescription:@"TBR expectation"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	streamTest.supportsTBR = YES;
	streamTest.myJID = [XMPPJID jidWithString:@"andres@test.com"];

	streamTest.elementReceived = ^void(NSXMLElement *element) {
		XCTAssertEqualObjects(element.name, @"auth");
		XCTAssertEqualObjects([element attributeForName:@"mechanism"].stringValue, @"X-OAUTH");
		XCTAssertEqualObjects(element.stringValue, @"token-token-token");

		[self.delegateExpectation fulfill];
	};

	[streamTest authenticateWithTBR:@"token-token-token" error:nil];

	[self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)testFailureHandleAuth {
	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPTBRAuthentication *auth = [[XMPPTBRAuthentication alloc] initWithStream:streamTest token:@"test"];

	NSXMLElement *failureElement = [NSXMLElement elementWithName:@"failure" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
	NSXMLElement *notAuthorized = [NSXMLElement elementWithName:@"not-authorized"];
	[failureElement addChild:notAuthorized];

	XCTAssertEqual([auth handleAuth:failureElement], XMPP_AUTH_FAIL);
}

- (void)testSuccessHandleAuth {
	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPTBRAuthentication *auth = [[XMPPTBRAuthentication alloc] initWithStream:streamTest token:@"test"];

	NSXMLElement *successElement = [NSXMLElement elementWithName:@"success" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
	XCTAssertEqual([auth handleAuth:successElement], XMPP_AUTH_SUCCESS);
}

@end
