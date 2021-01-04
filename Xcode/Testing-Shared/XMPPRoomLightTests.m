//
//  XMPPRoomLightTests.m
//  XMPPFrameworkTests
//
//  Created by Andres Canal on 5/31/16.
//
//

#import <XCTest/XCTest.h>
#import "XMPPMockStream.h"
@import KissXML;

@interface XMPPRoomLight()
- (nonnull NSString *)memberListVersion;
- (nonnull NSString *)configVersion;
@end

@interface XMPPRoomLightTests : XCTestCase <XMPPRoomLightDelegate>

@property (nonatomic, strong) XCTestExpectation *delegateResponseExpectation;
@property BOOL receivedDestroyMessage;
@property BOOL receivedConfigurationChangedMessage;
@end

@implementation XMPPRoomLightTests

- (void)testInitVersionsShouldBeEmpty {
	XMPPJID *jid = [XMPPJID jidWithUser:@"user" domain:@"domain.com" resource:@"resource"];
	XMPPRoomLight *roomLight = [[XMPPRoomLight alloc] initWithJID:jid roomname:@"room"];
	XCTAssertEqualObjects(roomLight.memberListVersion, @"");
	XCTAssertEqualObjects(roomLight.configVersion, @"");
}

- (void)testInitWithJIDAndRoomname {
	XMPPJID *jid = [XMPPJID jidWithUser:@"user" domain:@"domain.com" resource:@"resource"];
	XMPPRoomLight *roomLight = [[XMPPRoomLight alloc] initWithJID:jid roomname:@"room"];
	XCTAssertEqualObjects(roomLight.roomJID.full, @"user@domain.com/resource");
	XCTAssertEqualObjects(roomLight.roomname, @"room");
}

- (void)testCreateRoomLight{
	self.delegateResponseExpectation = [self expectationWithDescription:@"Create Room"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPJID *memberJID = [XMPPJID jidWithString:@"first-user@domain.com"];

	XMPPJID *jid = [XMPPJID jidWithString:@"domain.com"];
	XMPPRoomLight *roomLight = [[XMPPRoomLight alloc] initWithJID:jid roomname:@"test"];
	[roomLight addDelegate:self delegateQueue:dispatch_get_main_queue()];
	[roomLight activate:streamTest];

	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		NSXMLElement *query = [element elementForName:@"query"];
		XCTAssertEqualObjects(query.xmlns, @"urn:xmpp:muclight:0#create");

		NSString *elementID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *iq = [self fakeIQWithID:elementID andType:@"result"];
		[weakStreamTest fakeIQResponse:iq];
	};

	[roomLight createRoomLightWithMembersJID:@[memberJID]];

	[self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)xmppRoomLight:(XMPPRoomLight *)sender didCreateRoomLight:(XMPPIQ *)iq {
	XCTAssertEqualObjects(@"test", sender.roomname);
	XCTAssertNotNil(sender.roomJID);

	[self.delegateResponseExpectation fulfill];
}

- (void)testFailToCreateRoomLight{
	self.delegateResponseExpectation = [self expectationWithDescription:@"Create Room"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPJID *memberJID = [XMPPJID jidWithString:@"first-user@domain.com"];

	XMPPJID *jid = [XMPPJID jidWithString:@"domain.com"];
	XMPPRoomLight *roomLight = [[XMPPRoomLight alloc] initWithJID:jid roomname:@"test"];
	[roomLight addDelegate:self delegateQueue:dispatch_get_main_queue()];
	[roomLight activate:streamTest];

	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		NSXMLElement *query = [element elementForName:@"query"];
		XCTAssertEqualObjects(query.xmlns, @"urn:xmpp:muclight:0#create");

		NSString *elementID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *iq = [self fakeIQWithID:elementID andType:@"error"];
		[weakStreamTest fakeIQResponse:iq];
	};

	[roomLight createRoomLightWithMembersJID:@[memberJID]];

	[self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)xmppRoomLight:(XMPPRoomLight *)sender didFailToCreateRoomLight:(XMPPIQ *)iq {
	XCTAssertEqualObjects(@"test", sender.roomname);
	XCTAssertNotNil(sender.roomJID);

	[self.delegateResponseExpectation fulfill];
}

- (void)testLeaveRoomLight{
	self.delegateResponseExpectation = [self expectationWithDescription:@"Leave Room"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	[streamTest setMyJID:[XMPPJID jidWithString:@"test-user@domain.com"]];
	XMPPJID *roomJID = [XMPPJID jidWithString:@"room-id@domain.com"];

	XMPPRoomLight *roomLight = [[XMPPRoomLight alloc] initWithJID:roomJID roomname:@"roomName"];
	[roomLight addDelegate:self delegateQueue:dispatch_get_main_queue()];
	[roomLight activate:streamTest];

	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		NSXMLElement *query = [element elementForName:@"query"];
		NSXMLElement *user = [query elementsForName:@"user"].firstObject;

		XCTAssertEqualObjects(query.xmlns, @"urn:xmpp:muclight:0#affiliations");
		XCTAssertEqualObjects(user.stringValue, @"test-user@domain.com");
		XCTAssertEqualObjects([user attributeForName:@"affiliation"].stringValue, @"none");

		NSString *elementID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *iq = [self fakeIQWithID:elementID andType:@"result"];
		[weakStreamTest fakeIQResponse:iq];
	};

	[roomLight leaveRoomLight];

	[self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)xmppRoomLight:(XMPPRoomLight *)sender didLeaveRoomLight:(XMPPIQ *)iq {
	[self.delegateResponseExpectation fulfill];
}

- (void)testFailToLeaveRoomLight{
	self.delegateResponseExpectation = [self expectationWithDescription:@"Leave Room"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPJID *roomJID = [XMPPJID jidWithString:@"room-id@domain.com"];

	XMPPRoomLight *roomLight = [[XMPPRoomLight alloc] initWithJID:roomJID roomname:@"roomName"];
	[roomLight addDelegate:self delegateQueue:dispatch_get_main_queue()];
	[roomLight activate:streamTest];

	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		NSXMLElement *query = [element elementForName:@"query"];
		XCTAssertEqualObjects(query.xmlns, @"urn:xmpp:muclight:0#affiliations");

		NSString *elementID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *iq = [self fakeIQWithID:elementID andType:@"error"];
		[weakStreamTest fakeIQResponse:iq];
	};

	[roomLight leaveRoomLight];

	[self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)xmppRoomLight:(XMPPRoomLight *)sender didFailToLeaveRoomLight:(XMPPIQ *)iq {
	[self.delegateResponseExpectation fulfill];
}

- (void)testDidAddUser{
	self.delegateResponseExpectation = [self expectationWithDescription:@"Add Users"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPJID *roomJID = [XMPPJID jidWithString:@"room-id@domain.com"];

	XMPPRoomLight *roomLight = [[XMPPRoomLight alloc] initWithJID:roomJID roomname:@"roomName"];
	[roomLight addDelegate:self delegateQueue:dispatch_get_main_queue()];
	[roomLight activate:streamTest];

	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		NSXMLElement *query = [element elementForName:@"query"];
		XCTAssertEqualObjects(query.xmlns, @"urn:xmpp:muclight:0#affiliations");

		NSArray *users = [query elementsForName:@"user"];
		NSXMLElement *user1 = [users firstObject];
		XCTAssertEqualObjects([user1 attributeForName:@"affiliation"].stringValue, @"member");
		XCTAssertEqualObjects(user1.stringValue, @"user1@domain.com");

		NSXMLElement *user3 = [users lastObject];
		XCTAssertEqualObjects([user3 attributeForName:@"affiliation"].stringValue, @"member");
		XCTAssertEqualObjects(user3.stringValue, @"user3@domain.com");

		NSString *elementID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *iq = [self fakeIQWithID:elementID andType:@"result"];
		[weakStreamTest fakeIQResponse:iq];
	};

	[roomLight addUsers:@[[XMPPJID jidWithString:@"user1@domain.com"],
						  [XMPPJID jidWithString:@"user2@domain.com"],
						  [XMPPJID jidWithString:@"user3@domain.com"]]];

	[self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)xmppRoomLight:(XMPPRoomLight *)sender didAddUsers:(XMPPIQ*) iqResult {
	XCTAssertEqualObjects(sender.roomJID.bare, @"room-id@domain.com");
	[self.delegateResponseExpectation fulfill];
}


- (void)testDidFailToAddUser{
	self.delegateResponseExpectation = [self expectationWithDescription:@"Add Users"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPJID *roomJID = [XMPPJID jidWithString:@"room-id@domain.com"];

	XMPPRoomLight *roomLight = [[XMPPRoomLight alloc] initWithJID:roomJID roomname:@"roomName"];
	[roomLight addDelegate:self delegateQueue:dispatch_get_main_queue()];
	[roomLight activate:streamTest];

	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		NSXMLElement *query = [element elementForName:@"query"];
		XCTAssertEqualObjects(query.xmlns, @"urn:xmpp:muclight:0#affiliations");

		NSString *elementID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *iq = [self fakeIQWithID:elementID andType:@"error"];
		[weakStreamTest fakeIQResponse:iq];
	};

	[roomLight addUsers:@[[XMPPJID jidWithString:@"user1@domain.com"],
						  [XMPPJID jidWithString:@"user2@domain.com"],
						  [XMPPJID jidWithString:@"user3@domain.com"]]];

	[self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)xmppRoomLight:(XMPPRoomLight *)sender didFailToAddUsers:(XMPPIQ*)iq {
	XCTAssertEqualObjects(sender.roomJID.bare, @"room-id@domain.com");
	[self.delegateResponseExpectation fulfill];
}


- (void)testFetchMemberList{
	self.delegateResponseExpectation = [self expectationWithDescription:@"Fetch Member List"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPJID *roomJID = [XMPPJID jidWithString:@"room-id@domain.com"];

	XMPPRoomLight *roomLight = [[XMPPRoomLight alloc] initWithJID:roomJID roomname:@"roomName"];
	[roomLight addDelegate:self delegateQueue:dispatch_get_main_queue()];
	[roomLight activate:streamTest];

	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		NSXMLElement *query = [element elementForName:@"query"];
		XCTAssertEqualObjects(query.xmlns, @"urn:xmpp:muclight:0#affiliations");

		NSString *elementID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *iq = [self fakeIQUserListWithID:elementID];
		[weakStreamTest fakeIQResponse:iq];
	};

	[roomLight fetchMembersList];

	[self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)xmppRoomLight:(XMPPRoomLight *)sender didFetchMembersList:(XMPPIQ *)iqResult {
	NSXMLElement *user1 = [[sender knownMembersList] firstObject];
	NSXMLElement *user3 = [[sender knownMembersList] lastObject];
	XCTAssertEqualObjects([user1 attributeForName:@"affiliation"].stringValue, @"owner");
	XCTAssertEqualObjects(user1.stringValue, @"user1@shakespeare.lit");
	XCTAssertEqualObjects([user3 attributeForName:@"affiliation"].stringValue, @"member");
	XCTAssertEqualObjects(user3.stringValue, @"user3@shakespeare.lit");

	XCTAssertEqualObjects(sender.memberListVersion, @"123456");
	[self.delegateResponseExpectation fulfill];
}

- (void)testFailToFetchMemberList{
	self.delegateResponseExpectation = [self expectationWithDescription:@"Fetch Member List"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPJID *roomJID = [XMPPJID jidWithString:@"room-id@domain.com"];

	XMPPRoomLight *roomLight = [[XMPPRoomLight alloc] initWithJID:roomJID roomname:@"roomName"];
	[roomLight addDelegate:self delegateQueue:dispatch_get_main_queue()];
	[roomLight activate:streamTest];

	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		NSXMLElement *query = [element elementForName:@"query"];
		XCTAssertEqualObjects(query.xmlns, @"urn:xmpp:muclight:0#affiliations");

		NSString *elementID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *iq = [self fakeIQUserListWithID:elementID];
		[weakStreamTest fakeIQResponse:iq];
	};

	[roomLight fetchMembersList];

	[self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)xmppRoomLight:(XMPPRoomLight *)sender didFailToFetchMembersList:(XMPPIQ *)iq{
	[self.delegateResponseExpectation fulfill];
}

- (void)testSendMessage{
	self.delegateResponseExpectation = [self expectationWithDescription:@"send message"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPJID *roomJID = [XMPPJID jidWithString:@"room-id@domain.com"];

	XMPPRoomLight *roomLight = [[XMPPRoomLight alloc] initWithJID:roomJID roomname:@"roomName"];
	[roomLight activate:streamTest];

	streamTest.elementReceived = ^void(NSXMLElement *element) {
		XMPPMessage *message = [XMPPMessage messageFromElement:element];
		XCTAssertEqualObjects(message.type, @"groupchat");
		XCTAssertEqualObjects(message.to.bare, @"room-id@domain.com");
		XCTAssertEqualObjects(message.body, @"Hi there");

		[self.delegateResponseExpectation fulfill];
	};

	[roomLight sendMessageWithBody:@"Hi there"];

	[self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)testSendMessageWithBody{
	self.delegateResponseExpectation = [self expectationWithDescription:@"send message with body"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPJID *roomJID = [XMPPJID jidWithString:@"room-id@domain.com"];

	XMPPRoomLight *roomLight = [[XMPPRoomLight alloc] initWithJID:roomJID roomname:@"roomName"];
	[roomLight activate:streamTest];

	XMPPMessage *message = [XMPPMessage messageWithType:@"groupchat" to:roomJID];
	[message addBody:@"Hi there"];

	streamTest.elementReceived = ^void(NSXMLElement *element) {
		XMPPMessage *message = [XMPPMessage messageFromElement:element];
		XCTAssertEqualObjects(message.type, @"groupchat");
		XCTAssertEqualObjects(message.to.bare, @"room-id@domain.com");
		XCTAssertEqualObjects(message.body, @"Hi there");

		[self.delegateResponseExpectation fulfill];
	};

	[roomLight sendMessage:message];

	[self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)testChangeSubject{
	self.receivedConfigurationChangedMessage = false;
	self.delegateResponseExpectation = [self expectationWithDescription:@"change subject"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	streamTest.myJID = [XMPPJID jidWithString:@"andres@domain.com"];
	XMPPJID *roomJID = [XMPPJID jidWithString:@"room-id@domain.com"];

	XMPPRoomLight *roomLight = [[XMPPRoomLight alloc] initWithJID:roomJID roomname:@"roomName"];
	[roomLight activate:streamTest];
	[roomLight addDelegate:self delegateQueue:dispatch_get_main_queue()];

	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		NSXMLElement *query = [element elementForName:@"query"];
		NSXMLElement *subject = [query elementForName:@"subject"];

		XCTAssertEqualObjects(query.xmlns, @"urn:xmpp:muclight:0#configuration");
		XCTAssertEqualObjects(subject.stringValue, @"new subject");

		[weakStreamTest fakeMessageResponse: [self fakeMessageChangeSubject]];

		NSString *iqID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *iq = [self fakeIQWithID:iqID  andType:@"result"];
		[weakStreamTest fakeIQResponse:iq];
	};

	[roomLight changeRoomSubject:@"new subject"];

	[self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)xmppRoomLight:(XMPPRoomLight *)sender configurationChanged:(XMPPMessage *)message{
	self.receivedConfigurationChangedMessage = YES;
}

- (void)testDestroyRoom{
	self.receivedDestroyMessage = NO;
	self.delegateResponseExpectation = [self expectationWithDescription:@"delete room"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPJID *roomJID = [XMPPJID jidWithString:@"room-id@domain.com"];

	XMPPRoomLight *roomLight = [[XMPPRoomLight alloc] initWithJID:roomJID roomname:@"roomName"];
	[roomLight activate:streamTest];
	[roomLight addDelegate:self delegateQueue:dispatch_get_main_queue()];

	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		NSXMLElement *query = [element elementForName:@"query"];
		XCTAssertEqualObjects(query.xmlns, @"urn:xmpp:muclight:0#destroy");

		[weakStreamTest fakeMessageResponse: [self fakeMessageDestroy]];

		NSString *iqID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *iq = [self fakeIQWithID:iqID  andType:@"result"];
		[weakStreamTest fakeIQResponse:iq];
	};

	[roomLight destroyRoom];

	[self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)xmppRoomLight:(XMPPRoomLight *)sender roomDestroyed:(XMPPMessage *)message {
	self.receivedDestroyMessage = YES;
}

- (void)xmppRoomLight:(nonnull XMPPRoomLight *)sender didDestroyRoomLight:(nonnull XMPPIQ*) iqResult {
	XCTAssertTrue(self.receivedDestroyMessage);
	[self.delegateResponseExpectation fulfill];
}

- (void)testFailToDestroyRoom{
	self.delegateResponseExpectation = [self expectationWithDescription:@"delete room"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	streamTest.myJID = [XMPPJID jidWithString:@"andres@domain.com"];
	XMPPJID *roomJID = [XMPPJID jidWithString:@"room-id@domain.com"];

	XMPPRoomLight *roomLight = [[XMPPRoomLight alloc] initWithJID:roomJID roomname:@"roomName"];
	[roomLight activate:streamTest];
	[roomLight addDelegate:self delegateQueue:dispatch_get_main_queue()];

	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		NSString *iqID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *iq = [self fakeIQWithID:iqID  andType:@"error"];
		[weakStreamTest fakeIQResponse:iq];
	};

	[roomLight destroyRoom];

	[self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)xmppRoomLight:(XMPPRoomLight *)sender didFailToDestroyRoomLight:(XMPPIQ *)iq{
	[self.delegateResponseExpectation fulfill];
}

- (void)testChangeAffiliations{
	self.receivedDestroyMessage = NO;
	self.delegateResponseExpectation = [self expectationWithDescription:@"change affiliation"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPJID *roomJID = [XMPPJID jidWithString:@"room-id@domain.com"];

	XMPPRoomLight *roomLight = [[XMPPRoomLight alloc] initWithJID:roomJID roomname:@"roomName"];
	[roomLight activate:streamTest];
	[roomLight addDelegate:self delegateQueue:dispatch_get_main_queue()];

	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		NSXMLElement *query = [element elementForName:@"query"];
		XCTAssertEqualObjects(query.xmlns, @"urn:xmpp:muclight:0#affiliations");

		NSArray *users = [query elementsForName:@"user"];
		XCTAssertEqualObjects([((NSXMLElement *)[users objectAtIndex:0]) attributeForName:@"affiliation"].stringValue,@"owner");
		XCTAssertEqualObjects([((NSXMLElement *)[users objectAtIndex:1]) attributeForName:@"affiliation"].stringValue,@"member");
		XCTAssertEqualObjects([((NSXMLElement *)[users objectAtIndex:2]) attributeForName:@"affiliation"].stringValue,@"none");

		XCTAssertEqualObjects(((NSXMLElement *)[users objectAtIndex:0]).stringValue,@"user1@domain.com");
		XCTAssertEqualObjects(((NSXMLElement *)[users objectAtIndex:1]).stringValue,@"user2@domain.com");
		XCTAssertEqualObjects(((NSXMLElement *)[users objectAtIndex:2]).stringValue,@"user3@domain.com");

		NSString *iqID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *iq = [self fakeIQWithID:iqID  andType:@"result"];
		[weakStreamTest fakeIQResponse:iq];
	};

	NSXMLElement *user1 = [NSXMLElement elementWithName:@"user" stringValue:@"user1@domain.com"];
	NSXMLElement *user2 = [NSXMLElement elementWithName:@"user" stringValue:@"user2@domain.com"];
	NSXMLElement *user3 = [NSXMLElement elementWithName:@"user" stringValue:@"user3@domain.com"];

	[user1 addAttributeWithName:@"affiliation" stringValue:@"owner"];
	[user2 addAttributeWithName:@"affiliation" stringValue:@"member"];
	[user3 addAttributeWithName:@"affiliation" stringValue:@"none"];

	[roomLight changeAffiliations:@[user1,user2,user3]];

	[self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)xmppRoomLight:(nonnull XMPPRoomLight *)sender didChangeAffiliations:(nonnull XMPPIQ*) iqResult{
	[self.delegateResponseExpectation fulfill];
}

- (void)testFailToChangeAffiliations{
	self.receivedDestroyMessage = NO;
	self.delegateResponseExpectation = [self expectationWithDescription:@"change affiliation"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPJID *roomJID = [XMPPJID jidWithString:@"room-id@domain.com"];

	XMPPRoomLight *roomLight = [[XMPPRoomLight alloc] initWithJID:roomJID roomname:@"roomName"];
	[roomLight activate:streamTest];
	[roomLight addDelegate:self delegateQueue:dispatch_get_main_queue()];

	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		NSXMLElement *query = [element elementForName:@"query"];
		XCTAssertEqualObjects(query.xmlns, @"urn:xmpp:muclight:0#affiliations");

		NSString *iqID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *iq = [self fakeIQWithID:iqID  andType:@"error"];
		[weakStreamTest fakeIQResponse:iq];
	};

	NSXMLElement *user1 = [NSXMLElement elementWithName:@"user" stringValue:@"user1@domain.com"];
	[user1 addAttributeWithName:@"affiliation" stringValue:@"owner"];

	[roomLight changeAffiliations:@[user1]];
	[self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)xmppRoomLight:(nonnull XMPPRoomLight *)sender didFailToChangeAffiliations:(nonnull XMPPIQ*) iqResult{
	[self.delegateResponseExpectation fulfill];
}

- (void)testGetConfiguration{
	self.delegateResponseExpectation = [self expectationWithDescription:@"get configuration"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPJID *roomJID = [XMPPJID jidWithString:@"room-id@domain.com"];

	XMPPRoomLight *roomLight = [[XMPPRoomLight alloc] initWithJID:roomJID roomname:@"roomName"];
	[roomLight activate:streamTest];
	[roomLight addDelegate:self delegateQueue:dispatch_get_main_queue()];

	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		XCTAssertEqualObjects([element attributeForName:@"type"].stringValue,@"get");
		NSXMLElement *query = [element elementForName:@"query"];
		XCTAssertEqualObjects(query.xmlns, @"urn:xmpp:muclight:0#configuration");

		NSString *iqID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *iq = [self fakeIQConfigurationMessageWithID:iqID];
		[weakStreamTest fakeIQResponse:iq];
	};

	[roomLight getConfiguration];

	[self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
		XCTAssertEqualObjects(roomLight.roomname, @"Roomname");
		XCTAssertEqualObjects(roomLight.subject, @"Subject");
	}];
}

- (void)xmppRoomLight:(XMPPRoomLight *)sender didGetConfiguration:(XMPPIQ *)iqResult{
	XCTAssertEqualObjects(sender.configVersion, @"123456");
	[self.delegateResponseExpectation fulfill];
}

- (void)testFailToGetConfiguration{
	self.delegateResponseExpectation = [self expectationWithDescription:@"get configuration"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPJID *roomJID = [XMPPJID jidWithString:@"room-id@domain.com"];

	XMPPRoomLight *roomLight = [[XMPPRoomLight alloc] initWithJID:roomJID roomname:@"roomName"];
	[roomLight activate:streamTest];
	[roomLight addDelegate:self delegateQueue:dispatch_get_main_queue()];

	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		NSString *iqID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *iq = [self fakeIQWithID:iqID  andType:@"error"];
		[weakStreamTest fakeIQResponse:iq];
	};

	[roomLight getConfiguration];

	[self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)xmppRoomLight:(XMPPRoomLight *)sender didFailToGetConfiguration:(nonnull XMPPIQ *)iq{
	[self.delegateResponseExpectation fulfill];
}

- (void)testSetConfiguration{
	self.receivedConfigurationChangedMessage = NO;
	self.delegateResponseExpectation = [self expectationWithDescription:@"get configuration"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	streamTest.myJID = [XMPPJID jidWithString:@"andres@domain.com"];
	XMPPJID *roomJID = [XMPPJID jidWithString:@"room-id@domain.com"];

	XMPPRoomLight *roomLight = [[XMPPRoomLight alloc] initWithJID:roomJID roomname:@"roomName"];
	[roomLight activate:streamTest];
	[roomLight addDelegate:self delegateQueue:dispatch_get_main_queue()];

	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		NSXMLElement *query = [element elementForName:@"query"];
		XCTAssertEqualObjects([element attributeForName:@"type"].stringValue,@"set");
		XCTAssertEqualObjects(query.xmlns, @"urn:xmpp:muclight:0#configuration");

		NSXMLNode *config = [query children].firstObject;
		XCTAssertEqualObjects(config.stringValue,@"A Darker Cave");
		XCTAssertEqualObjects(config.name,@"roomname");

		[weakStreamTest fakeMessageResponse:[self fakeMessageConfigurationChange]];

		NSString *iqID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *iq = [self fakeIQWithID:iqID  andType:@"result"];
		[weakStreamTest fakeIQResponse:iq];
	};

	NSXMLElement *config = [NSXMLElement elementWithName:@"roomname" stringValue:@"A Darker Cave"];
	[roomLight setConfiguration:@[config]];

	[self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
		XCTAssertEqualObjects(roomLight.roomname, @"A Darker Cave");
	}];
}

- (void)xmppRoomLight:(XMPPRoomLight *)sender didSetConfiguration:(XMPPIQ *)iqResult{
	XCTAssertTrue(self.receivedConfigurationChangedMessage);
	[self.delegateResponseExpectation fulfill];
}

- (void)testFailToSetConfiguration{
	self.delegateResponseExpectation = [self expectationWithDescription:@"get configuration"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	streamTest.myJID = [XMPPJID jidWithString:@"andres@domain.com"];
	XMPPJID *roomJID = [XMPPJID jidWithString:@"room-id@domain.com"];

	XMPPRoomLight *roomLight = [[XMPPRoomLight alloc] initWithJID:roomJID roomname:@"roomName"];
	[roomLight activate:streamTest];
	[roomLight addDelegate:self delegateQueue:dispatch_get_main_queue()];

	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		NSString *iqID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *iq = [self fakeIQWithID:iqID  andType:@"error"];
		[weakStreamTest fakeIQResponse:iq];
	};

	NSXMLElement *config = [NSXMLElement elementWithName:@"roomname" stringValue:@"tester"];
	[roomLight setConfiguration:@[config]];

	[self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)xmppRoomLight:(XMPPRoomLight *)sender didFailToSetConfiguration:(nonnull XMPPIQ *)iq{
	[self.delegateResponseExpectation fulfill];
}

- (XMPPIQ *)fakeIQUserListWithID:(NSString *) elementID{
	NSMutableString *s = [NSMutableString string];
	[s appendString: @"<iq from='coven@muclight.shakespeare.lit'"];
	[s appendString: @"    id='getmembers'"];
	[s appendString: @"    to='crone1@shakespeare.lit/desktop'"];
	[s appendString: @"    type='result'>"];
	[s appendString: @"    <query xmlns='urn:xmpp:muclight:0#affiliations'>"];
	[s appendString: @"        <version>123456</version>"];
	[s appendString: @"        <user affiliation='owner'>user1@shakespeare.lit</user>"];
	[s appendString: @"        <user affiliation='member'>user2@shakespeare.lit</user>"];
	[s appendString: @"        <user affiliation='member'>user3@shakespeare.lit</user>"];
	[s appendString: @"    </query>"];
	[s appendString: @"</iq>"];

	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	XMPPIQ *iq = [XMPPIQ iqFromElement:[doc rootElement]];
	[iq addAttributeWithName:@"id" stringValue:elementID];

	return iq;
}

- (XMPPIQ *)fakeIQWithID:(NSString *) elementID andType:(NSString *)type{
	NSMutableString *s = [NSMutableString string];
	[s appendString: @"<iq to='crone1@shakespeare.lit/desktop'"];
	[s appendString: @"    id='create1'"];
	[s appendString: @"    from='coven@muclight.shakespeare.lit'"];
	[s appendString: @"    type='result' />"];

	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	XMPPIQ *iq = [XMPPIQ iqFromElement:[doc rootElement]];
	[iq addAttributeWithName:@"id" stringValue:elementID];
	[iq addAttributeWithName:@"type" stringValue:type];

	return iq;
}

- (XMPPIQ *)fakeIQConfigurationMessageWithID:(NSString *) elementID {
	NSMutableString *s = [NSMutableString string];
	[s appendString:@"<iq xmlns='jabber:client' from='testtesttest@muclight.erlang-solutions.com' to='ramabit@erlang-solutions.com/Andress-MacBook-Air' id='config0' type='result'>"];
	[s appendString:@"	<query xmlns='urn:xmpp:muclight:0#configuration'>"];
	[s appendString:@"		<version>123456</version>"];
	[s appendString:@"		<roomname>Roomname</roomname>"];
	[s appendString:@"		<subject>Subject</subject>"];
	[s appendString:@"	</query>"];
	[s appendString:@"</iq>"];

	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	XMPPIQ *iq = [XMPPIQ iqFromElement:[doc rootElement]];
	[iq addAttributeWithName:@"id" stringValue:elementID];

	return iq;
}

- (XMPPMessage *)fakeMessageDestroy{
	NSMutableString *s = [NSMutableString string];
	[s appendString: @"<message from='room-id@domain.com' to='andres@domain.com' type='groupchat' id='destroynotif'>"];
	[s appendString: @"	<x xmlns='urn:xmpp:muclight:0#affiliations'>"];
	[s appendString: @"		<user affiliation='none'>andres@domain.com</user>"];
	[s appendString: @"	</x>"];
	[s appendString: @"	<x xmlns='urn:xmpp:muclight:0#destroy' />"];
	[s appendString: @"	<body /> "];
	[s appendString: @"</message>"];

	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	XMPPMessage *message = [XMPPMessage messageFromElement:[doc rootElement]];
	return message;
}

- (XMPPMessage *)fakeMessageChangeSubject{
	NSMutableString *s = [NSMutableString string];
	[s appendString:@"<message from='room-id@domain.com' to='andres@domain.com' type='groupchat'>"];
	[s appendString:@"	<x xmlns='urn:xmpp:muclight:0#configuration'>"];
	[s appendString:@"		<prev-version>asdfghj000</prev-version> "];
	[s appendString:@"		<version>asdfghj</version>"];
	[s appendString:@"		<subject>To be or not to be?</subject>"];
	[s appendString:@"	</x>"];
	[s appendString:@"	<body />"];
	[s appendString:@"</message>"];

	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	XMPPMessage *message = [XMPPMessage messageFromElement:[doc rootElement]];
	return message;
}

- (XMPPMessage *)fakeMessageConfigurationChange{
	NSMutableString *s = [NSMutableString string];
	[s appendString:@"<message from='room-id@domain.com' to='andres@domain.com' type='groupchat'>"];
	[s appendString:@"	<x xmlns='urn:xmpp:muclight:0#configuration'>"];
	[s appendString:@"		<prev-version>zaqwsx</prev-version>"];
	[s appendString:@"		<version>zxcvbnm</version>"];
	[s appendString:@"		<roomname>A Darker Cave</roomname>"];
	[s appendString:@"	</x>"];
	[s appendString:@"	<body />"];
	[s appendString:@"</message>"];

	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	XMPPMessage *message = [XMPPMessage messageFromElement:[doc rootElement]];
	return message;
}

@end
