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
    
    func testImportModule() {
        let pushModule = XMPPPushModule()
        XCTAssertNotNil(pushModule)
    }
    
    func testEnableStanzaWithoutOptions() {
        
        let jid = XMPPJID(string: "push-5.client.example")
        let node = "yxs32uqsflafdk3iuqo"
        let enableStanza =  XMPPIQ.enableNotificationsElement(with: jid!, node: node, options: nil)
        XCTAssertNotNil(enableStanza,"No Stanza")

        XCTAssertNotNil(enableStanza.attribute(forName: "id"), "No id attribute")
        enableStanza.removeAttribute(forName: "id")

        /**
        <iq type="set">
            <enable xmlns="urn:xmpp:push:0" jid="push-5.client.example" node="yxs32uqsflafdk3iuqo"></enable>
        </iq>
        */
        let expected = "<iq type=\"set\"><enable xmlns=\"urn:xmpp:push:0\" jid=\"push-5.client.example\" node=\"yxs32uqsflafdk3iuqo\"></enable></iq>"
        var expXml = XMLElement()
        do {
            expXml = try XMLElement(xmlString: expected)
        } catch {
        }
        XCTAssertEqual(expXml.xmlString, enableStanza.xmlString)
    }

    func testEnableStanzaWithOptions() {
        let jid = XMPPJID(string: "push-5.client.example")
        let node = "yxs32uqsflafdk3iuqo"
        let options = ["secret":"eruio234vzxc2kla-91"]
        let enableStanza =  XMPPIQ.enableNotificationsElement(with: jid!, node: node, options: options)
        XCTAssertNotNil(enableStanza,"No Stanza")

        XCTAssertNotNil(enableStanza.attribute(forName: "id"), "No id attribute")
        enableStanza.removeAttribute(forName: "id")

        /**
        <iq type="set">
            <enable xmlns="urn:xmpp:push:0" jid="push-5.client.example" node="yxs32uqsflafdk3iuqo">
                <x xmlns="jabber:x:data" type="submit">
                    <field var="FORM_TYPE"><value>http://jabber.org/protocol/pubsub#publish-options</value></field>
                    <field var="secret"><value>eruio234vzxc2kla-91</value></field>
                </x>
            </enable>
        </iq>
        */
        XCTAssertTrue(enableStanza.xmlString == "<iq type=\"set\"><enable xmlns=\"urn:xmpp:push:0\" jid=\"push-5.client.example\" node=\"yxs32uqsflafdk3iuqo\"><x xmlns=\"jabber:x:data\" type=\"submit\"><field var=\"FORM_TYPE\"><value>http://jabber.org/protocol/pubsub#publish-options</value></field><field var=\"secret\"><value>eruio234vzxc2kla-91</value></field></x></enable></iq>","XML does not match \(enableStanza.xmlString)")
    }
    
    func testDisableStanza() {
        let jid = XMPPJID(string: "push-5.client.example")
        let node = "yxs32uqsflafdk3iuqo"
        let disableStanza = XMPPIQ.disableNotificationsElement(with: jid!, node: node)
        XCTAssertNotNil(disableStanza)
        print("\(disableStanza.xmlString)")

        XCTAssertNotNil(disableStanza.attribute(forName: "id"), "No id attribute")
        disableStanza.removeAttribute(forName: "id")

        /**
        <iq type="set">
            <disable xmlns="urn:xmpp:push:0" jid="push-5.client.example" node="yxs32uqsflafdk3iuqo"></disable>
        </iq>
        */
        let expected = "<iq type=\"set\"><disable xmlns=\"urn:xmpp:push:0\" jid=\"push-5.client.example\" node=\"yxs32uqsflafdk3iuqo\"></disable></iq>"
        var expXml = XMLElement()
        do {
            expXml = try XMLElement(xmlString: expected)
        } catch {
        }
        XCTAssertEqual(disableStanza.xmlString, expXml.xmlString)
    }
}
