//
//  XMPPPushTests.swift
//  XMPPFrameworkTests
//
//  Created by David Chiles on 2/9/16.
//
//
import XMPPFramework

import XCTest

class XMPPPushTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testEnableStanzaWithoutOptions() {
        
        let jid = XMPPJID.jidWithString("push-5.client.example")
        let node = "yxs32uqsflafdk3iuqo"
        let enableStanza =  XMPPIQ.enableNotificationsElementWithJID(jid, node: node, options: nil)
        XCTAssertNotNil(enableStanza,"No Stanza")
        
        /**
        <iq type="set">
            <enable xmlns="urn:xmpp:push:0" jid="push-5.client.example" node="yxs32uqsflafdk3iuqo"></enable>
        </iq>
        */
        XCTAssertTrue(enableStanza.XMLString() == "<iq type=\"set\"><enable xmlns=\"urn:xmpp:push:0\" jid=\"push-5.client.example\" node=\"yxs32uqsflafdk3iuqo\"></enable></iq>","XML does not match \(enableStanza.XMLString())")
    }

    func testEnableStanzaWithOptions() {
        let jid = XMPPJID.jidWithString("push-5.client.example")
        let node = "yxs32uqsflafdk3iuqo"
        let options = ["secret":"eruio234vzxc2kla-91"]
        let enableStanza =  XMPPIQ.enableNotificationsElementWithJID(jid, node: node, options: options)
        XCTAssertNotNil(enableStanza,"No Stanza")
        
        /**
        <iq type="set">
            <enable xmlns="urn:xmpp:push:0" jid="push-5.client.example" node="yxs32uqsflafdk3iuqo">
                <x xmlns="jabber:x:data">
                    <field var="FORM_TYPE"><value>http://jabber.org/protocol/pubsub#publish-options</value></field>
                    <field var="secret"><value>eruio234vzxc2kla-91</value></field>
                </x>
            </enable>
        </iq>
        */
        XCTAssertTrue(enableStanza.XMLString() == "<iq type=\"set\"><enable xmlns=\"urn:xmpp:push:0\" jid=\"push-5.client.example\" node=\"yxs32uqsflafdk3iuqo\"><x xmlns=\"jabber:x:data\"><field var=\"FORM_TYPE\"><value>http://jabber.org/protocol/pubsub#publish-options</value></field><field var=\"secret\"><value>eruio234vzxc2kla-91</value></field></x></enable></iq>","XML does not match \(enableStanza.XMLString())")
    }
    
    func testDisableStanza() {
        let jid = XMPPJID.jidWithString("push-5.client.example")
        let node = "yxs32uqsflafdk3iuqo"
        let disableStanza = XMPPIQ.disableNotificationsElementWithJID(jid, node: node)
        XCTAssertNotNil(disableStanza)
        print("\(disableStanza.XMLString())")
        /**
        <iq type="set">
            <disable xmlns="urn:xmpp:push:0" jid="push-5.client.example" node="yxs32uqsflafdk3iuqo"></disable>
        </iq>
        */
        XCTAssertTrue(disableStanza.XMLString() == "<iq type=\"set\"><disable xmlns=\"urn:xmpp:push:0\" jid=\"push-5.client.example\" node=\"yxs32uqsflafdk3iuqo\"></disable></iq>","XML does not match \(disableStanza.XMLString())")
    }
}
