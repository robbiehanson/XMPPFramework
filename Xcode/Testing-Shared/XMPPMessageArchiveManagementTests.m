//
//  XMPPMessageArchiveManagementTests.m
//  XMPPFrameworkTests
//
//  Created by Andres on 5/24/16.
//
//

#import <XCTest/XCTest.h>
#import "XMPPMockStream.h"
@import KissXML;

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
	
	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		XMPPIQ *iq = [XMPPIQ iqFromElement:element];
		XCTAssertEqualObjects(@"set", [iq type]);
		
		NSXMLElement *query = [iq elementForName:@"query"];
		XCTAssertNotNil(query);
		
		NSXMLElement *x = [[query elementsForLocalName:@"x" URI:@"jabber:x:data"] firstObject];
        XCTAssertNotNil(x);
		NSArray *fields = [x elementsForName:@"field"];
        XCTAssertNotNil(fields);
		
		NSXMLElement *firstField = [fields firstObject];
		XCTAssertEqualObjects(@"field", [firstField name]);
		XCTAssertEqualObjects(@"FORM_TYPE", [firstField attributeStringValueForName:@"var"]);
		XCTAssertEqualObjects(@"hidden", [firstField attributeStringValueForName:@"type"]);
		
		NSXMLElement *value = [firstField elementForName:@"value"];
		XCTAssertEqualObjects(@"value", [value name]);
		XCTAssertEqualObjects(@"urn:xmpp:mam:2", [value stringValue]);
		
		NSXMLElement *lastField = [fields lastObject];
		XCTAssertEqualObjects(@"field", [lastField name]);
		XCTAssertEqualObjects(@"with", [lastField attributeStringValueForName:@"var"]);
		XCTAssertNil([lastField attributeStringValueForName:@"type"]);
		
		value = [lastField elementForName:@"value"];
		XCTAssertEqualObjects(@"value", [value name]);
		XCTAssertEqualObjects(@"this-is-a-jid", [value stringValue]);
		
        XMPPResultSet *resultSet = [XMPPResultSet resultSetFromElement:[[query elementsForLocalName:@"set" URI:@"http://jabber.org/protocol/rsm"] firstObject]];
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

- (void)testRetrieveTargetedMessageArchive {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Handler IQ with \"to\""];
    
    XMPPJID *archiveJID = [XMPPJID jidWithString:@"test.archive@erlang-solutions.com"];
    
    XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
    streamTest.elementReceived = ^void(NSXMLElement *element) {
        XMPPIQ *iq = [XMPPIQ iqFromElement:element];
        XCTAssertEqualObjects([iq to], archiveJID);
        
        [expectation fulfill];
    };
    
    XMPPMessageArchiveManagement *messageArchiveManagement = [[XMPPMessageArchiveManagement alloc] init];
    [messageArchiveManagement activate:streamTest];
    [messageArchiveManagement retrieveMessageArchiveAt:archiveJID withFields:nil withResultSet:nil];
    
    [self waitForExpectationsWithTimeout:1 handler:^(NSError * _Nullable error) {
        if(error){
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

- (void)testDelegateDidReceiveMAMMessage {
	self.delegateExpectation = [self expectationWithDescription:@"Delegate"];
	
	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	
	XMPPMessageArchiveManagement *messageArchiveManagement = [[XMPPMessageArchiveManagement alloc] init];
	[messageArchiveManagement activate:streamTest];
	[messageArchiveManagement addDelegate:self delegateQueue:dispatch_get_main_queue()];
	
	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(XMPPElement *element) {
		NSString * queryID = [[element elementForName:@"query"] attributeStringValueForName:@"queryid"];
        XCTAssertNotNil(queryID);
		XMPPMessage *fakeMessage = [self fakeMessageWithQueryID:queryID eid:element.elementID];
		[weakStreamTest fakeMessageResponse:fakeMessage];
	};
	
	[messageArchiveManagement retrieveMessageArchiveWithFields:nil withResultSet:nil];
	
	[self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
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
	
	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	
	XMPPMessageArchiveManagement *messageArchiveManagement = [[XMPPMessageArchiveManagement alloc] init];
	[messageArchiveManagement activate:streamTest];
	[messageArchiveManagement addDelegate:self delegateQueue:dispatch_get_main_queue()];
	
	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
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

- (void)testDelegateDidReceiveError {
	self.delegateExpectation = [self expectationWithDescription:@"Delegate"];
	
	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	
	XMPPMessageArchiveManagement *messageArchiveManagement = [[XMPPMessageArchiveManagement alloc] init];
	[messageArchiveManagement activate:streamTest];
	[messageArchiveManagement addDelegate:self delegateQueue:dispatch_get_main_queue()];
	
	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		NSString *elementID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *fakeIQResponse = [self fakeErrorIQWithID:elementID];
		[weakStreamTest fakeIQResponse:fakeIQResponse];
	};
	
	[messageArchiveManagement retrieveMessageArchiveWithFields:nil withResultSet:nil];
	
	[self waitForExpectationsWithTimeout:1 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)xmppMessageArchiveManagement:(XMPPMessageArchiveManagement *)xmppMessageArchiveManagement didFailToReceiveMessages:(XMPPIQ *)error {
	[self.delegateExpectation fulfill];
}


- (void)testRetrievingFormFields {
	self.delegateExpectation = [self expectationWithDescription:@"Delegate"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];

	XMPPMessageArchiveManagement *messageArchiveManagement = [[XMPPMessageArchiveManagement alloc] init];
	[messageArchiveManagement activate:streamTest];
	[messageArchiveManagement addDelegate:self delegateQueue:dispatch_get_main_queue()];

	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		NSString *elementID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *fakeIQResponse = [self fakeFormFieldsMessageWithID:elementID];
		[weakStreamTest fakeIQResponse:fakeIQResponse];
	};

	[messageArchiveManagement retrieveFormFields];

	[self waitForExpectationsWithTimeout:1 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)xmppMessageArchiveManagement:(XMPPMessageArchiveManagement *)xmppMessageArchiveManagement didReceiveFormFields:(XMPPIQ *)iq {
	[self.delegateExpectation fulfill];
}

- (void)testFailToRetrievingFormFields {
	self.delegateExpectation = [self expectationWithDescription:@"Delegate"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];

	XMPPMessageArchiveManagement *messageArchiveManagement = [[XMPPMessageArchiveManagement alloc] init];
	[messageArchiveManagement activate:streamTest];
	[messageArchiveManagement addDelegate:self delegateQueue:dispatch_get_main_queue()];

	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		NSString *elementID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *fakeIQResponse = [self fakeErrorIQWithID:elementID];
		[weakStreamTest fakeIQResponse:fakeIQResponse];
	};

	[messageArchiveManagement retrieveFormFields];

	[self waitForExpectationsWithTimeout:1 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)xmppMessageArchiveManagement:(XMPPMessageArchiveManagement *)xmppMessageArchiveManagement didFailToReceiveFormFields:(XMPPIQ *)iq {
	[self.delegateExpectation fulfill];
}

- (void)testResultAutomaticPaging {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Next page IQ"];
    
    NSInteger pageSize = 10;
    
    XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
    __weak XMPPMockStream *weakStreamTest = streamTest;
    streamTest.elementReceived = ^void(NSXMLElement *element) {
        XMPPIQ *iq = [XMPPIQ iqFromElement:element];
        NSXMLElement *query = [iq elementForName:@"query"];
        
        XMPPResultSet *resultSet = [XMPPResultSet resultSetFromElement:[[query elementsForLocalName:@"set" URI:@"http://jabber.org/protocol/rsm"] firstObject]];
        if (!resultSet) {
            [weakStreamTest fakeIQResponse:[self fakeIQWithID:[iq elementID]]];
            return;
        }
        
        XCTAssertEqual(pageSize, resultSet.max);
        XCTAssertEqualObjects(@"09af3-cc343-b409f", resultSet.after);
        
        [expectation fulfill];
    };
    
    XMPPMessageArchiveManagement *messageArchiveManagement = [[XMPPMessageArchiveManagement alloc] init];
    messageArchiveManagement.resultAutomaticPagingPageSize = pageSize;
    [messageArchiveManagement activate:streamTest];
    [messageArchiveManagement retrieveMessageArchiveWithFields:nil withResultSet:nil];
    
    [self waitForExpectationsWithTimeout:1 handler:^(NSError * _Nullable error) {
        if(error){
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

- (XMPPMessage *)fakeMessageWithQueryID:(NSString *)queryID eid:(NSString*)eid{
	
	NSString *resultOpenXML = [NSString stringWithFormat:@"<result xmlns='urn:xmpp:mam:2' queryid='%@' id='28482-98726-73623'>",queryID];
	
	NSMutableString *s = [NSMutableString string];
	[s appendFormat: @"<message id='%@' to='juliet@capulet.lit/chamber'>", eid];
	[s appendString: resultOpenXML];
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

- (XMPPIQ *)fakeIQWithID:(NSString *) elementID{
	NSMutableString *s = [NSMutableString string];
	[s appendString: @"<iq type='result' id='q29302'>"];
	[s appendString: @"   <fin xmlns='urn:xmpp:mam:2'>"];
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

- (XMPPIQ *)fakeErrorIQWithID:(NSString *) elementID{
	NSString *s = @"<iq type='error' id='juliet2'></iq>";
	
	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	XMPPIQ *iq = [XMPPIQ iqFromElement:[doc rootElement]];
	[iq addAttributeWithName:@"id" stringValue:elementID];
	
	return iq;
}

- (XMPPIQ *)fakeFormFieldsMessageWithID:(NSString *) elementID{
	NSMutableString *s = [NSMutableString string];
	[s appendString: @"<iq type='result' id='form1'>"];
	[s appendString: @"  <query xmlns='urn:xmpp:mam:2'>"];
	[s appendString: @"    <x xmlns='jabber:x:data' type='form'>"];
	[s appendString: @"      <field type='hidden' var='FORM_TYPE'>"];
	[s appendString: @"        <value>urn:xmpp:mam:2</value>"];
	[s appendString: @"      </field>"];
	[s appendString: @"      <field type='jid-single' var='with'/>"];
	[s appendString: @"      <field type='text-single' var='start'/>"];
	[s appendString: @"      <field type='text-single' var='end'/>"];
	[s appendString: @"      <field type='text-single' var='urn:example:xmpp:free-text-search'/>"];
	[s appendString: @"      <field type='text-single' var='urn:example:xmpp:stanza-content'/>"];
	[s appendString: @"    </x>"];
	[s appendString: @"  </query>"];
	[s appendString: @"</iq>"];

	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	XMPPIQ *iq = [XMPPIQ iqFromElement:[doc rootElement]];
	[iq addAttributeWithName:@"id" stringValue:elementID];

	return iq;
}

@end
