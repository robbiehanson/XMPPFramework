//
//  XMPPStanzaIdTests.swift
//  XMPPFrameworkTests
//
//  Created by Chris Ballinger on 10/12/17.
//

import XCTest
import XMPPFramework

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
