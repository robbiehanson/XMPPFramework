//
//  XMPPServiceDiscoveryTests.m
//  XMPPFrameworkTests
//
//  Created by Andres Canal on 5/27/16.
//
//

#import <XCTest/XCTest.h>
#import "XMPPFramework/XMPPServiceDiscovery.h"
#import "XMPPMockStream.h"

@interface XMPPServiceDiscoveryTests : XCTestCase <XMPPServiceDiscoveryDelegate>
@property (nonatomic, strong) XCTestExpectation *delegateExpectation;
@end

@implementation XMPPServiceDiscoveryTests

- (void) testDiscoverInformationAbout{
	self.delegateExpectation = [self expectationWithDescription:@"Information Response"];
	
	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPServiceDiscovery *serviceDiscovery = [[XMPPServiceDiscovery alloc] init];
	[serviceDiscovery activate:streamTest];
	[serviceDiscovery addDelegate:self delegateQueue:dispatch_get_main_queue()];
	
	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		NSString *elementID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *iq = [self fakeInfoIQWithID:elementID];
		[weakStreamTest fakeIQResponse:iq];
	};

	[serviceDiscovery discoverInformationAboutJID:[XMPPJID jidWithString:@"test.com"]];
	
	[self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)xmppServiceDiscovery:(XMPPServiceDiscovery *)sender didDiscoverInformation:(NSArray *)items{
	XCTAssertEqual(items.count, 9);
	[self.delegateExpectation fulfill];
}

- (void) testDiscoverItems{
	self.delegateExpectation = [self expectationWithDescription:@"Items Response"];
	
	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPServiceDiscovery *serviceDiscovery = [[XMPPServiceDiscovery alloc] init];
	[serviceDiscovery activate:streamTest];
	[serviceDiscovery addDelegate:self delegateQueue:dispatch_get_main_queue()];
	
	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		NSString *elementID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *iq = [self fakeItemIQWithID:elementID];
		[weakStreamTest fakeIQResponse:iq];
	};
	
	[serviceDiscovery discoverItemsAssociatedWithJID:[XMPPJID jidWithString:@"test.com"]];
	
	[self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)xmppServiceDiscovery:(XMPPServiceDiscovery *)sender didDiscoverItems:(NSArray *)items{
	XCTAssertEqual(items.count, 8);
	[self.delegateExpectation fulfill];
}

- (void) testError{
	self.delegateExpectation = [self expectationWithDescription:@"Error Response"];
	
	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPServiceDiscovery *serviceDiscovery = [[XMPPServiceDiscovery alloc] init];
	[serviceDiscovery activate:streamTest];
	[serviceDiscovery addDelegate:self delegateQueue:dispatch_get_main_queue()];
	
	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		NSString *elementID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *iq = [self fakeErrorWithID:elementID];
		[weakStreamTest fakeIQResponse:iq];
	};
	
	[serviceDiscovery discoverItemsAssociatedWithJID:[XMPPJID jidWithString:@"test.com"]];
	
	[self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (XMPPIQ *)fakeErrorWithID:(NSString *) elementID{
	NSMutableString *s = [NSMutableString string];
	[s appendString:@"<iq type='error'"];
	[s appendString:@"    from='mim.shakespeare.lit'"];
	[s appendString:@"    to='romeo@montague.net/orchard'"];
	[s appendString:@"    id='info3'>"];
	[s appendString:@"  <query xmlns='http://jabber.org/protocol/disco#info' "];
	[s appendString:@"         node='http://jabber.org/protocol/commands'/>"];
	[s appendString:@"  <error type='cancel'>"];
	[s appendString:@"    <not-allowed xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>"];
	[s appendString:@"  </error>"];
	[s appendString:@"</iq>"];

	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	XMPPIQ *iq = [XMPPIQ iqFromElement:[doc rootElement]];
	[iq addAttributeWithName:@"id" stringValue:elementID];

	return iq;
}

- (void)xmppServiceDiscovery:(XMPPServiceDiscovery *)sender didFailToDiscover:(XMPPIQ *)iq{
	XCTAssertNotNil([iq elementForName:@"error"]);
	[self.delegateExpectation fulfill];
}


- (XMPPIQ *)fakeItemIQWithID:(NSString *) elementID{
	NSMutableString *s = [NSMutableString string];
	[s appendString:@"<iq type='result'"];
	[s appendString:@"    from='shakespeare.lit'"];
	[s appendString:@"    to='romeo@montague.net/orchard'"];
	[s appendString:@"    id='items1'>"];
	[s appendString:@"  <query xmlns='http://jabber.org/protocol/disco#items'>"];
	[s appendString:@"    <item jid='people.shakespeare.lit'"];
	[s appendString:@"          name='Directory of Characters'/>"];
	[s appendString:@"    <item jid='plays.shakespeare.lit'"];
	[s appendString:@"          name='Play-Specific Chatrooms'/>"];
	[s appendString:@"    <item jid='mim.shakespeare.lit'"];
	[s appendString:@"          name='Gateway to Marlowe IM'/>"];
	[s appendString:@"    <item jid='words.shakespeare.lit'"];
	[s appendString:@"          name='Shakespearean Lexicon'/>"];
	[s appendString:@"    <item jid='globe.shakespeare.lit'"];
	[s appendString:@"          name='Calendar of Performances'/>"];
	[s appendString:@"    <item jid='headlines.shakespeare.lit'"];
	[s appendString:@"          name='Latest Shakespearean News'/>"];
	[s appendString:@"    <item jid='catalog.shakespeare.lit'"];
	[s appendString:@"          name='Buy Shakespeare Stuff!'/>"];
	[s appendString:@"    <item jid='en2fr.shakespeare.lit'"];
	[s appendString:@"          name='French Translation Service'/>"];
	[s appendString:@"  </query>"];
	[s appendString:@"</iq>"];
	
	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	XMPPIQ *iq = [XMPPIQ iqFromElement:[doc rootElement]];
	[iq addAttributeWithName:@"id" stringValue:elementID];
	
	return iq;
}

- (XMPPIQ *)fakeInfoIQWithID:(NSString *) elementID{

	NSMutableString *s = [NSMutableString string];
	[s appendString: @"<iq type='result'"];
	[s appendString: @"    from='plays.shakespeare.lit'"];
	[s appendString: @"    to='romeo@montague.net/orchard'"];
	[s appendString: @"    id='info1'>"];
	[s appendString: @"  <query xmlns='http://jabber.org/protocol/disco#info'>"];
	[s appendString: @"    <identity"];
	[s appendString: @"        category='conference'"];
	[s appendString: @"        type='text'"];
	[s appendString: @"        name='Play-Specific Chatrooms'/>"];
	[s appendString: @"    <identity"];
	[s appendString: @"        category='directory'"];
	[s appendString: @"        type='chatroom'"];
	[s appendString: @"        name='Play-Specific Chatrooms'/>"];
	[s appendString: @"    <feature var='http://jabber.org/protocol/disco#info'/>"];
	[s appendString: @"    <feature var='http://jabber.org/protocol/disco#items'/>"];
	[s appendString: @"    <feature var='http://jabber.org/protocol/muc'/>"];
	[s appendString: @"    <feature var='jabber:iq:register'/>"];
	[s appendString: @"    <feature var='jabber:iq:search'/>"];
	[s appendString: @"    <feature var='jabber:iq:time'/>"];
	[s appendString: @"    <feature var='jabber:iq:version'/>"];
	[s appendString: @"  </query>"];
	[s appendString: @"</iq>"];
	
	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	XMPPIQ *iq = [XMPPIQ iqFromElement:[doc rootElement]];
	[iq addAttributeWithName:@"id" stringValue:elementID];
	
	return iq;
}

@end
