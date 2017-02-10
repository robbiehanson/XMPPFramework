//
//  XMPPTBReconnectionTests.m
//  XMPPFrameworkTests
//
//  Created by Andres Canal on 7/5/16.
//
//

#import <XCTest/XCTest.h>
#import "XMPPMockStream.h"
#import "XMPPTBReconnection.h"
#import "XMPPJID.h"

@interface XMPPTBReconnectionTests : XCTestCase <XMPPTBReconnectionDelegate>
@property (nonatomic, strong) XCTestExpectation *delegateResponseExpectation;
@end

@implementation XMPPTBReconnectionTests

- (void)testGetAuthToken {
	self.delegateResponseExpectation = [self expectationWithDescription:@"receive message"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPTBReconnection *xmppTBRReconnection = [[XMPPTBReconnection alloc] init];
	[xmppTBRReconnection activate:streamTest];
	[xmppTBRReconnection addDelegate:self delegateQueue:dispatch_get_main_queue()];

	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		NSXMLElement *query = [element elementForName:@"query"];
		XCTAssertEqualObjects(query.xmlns, @"erlang-solutions.com:xmpp:token-auth:0");
		XCTAssertEqualObjects([element attributeForName:@"type"].stringValue, @"get");

		NSString *elementID = [element attributeForName:@"id"].stringValue;
		[weakStreamTest fakeIQResponse:[self fakeIQWithID:elementID]];
	};
	[xmppTBRReconnection getAuthToken];

	[self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)xmppTBReconnection:(XMPPTBReconnection *)sender didReceiveToken:(NSDictionary<NSString *,NSString *> *)token {
	XCTAssertEqualObjects(token[@"access_token"], @"ACCESS_TOKEN");
	XCTAssertEqualObjects(token[@"refresh_token"], @"REFRESH_TOKEN");
	[self.delegateResponseExpectation fulfill];
}

- (void)testGetAuthTokenWithError {
	self.delegateResponseExpectation = [self expectationWithDescription:@"receive message"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPTBReconnection *xmppTBRReconnection = [[XMPPTBReconnection alloc] init];
	[xmppTBRReconnection activate:streamTest];
	[xmppTBRReconnection addDelegate:self delegateQueue:dispatch_get_main_queue()];

	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		NSString *elementID = [element attributeForName:@"id"].stringValue;
		[weakStreamTest fakeIQResponse:[self fakeIQWithError:elementID]];
	};
	[xmppTBRReconnection getAuthToken];

	[self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)xmppTBReconnection:(XMPPTBReconnection *)sender didFailToReceiveToken:(XMPPIQ *)iq {
	[self.delegateResponseExpectation fulfill];
}

- (XMPPIQ *)fakeIQWithError:(NSString *) elementID {
	NSMutableString *s = [NSMutableString string];
	[s appendString: @"<iq from='alice@wonderland.com' type='error' to='alice@wonderland.com/resource'>"];
	[s appendString: @"</iq>"];

	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	XMPPIQ *iq = [XMPPIQ iqFromElement:[doc rootElement]];
	[iq addAttributeWithName:@"id" stringValue:elementID];

	return iq;
}


- (XMPPIQ *)fakeIQWithID:(NSString *) elementID {
	NSMutableString *s = [NSMutableString string];
	[s appendString: @"<iq from='alice@wonderland.com' type='result' to='alice@wonderland.com/resource'>"];
	[s appendString: @"  <items xmlns='erlang-solutions.com:xmpp:token-auth:0'>"];
	[s appendString: @"    <access_token>ACCESS_TOKEN</access_token>"];
	[s appendString: @"    <refresh_token>REFRESH_TOKEN</refresh_token>"];
	[s appendString: @"  </items>"];
	[s appendString: @"</iq>"];

	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	XMPPIQ *iq = [XMPPIQ iqFromElement:[doc rootElement]];
	[iq addAttributeWithName:@"id" stringValue:elementID];

	return iq;
}

@end
