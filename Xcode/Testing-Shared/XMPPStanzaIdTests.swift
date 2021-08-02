//
//  XMPPStanzaIdTests.swift
//  XMPPFrameworkTests
//
//  Created by Chris Ballinger on 10/12/17.
//

import XCTest
import XMPPFramework

extension XMPPJID {
    static var alice: XMPPJID {
        return XMPPJID(string: "alice@example.com/phone")!
    }
    static var bob: XMPPJID {
        return XMPPJID(string: "bob@example.com/phone")!
    }
}

class XMPPStanzaIdTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testParsingStanzaId() {
        let originId = "de305d54-75b4-431b-adb2-eb6b9e546013"
        let stanzaId = "5f3dbc5e-e1d3-4077-a492-693f3769c7ad"
        let stanzaIdBy = "room@muc.example.com"
        let xmlString = """
        <message xmlns='jabber:client'
                 to='room@muc.example.com'
                 type='groupchat'>
          <body>Typical body text</body>
          <stanza-id xmlns='urn:xmpp:sid:0'
                     id='\(stanzaId)'
                     by='\(stanzaIdBy)'/>
          <origin-id xmlns='urn:xmpp:sid:0' id='\(originId)'/>
        </message>
        """
        let message = try! XMPPMessage(xmlString: xmlString)
        let stanza = message.stanzaIds.first!
        XCTAssertEqual(originId, message.originId!)
        XCTAssertEqual(stanzaId, stanza.value)
        XCTAssertEqual(stanzaIdBy, stanza.key.bare)
    }
    
    func testRealWorldDirectStanza() {
        let aliceJID = XMPPJID.alice
        let bobJID = XMPPJID.bob
        let aliceId = "ZIz3m-9WfaGiDEFF"
        let bobId = "aGPHNtY3YWO21PPe"

        let xmlString = """
        <message from="\(aliceJID.full)" id="dec6ee2c-2bc3-4d5b-ac05-be7adaeadd77" to="\(bobJID.bare)" type="chat" xmlns="jabber:client">
            <body>Boop</body>
            <markable xmlns="urn:xmpp:chat-markers:0"/>
            <request xmlns="urn:xmpp:receipts"/>
            <origin-id id="dec6ee2c-2bc3-4d5b-ac05-be7adaeadd77" xmlns="urn:xmpp:sid:0"/>
            <active xmlns="http://jabber.org/protocol/chatstates"/>
            <stanza-id by="\(aliceJID.bare)" id="\(aliceId)" xmlns="urn:xmpp:sid:0"/>
            <stanza-id by="\(bobJID.bare)" id="\(bobId)" xmlns="urn:xmpp:sid:0"/>
        </message>
        """
        let message = try! XMPPMessage(xmlString: xmlString)
        let stanzaIds = message.stanzaIds
        XCTAssertEqual(stanzaIds[aliceJID.bareJID]!, aliceId)
        XCTAssertEqual(stanzaIds[bobJID.bareJID]!, bobId)
    }
    
    func testAddOriginId() {
        let xmlString = """
        <message xmlns='jabber:client'
                 to='room@muc.example.com'
                 type='groupchat'>
          <body>Typical body text</body>
        </message>
        """
        let originId = "de305d54-75b4-431b-adb2-eb6b9e546013"
        let message = try! XMPPMessage(xmlString: xmlString)
        XCTAssertNil(message.originId)
        
        message.addOriginId(originId)
        XCTAssertEqual(originId, message.originId!)
    }
    
    
}
