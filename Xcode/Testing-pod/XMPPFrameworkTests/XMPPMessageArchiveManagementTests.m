//
//  XMPPMessageArchiveManagementTests.m
//  XMPPFrameworkTests
//
//  Created by Andres on 5/24/16.
//
//

#import <XCTest/XCTest.h>
#import "XMPPFramework/XMPPMessageArchiveManagement.h"

@interface XMPPStreamTest : XMPPStream

- (void)fakeIQResponse:(XMPPIQ *) iq;
- (void)fakeMessageResponse:(XMPPMessage *) message;

@property (nonatomic, copy) void (^elementReceived)(NSXMLElement *element);
@property (nonatomic, strong) XMPPMessageArchiveManagement *delegate;

@end

@implementation XMPPStreamTest

- (void)fakeMessageResponse:(XMPPMessage *) message {
	[((id<XMPPStreamDelegate>)self.delegate) xmppStream:self didReceiveMessage:message];
}

- (void)fakeIQResponse:(XMPPIQ *) iq {
	[((id<XMPPStreamDelegate>)self.delegate) xmppStream:self didReceiveIQ:iq];
}

- (void)addDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue{
	[super addDelegate:delegate delegateQueue:delegateQueue];
	self.delegate = delegate;
}

- (void)sendElement:(NSXMLElement *)element {
	if(self.elementReceived) {
		self.elementReceived(element);
	}
}

@end

@interface XMPPMessageArchiveManagementTests : XCTestCase <XMPPMessageArchiveManagementDelegate>

@property (nonatomic, strong) XCTestExpectation *delegateExpectation;

@end

@implementation XMPPMessageArchiveManagementTests 

- (void)setUp {
	[super setUp];
}

- (void)tearDown {
	[super tearDown];
}

- (void)testFieldWithVar {
	NSXMLElement *field = [XMPPMessageArchiveManagement fieldWithVar:@"var" type:@"type" andValue:@"value"];
	
	XCTAssertEqualObjects(@"field", [field name]);
	XCTAssertEqualObjects(@"var", [field attributeStringValueForName:@"var"]);
	XCTAssertEqualObjects(@"type", [field attributeStringValueForName:@"type"]);
	
	NSXMLElement *value = [field elementForName:@"value"];
	XCTAssertEqualObjects(@"value", [value name]);
	XCTAssertEqualObjects(@"value", [value stringValue]);
}

- (void)testRetriveMessageArchiveWithFields {
	XCTestExpectation *expectation = [self expectationWithDescription:@"Handler IQ"];
	
	XMPPStreamTest *streamTest = [[XMPPStreamTest alloc] init];
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		XMPPIQ *iq = [XMPPIQ iqFromElement:element];
		XCTAssertEqualObjects(@"set", [iq type]);
		
		NSXMLElement *query = [iq elementForName:@"query"];
		XCTAssertNotNil(query);
		
		NSXMLElement *x = [query elementForName:@"x"];
		NSArray *fields = [x elementsForName:@"field"];
		
		NSXMLElement *firstField = [fields firstObject];
		XCTAssertEqualObjects(@"field", [firstField name]);
		XCTAssertEqualObjects(@"FORM_TYPE", [firstField attributeStringValueForName:@"var"]);
		XCTAssertEqualObjects(@"hidden", [firstField attributeStringValueForName:@"type"]);
		
		NSXMLElement *value = [firstField elementForName:@"value"];
		XCTAssertEqualObjects(@"value", [value name]);
		XCTAssertEqualObjects(@"urn:xmpp:mam:1", [value stringValue]);
		
		NSXMLElement *lastField = [fields lastObject];
		XCTAssertEqualObjects(@"field", [lastField name]);
		XCTAssertEqualObjects(@"with", [lastField attributeStringValueForName:@"var"]);
		XCTAssertNil([lastField attributeStringValueForName:@"type"]);
		
		value = [lastField elementForName:@"value"];
		XCTAssertEqualObjects(@"value", [value name]);
		XCTAssertEqualObjects(@"this-is-a-jid", [value stringValue]);
		
		XMPPResultSet *resultSet = [XMPPResultSet resultSetFromElement:[query elementForName:@"set"]];
		XCTAssertEqual(10, resultSet.max);
		XCTAssertEqualObjects(@"after-this", resultSet.after);

		[expectation fulfill];
	};

	NSXMLElement *field = [XMPPMessageArchiveManagement fieldWithVar:@"with" type:nil andValue:@"this-is-a-jid"];
	XMPPResultSet *resultSet = [XMPPResultSet resultSetWithMax:10 after:@"after-this"];
	
	XMPPMessageArchiveManagement *messageArchiveManagement = [[XMPPMessageArchiveManagement alloc] init];
	[messageArchiveManagement activate:streamTest];
	[messageArchiveManagement retrieveMessageArchiveWithFields:@[field] withResultSet:resultSet];
	
	[self waitForExpectationsWithTimeout:1 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)testDelegateDidReceiveMAMMessage {
	self.delegateExpectation = [self expectationWithDescription:@"Delegate"];
	
	XMPPStreamTest *streamTest = [[XMPPStreamTest alloc] init];
	
	XMPPMessageArchiveManagement *messageArchiveManagement = [[XMPPMessageArchiveManagement alloc] init];
	[messageArchiveManagement activate:streamTest];
	[messageArchiveManagement addDelegate:self delegateQueue:dispatch_get_main_queue()];
	
	__weak typeof(XMPPStreamTest) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		XMPPMessage *fakeMessage = [self fakeMessage];
		[weakStreamTest fakeMessageResponse:fakeMessage];
	};
	
	[messageArchiveManagement retrieveMessageArchiveWithFields:nil withResultSet:nil];
	
	[self waitForExpectationsWithTimeout:1 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
	
}

- (void)xmppMessageArchiveManagement:(XMPPMessageArchiveManagement *)xmppMessageArchiveManagement didReceiveMAMMessage:(XMPPMessage *)message{

	[self.delegateExpectation fulfill];
}

- (void)testDelegateDidReceiveIQ {
	self.delegateExpectation = [self expectationWithDescription:@"Delegate"];
	
	XMPPStreamTest *streamTest = [[XMPPStreamTest alloc] init];
	
	XMPPMessageArchiveManagement *messageArchiveManagement = [[XMPPMessageArchiveManagement alloc] init];
	[messageArchiveManagement activate:streamTest];
	[messageArchiveManagement addDelegate:self delegateQueue:dispatch_get_main_queue()];
	
	__weak typeof(XMPPStreamTest) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		NSString *elementID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *fakeIQResponse = [self fakeIQWithID:elementID];
		[weakStreamTest fakeIQResponse:fakeIQResponse];
	};
	
	[messageArchiveManagement retrieveMessageArchiveWithFields:nil withResultSet:nil];
	
	[self waitForExpectationsWithTimeout:1 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)xmppMessageArchiveManagement:(XMPPMessageArchiveManagement *)xmppMessageArchiveManagement didFinishReceivingMessagesWithSet:(XMPPResultSet *)resultSet {
	
	XCTAssertEqualObjects(@"28482-98726-73623", resultSet.first);
	XCTAssertEqualObjects(@"09af3-cc343-b409f", resultSet.last);
	XCTAssertEqual(20, resultSet.count);
	XCTAssertEqual(0, resultSet.firstIndex);
	
	[self.delegateExpectation fulfill];
}


- (XMPPMessage *) fakeMessage{
	NSMutableString *s = [NSMutableString string];
	[s appendString: @"<message id='aeb213' to='juliet@capulet.lit/chamber'>"];
	[s appendString: @"   <result xmlns='urn:xmpp:mam:1' queryid='f27' id='28482-98726-73623'>"];
	[s appendString: @"      <forwarded xmlns='urn:xmpp:forward:0'>"];
	[s appendString: @"         <delay xmlns='urn:xmpp:delay' stamp='2010-07-10T23:08:25Z'/>"];
	[s appendString: @"         <message xmlns='jabber:client' from='witch@shakespeare.lit' to='macbeth@shakespeare.lit'>"];
	[s appendString: @"            <body>Hail to thee</body>"];
	[s appendString: @"         </message>"];
	[s appendString: @"      </forwarded>"];
	[s appendString: @"   </result>"];
	[s appendString: @"</message>"];
	
	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	return [XMPPMessage messageFromElement:[doc rootElement]];
}

- (XMPPIQ *) fakeIQWithID:(NSString *) elementID{
	NSMutableString *s = [NSMutableString string];
	[s appendString: @"<iq type='result' id='q29302'>"];
	[s appendString: @"   <fin xmlns='urn:xmpp:mam:1'>"];
	[s appendString: @"      <set xmlns='http://jabber.org/protocol/rsm'>"];
	[s appendString: @"         <first index='0'>28482-98726-73623</first>"];
	[s appendString: @"         <last>09af3-cc343-b409f</last>"];
	[s appendString: @"         <count>20</count>"];
	[s appendString: @"      </set>"];
	[s appendString: @"   </fin>"];
	[s appendString: @"</iq>"];
	
	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	XMPPIQ *iq = [XMPPIQ iqFromElement:[doc rootElement]];
	[iq addAttributeWithName:@"id" stringValue:elementID];

	return iq;
}

@end
