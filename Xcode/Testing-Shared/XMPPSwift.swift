//
//  XMPPSwift.swift
//  XMPPSwift
//
//  Created by David Chiles on 1/28/16.
//
//

import XCTest
import XMPPFramework
import KissXML

class XMPPSwift: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testCreatingElement() {
        let e = XMLElement()
        let element = XMPPElement()
        XCTAssertNotNil(e)
        XCTAssertNotNil(element)
    }
    
    func testCreateStream() {
        let stream = XMPPStream()
        XCTAssertNotNil(stream)
    }
    
    func testCreateParser() {
        let parser = XMPPParser()
        XCTAssertNotNil(parser)
    }
    
    func testJIDCompare() {
        let jid1 = XMPPJID(string: "a@a.com")!
        let jid2 = XMPPJID(string: "b@b.com")!
        XCTAssertFalse(jid1.isEqual(to: jid2, options: .bare))
    }
    
}
