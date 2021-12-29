//
//  XMPPMUCLightTests.m
//  XMPPFrameworkTests
//
//  Created by Andres on 5/30/16.
//
//

#import <XCTest/XCTest.h>
#import "XMPPMockStream.h"
@import KissXML;

// This is a Mock class to make test run faster. We need a delay when we
// are working over a real XMPPServer, but in tests it makes no sense to
// wait that long. This mock is only used in "testRoomsCountRemoval"

@interface XMPPMUCLightMock: XMPPMUCLight
- (double) delayInSeconds;
@end

@implementation XMPPMUCLightMock

- (double) delayInSeconds {
	return 1;
}

@end

////////////////////////////////////////////////////////////////////////


@interface XMPPMUCLightTests: XCTestCase <XMPPMUCLightDelegate>

@property (nonatomic, strong) XCTestExpectation *delegateResponseExpectation;
@property (nonatomic, strong) XCTestExpectation *roomsCountExpectation;

@end

@implementation XMPPMUCLightTests

- (void)setUp {
	[super setUp];
}

- (void)tearDown {
	[super tearDown];
}

- (void)testRoomsCountRemoval {
	self.roomsCountExpectation = [self expectationWithDescription:@"Count"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPMUCLightMock *mucLight = [[XMPPMUCLightMock alloc] init];

	[mucLight addDelegate:self delegateQueue:dispatch_get_main_queue()];
	[mucLight activate:streamTest];

	XMPPRoomLight *roomLight = [[XMPPRoomLight alloc] initWithJID:[XMPPJID jidWithString:@"test@test.com"] roomname:@"test name"];
	[roomLight activate:streamTest];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[roomLight deactivate];
	});

	// after calling to deactivate xmppStream:willUnregisterModule: implementation
	// from XMPPMUCLightMock is going to take 1 second to actually remove the room
	// from the set of rooms, so waiting 3 seconds would be enought.
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		XCTAssertTrue([[mucLight.rooms allObjects] count] == 0);
		[self.roomsCountExpectation fulfill];
	});

	[self waitForExpectationsWithTimeout:6 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)testRoomsCountAddition {
	self.roomsCountExpectation = [self expectationWithDescription:@"Count"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPMUCLight *mucLight = [[XMPPMUCLight alloc] init];

	[mucLight addDelegate:self delegateQueue:dispatch_get_main_queue()];
	[mucLight activate:streamTest];

	XMPPRoomLight *roomLight = [[XMPPRoomLight alloc] initWithJID:[XMPPJID jidWithString:@"test@test.com"] roomname:@"test name"];
	[roomLight activate:streamTest];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		XCTAssertTrue([mucLight.rooms containsObject:roomLight.roomJID]);
		[self.roomsCountExpectation fulfill];
	});

	[self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)testRequestBlockingList{
	self.delegateResponseExpectation = [self expectationWithDescription:@"Block List"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPMUCLight *mucLight = [[XMPPMUCLight alloc] init];

	[mucLight addDelegate:self delegateQueue:dispatch_get_main_queue()];
	[mucLight activate:streamTest];

	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		NSXMLElement *query = [element elementForName:@"query"];
		XCTAssertNotNil([element elementForName:@"query"]);
		XCTAssertEqualObjects(query.xmlns, @"urn:xmpp:muclight:0#blocking");
		XCTAssertEqualObjects([element attributeForName:@"type"].stringValue, @"get");
		XCTAssertEqualObjects([element attributeForName:@"to"].stringValue, @"muclight.test.com");


		NSString *elementID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *iq = [self fakeSuccessBlockListIQWithID:elementID];
		[weakStreamTest fakeIQResponse:iq];
	};

	[mucLight requestBlockingList:@"muclight.test.com"];
	
	[self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void) xmppMUCLight:(XMPPMUCLight *)sender didRequestBlockingList:(NSArray<NSXMLElement *> *)items forServiceNamed:(NSString *)serviceName{
	XCTAssertEqual(items.count, 2);
	XCTAssertEqualObjects(serviceName, @"muclight.test.com");
	[self.delegateResponseExpectation fulfill];
}

- (void)testFailToRequestBlockingList{
	self.delegateResponseExpectation = [self expectationWithDescription:@"Block List"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPMUCLight *mucLight = [[XMPPMUCLight alloc] init];

	[mucLight addDelegate:self delegateQueue:dispatch_get_main_queue()];
	[mucLight activate:streamTest];

	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		XMPPIQ *iq = [self fakeErrorIQWithID:[element attributeForName:@"id"].stringValue];
		[weakStreamTest fakeIQResponse:iq];
	};

	[mucLight requestBlockingList:@"muclight.test.com"];

	[self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)xmppMUCLight:(XMPPMUCLight *)sender failedToRequestBlockingList:(NSString *)serviceName withError:(NSError *)error{
	XCTAssertEqualObjects(serviceName, @"muclight.test.com");
	[self.delegateResponseExpectation fulfill];
}

- (void)testDiscoverRoomsForServiceNamed {
	self.delegateResponseExpectation = [self expectationWithDescription:@"Slot Response"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPMUCLight *mucLight = [[XMPPMUCLight alloc] init];

	[mucLight addDelegate:self delegateQueue:dispatch_get_main_queue()];
	[mucLight activate:streamTest];

	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {

		//  <iq from='hag66@shakespeare.lit/pda'
		//      id='h7ns81g'
		//      to='shakespeare.lit'
		//      type='get'>
		//    <query xmlns='http://jabber.org/protocol/disco#items'/>
		//  </iq>

		XCTAssertNotNil([element elementForName:@"query" xmlns:@"http://jabber.org/protocol/disco#items"]);
		XCTAssertEqualObjects([element attributeForName:@"type"].stringValue, @"get");
		XCTAssertEqualObjects([element attributeForName:@"to"].stringValue, @"muclight.test.com");

		NSString *elementID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *iq = [self fakeSuccessIQWithID:elementID];
		[weakStreamTest fakeIQResponse:iq];
	};

	[mucLight discoverRoomsForServiceNamed:@"muclight.test.com"];

	[self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];

}

- (void)xmppMUCLight:(XMPPMUCLight *)sender didDiscoverRooms:(NSArray *)rooms forServiceNamed:(NSString *)serviceName {
	XCTAssertEqualObjects(serviceName, @"muclight.test.com");
	XCTAssertEqual(4, rooms.count);

	[self.delegateResponseExpectation fulfill];
}


- (void)testFailToDiscoverRoomsForServiceNamed {
	self.delegateResponseExpectation = [self expectationWithDescription:@"Slot Response"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPMUCLight *mucLight = [[XMPPMUCLight alloc] init];

	[mucLight addDelegate:self delegateQueue:dispatch_get_main_queue()];
	[mucLight activate:streamTest];

	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {

		NSString *elementID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *iq = [self fakeErrorIQWithID:elementID];
		[weakStreamTest fakeIQResponse:iq];
	};

	[mucLight discoverRoomsForServiceNamed:@"muclight.test.com"];

	[self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];

}

- (void)xmppMUCLight:(XMPPMUCLight *)sender failedToDiscoverRoomsForServiceNamed:(NSString *)serviceName withError:(NSError *)error {
	XCTAssertEqualObjects(serviceName, @"muclight.test.com");
	[self.delegateResponseExpectation fulfill];
}


- (void)testChangeAffiliation {
	self.delegateResponseExpectation = [self expectationWithDescription:@"Slot Response"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPMUCLight *mucLight = [[XMPPMUCLight alloc] init];

	[mucLight addDelegate:self delegateQueue:dispatch_get_main_queue()];
	[mucLight activate:streamTest];
	[streamTest fakeMessageResponse:[self fakeMessageChangeAffiliation]];

	[self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)xmppMUCLight:(XMPPMUCLight *)sender changedAffiliation:(NSString *)affiliation userJID:(XMPPJID *)userJID roomJID:(XMPPJID *)roomJID {
	XCTAssertEqualObjects(affiliation, @"member");
	XCTAssertEqualObjects(roomJID.full, @"coven@muclight.shakespeare.lit");
	[self.delegateResponseExpectation fulfill];
}

- (void)testPerformActionOnElements{
	self.delegateResponseExpectation = [self expectationWithDescription:@"Perform Action"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPMUCLight *mucLight = [[XMPPMUCLight alloc] init];

	[mucLight addDelegate:self delegateQueue:dispatch_get_main_queue()];
	[mucLight activate:streamTest];

	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		NSXMLElement *query = [element elementForName:@"query"];
		XCTAssertEqualObjects([element attributeForName:@"type"].stringValue, @"set");
		XCTAssertEqualObjects([element attributeForName:@"to"].stringValue, @"muclight.test.com");
		XCTAssertEqualObjects(query.xmlns, @"urn:xmpp:muclight:0#blocking");

		NSXMLNode *itemElement = [[query children] firstObject];
		XCTAssertEqualObjects(itemElement.stringValue, @"user@test.com");
		XCTAssertEqualObjects(itemElement.name, @"user");
		//XCTAssertEqualObjects([itemElement attributeStringValueForName:@"action"], @"deny");

		NSString *elementID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *iq = [self fakeSuccessIQWithID:elementID];
		[weakStreamTest fakeIQResponse:iq];
	};

	NSXMLElement *element = [NSXMLElement elementWithName:@"user" stringValue:@"user@test.com"];
	[element addAttributeWithName:@"action" stringValue:@"deny"];

	NSArray *elements = @[element];
	[mucLight performActionOnElements:elements forServiceNamed:@"muclight.test.com"];

	[self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void) xmppMUCLight:(XMPPMUCLight *)sender didPerformAction:(XMPPIQ *)serviceName{
	[self.delegateResponseExpectation fulfill];
}

- (XMPPMessage *)fakeMessageChangeAffiliation {
	NSMutableString *s = [NSMutableString string];
	[s appendString: @"<message from='coven@muclight.shakespeare.lit'"];
	[s appendString: @"         to='user2@shakespeare.lit'"];
	[s appendString: @"         type='groupchat'"];
	[s appendString: @"         id='createnotif'>"];
	[s appendString: @"    <x xmlns='urn:xmpp:muclight:0#affiliations'>"];
	[s appendString: @"        <version>aaaaaaa</version>"];
	[s appendString: @"        <user affiliation='member'>user2@shakespeare.lit</user>"];
	[s appendString: @"    </x>"];
	[s appendString: @"    <body />"];
	[s appendString: @"</message>"];

	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	XMPPMessage *message = [XMPPMessage messageFromElement:[doc rootElement]];
	return message;
}

- (XMPPIQ *)fakeErrorIQWithID:(NSString *) elementID{
	NSMutableString *s = [NSMutableString string];
	[s appendString: @"<iq to='crone1@shakespeare.lit/desktop'"];
	[s appendString: @"    id='member1'"];
	[s appendString: @"    from='muclight.test.com'"];
	[s appendString: @"    type='error'>"];
	[s appendString: @"    <error type='cancel'>"];
	[s appendString: @"        <not-allowed xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>"];
	[s appendString: @"    </error>"];
	[s appendString: @"</iq>"];

	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	XMPPIQ *iq = [XMPPIQ iqFromElement:[doc rootElement]];
	[iq addAttributeWithName:@"id" stringValue:elementID];

	return iq;
}

- (XMPPIQ *)fakeSuccessIQWithID:(NSString *) elementID{
	NSMutableString *s = [NSMutableString string];
	[s appendString: @"<iq from='muclight.test.com'"];
	[s appendString: @"    id='zb8q41f4'"];
	[s appendString: @"    to='hag66@shakespeare.lit/pda'"];
	[s appendString: @"    type='result'>"];
	[s appendString: @"    <query xmlns='http://jabber.org/protocol/disco#items'>"];
	[s appendString: @"        <item jid='heath@muclight.shakespeare.lit' name='A Lonely Heath' version='1'/>"];
	[s appendString: @"        <item jid='coven@muclight.shakespeare.lit' name='A Dark Cave' version='2'/>"];
	[s appendString: @"        <item jid='forres@muclight.shakespeare.lit' name='The Palace' version='3'/>"];
	[s appendString: @"        <item jid='inverness@muclight.shakespeare.lit'"];
	[s appendString: @"              name='Macbeth&apos;s Castle'"];
	[s appendString: @"              version='4'/>"];
	[s appendString: @"    </query>"];
	[s appendString: @"</iq>"];

	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	XMPPIQ *iq = [XMPPIQ iqFromElement:[doc rootElement]];
	[iq addAttributeWithName:@"id" stringValue:elementID];

	return iq;
}

- (XMPPIQ *)fakeSuccessBlockListIQWithID:(NSString *) elementID{
	NSMutableString *s = [NSMutableString string];
	[s appendString: @"<iq from='muclight.test.com'"];
	[s appendString: @"    id='zb8q41f4'"];
	[s appendString: @"    to='hag66@shakespeare.lit/pda'"];
	[s appendString: @"    type='result'>"];
	[s appendString: @"    <query xmlns='urn:xmpp:muclight:0#blocking'>"];
	[s appendString: @"        <room action='deny'>coven@muclight.shakespeare.lit</room>"];
	[s appendString: @"        <user action='deny'>hag77@shakespeare.lit</user>"];
	[s appendString: @"    </query>"];
	[s appendString: @"</iq>"];

	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	XMPPIQ *iq = [XMPPIQ iqFromElement:[doc rootElement]];
	[iq addAttributeWithName:@"id" stringValue:elementID];

	return iq;
}


@end
