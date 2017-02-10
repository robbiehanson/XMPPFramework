//
//  XMPP0030Tests.m
//  XMPPFrameworkTests
//
//  Created by Andres Canal on 7/7/16.
//
//

#import <XCTest/XCTest.h>
#import "XMPPFramework/XMPPIQ+XEP_0030.h"

@interface XMPP0030Tests : XCTestCase

@end

@implementation XMPP0030Tests

- (void)testIQDiscoItem {
	
	XMPPJID *jid = [XMPPJID jidWithString:@"test@server.com"];
	XMPPIQ *discoItemsIQ = [XMPPIQ discoverItemsAssociatedWithJID:jid];
	
	NSXMLElement *queryElement = [discoItemsIQ elementForName:@"query"];
	XCTAssertEqualObjects(queryElement.xmlns, @"http://jabber.org/protocol/disco#items");
	
	XCTAssertEqualObjects(discoItemsIQ.to, jid);
	XCTAssertEqualObjects(discoItemsIQ.type, @"get");
}

- (void)testParsingDiscoItemsResponse {
	
	//	<iq xmlns='jabber:client' from='shakespeare.lit'
	//                              to='@shakespeare.lit'
	//                              id='items1' type='result'>
	//	   <query xmlns='http://jabber.org/protocol/disco#items'>
	//			<item jid='muc.erlang-solutions.com'/>
	//			<item jid='muclight.erlang-solutions.com'/>
	//			<item jid='pubsub.erlang-solutions.com'/>
	//			<item jid='vjud.erlang-solutions.com'/>
	//		</query>
	//	</iq>
	
	NSMutableString *s = [NSMutableString string];
	[s appendString: @"<iq xmlns='jabber:client' from='shakespeare.lit'"];
	[s appendString: @"                            to='@shakespeare.lit'"];
	[s appendString: @"                            id='items1' type='result'>"];
	[s appendString: @"   <query xmlns='http://jabber.org/protocol/disco#items'>"];
	[s appendString: @"		<item jid='muc.erlang-solutions.com'/>"];
	[s appendString: @"		<item jid='muclight.erlang-solutions.com'/>"];
	[s appendString: @"		<item jid='pubsub.erlang-solutions.com'/>"];
	[s appendString: @"		<item jid='vjud.erlang-solutions.com'/>"];
	[s appendString: @"	  </query>"];
	[s appendString: @"</iq>"];
	
	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	XMPPIQ *iq = [XMPPIQ iqFromElement:[doc rootElement]];

	NSArray *parsedItems = [XMPPIQ parseDiscoveredItemsFromIQ:iq];
	XCTAssertEqualObjects([((NSXMLElement *)parsedItems[0]) attributeForName:@"jid"].stringValue, @"muc.erlang-solutions.com");
	XCTAssertEqualObjects([((NSXMLElement *)parsedItems[1]) attributeForName:@"jid"].stringValue, @"muclight.erlang-solutions.com");
	XCTAssertEqualObjects([((NSXMLElement *)parsedItems[2]) attributeForName:@"jid"].stringValue, @"pubsub.erlang-solutions.com");
	XCTAssertEqualObjects([((NSXMLElement *)parsedItems[3]) attributeForName:@"jid"].stringValue, @"vjud.erlang-solutions.com");
}

- (void)testParsingDiscoItemsWithNoItems {
	
	//	<iq xmlns='jabber:client' from='shakespeare.lit'
	//                              to='@shakespeare.lit'
	//                              id='items1' type='result'>
	//	   <query xmlns='http://jabber.org/protocol/disco#items'>
	//	   </query>
	//	</iq>
	
	NSMutableString *s = [NSMutableString string];
	[s appendString: @"<iq xmlns='jabber:client' from='shakespeare.lit'"];
	[s appendString: @"                            to='@shakespeare.lit'"];
	[s appendString: @"                            id='items1' type='result'>"];
	[s appendString: @"  <query xmlns='http://jabber.org/protocol/disco#items'>"];
	[s appendString: @"	 </query>"];
	[s appendString: @"</iq>"];
	
	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	XMPPIQ *iq = [XMPPIQ iqFromElement:[doc rootElement]];
	
	NSArray *parsedItems = [XMPPIQ parseDiscoveredItemsFromIQ:iq];
	XCTAssertNotNil(parsedItems);
}

- (void)testParsingDiscoItemsWithWrongIQ {
	
	//	<iq xmlns='jabber:client' from='shakespeare.lit'
	//                              to='@shakespeare.lit'
	//                              id='items1' type='result'>
	//	   <query xmlns='http://jabber.org/protocol/disco#items'>
	//	   </query>
	//	</iq>
	
	NSMutableString *s = [NSMutableString string];
	[s appendString: @"<iq xmlns='jabber:client' from='shakespeare.lit'"];
	[s appendString: @"                            to='@shakespeare.lit'"];
	[s appendString: @"                            id='items1' type='result'>"];
	[s appendString: @"  <query xmlns='anotherxmlns'>"];
	[s appendString: @"	 </query>"];
	[s appendString: @"</iq>"];
	
	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	XMPPIQ *iq = [XMPPIQ iqFromElement:[doc rootElement]];
	
	NSArray *parsedItems = [XMPPIQ parseDiscoveredItemsFromIQ:iq];
	XCTAssertNil(parsedItems);
}

- (void)testIQDiscoInfo {
	
	XMPPJID *jid = [XMPPJID jidWithString:@"test@server.com"];
	XMPPIQ *discoItemsIQ = [XMPPIQ discoverInfoAssociatedWithJID:jid];
	
	NSXMLElement *queryElement = [discoItemsIQ elementForName:@"query"];
	XCTAssertEqualObjects(queryElement.xmlns, @"http://jabber.org/protocol/disco#info");
	
	XCTAssertEqualObjects(discoItemsIQ.to, jid);
	XCTAssertEqualObjects(discoItemsIQ.type, @"get");
}

- (void)testParsingDiscoInfoResponse {
	
	//    <iq xmlns='jabber:client' from='erlang-solutions.com' to='ramabit@erlang-solutions.com/Andress-MacBook-Pro' id='items1' type='result'>
	//      <query xmlns='http://jabber.org/protocol/disco#info'>
	//        <identity category='pubsub' type='pep'/>
	//        <identity category='server' type='im' name='ejabberd'/>
	//        <feature var='erlang-solutions.com:xmpp:token-auth:0'/>
	//        <feature var='urn:xmpp:mam:0'/>
	//        <feature var='urn:xmpp:mam:1'/>
	//      </query>
	//    </iq>
	
	NSMutableString *s = [NSMutableString string];
	[s appendString:@"<iq xmlns='jabber:client' id='items1' type='result'>"];
	[s appendString:@"  <query xmlns='http://jabber.org/protocol/disco#info'>"];
	[s appendString:@"    <identity category='pubsub' type='pep'/>"];
	[s appendString:@"    <identity category='server' type='im' name='ejabberd'/>"];
	[s appendString:@"    <feature var='urn:xmpp:mam:0'/>"];
	[s appendString:@"    <feature var='urn:xmpp:mam:1'/>"];
	[s appendString:@"  </query>"];
	[s appendString:@"</iq>"];
	
	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	XMPPIQ *iq = [XMPPIQ iqFromElement:[doc rootElement]];
	
	NSArray *parsedItems = [XMPPIQ parseDiscoveredInfoFromIQ:iq];
	XCTAssertEqual(parsedItems.count, 4);
}

- (void)testParsingDiscoInfoWithNoFeatures {
	
	//	<iq xmlns='jabber:client' from='shakespeare.lit'
	//                              to='@shakespeare.lit'
	//                              id='items1' type='result'>
	//	   <query xmlns='http://jabber.org/protocol/disco#items'>
	//	   </query>
	//	</iq>
	
	NSMutableString *s = [NSMutableString string];
	[s appendString: @"<iq xmlns='jabber:client' from='shakespeare.lit'"];
	[s appendString: @"                            to='@shakespeare.lit'"];
	[s appendString: @"                            id='items1' type='result'>"];
	[s appendString: @"  <query xmlns='http://jabber.org/protocol/disco#info'>"];
	[s appendString: @"	 </query>"];
	[s appendString: @"</iq>"];
	
	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	XMPPIQ *iq = [XMPPIQ iqFromElement:[doc rootElement]];
	
	NSArray *parsedItems = [XMPPIQ parseDiscoveredInfoFromIQ:iq];
	XCTAssertNotNil(parsedItems);
}

- (void)testParsingDiscoInfoWithWrongIQ {
	
	//	<iq xmlns='jabber:client' from='shakespeare.lit'
	//                              to='@shakespeare.lit'
	//                              id='items1' type='result'>
	//	   <query xmlns='http://jabber.org/protocol/disco#items'>
	//	   </query>
	//	</iq>
	
	NSMutableString *s = [NSMutableString string];
	[s appendString: @"<iq xmlns='jabber:client' from='shakespeare.lit'"];
	[s appendString: @"                            to='@shakespeare.lit'"];
	[s appendString: @"                            id='items1' type='result'>"];
	[s appendString: @"  <query xmlns='anotherxmlns'>"];
	[s appendString: @"	 </query>"];
	[s appendString: @"</iq>"];
	
	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	XMPPIQ *iq = [XMPPIQ iqFromElement:[doc rootElement]];
	
	NSArray *parsedItems = [XMPPIQ parseDiscoveredItemsFromIQ:iq];
	XCTAssertNil(parsedItems);
}

@end
