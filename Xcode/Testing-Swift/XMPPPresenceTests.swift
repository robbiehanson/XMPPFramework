//
//  XMPPPresenceTests.swift
//  XMPPFrameworkSwiftTests
//
//  Created by Chris Ballinger on 12/7/17.
//

import XCTest
#if SWIFT_PACKAGE
    import XMPPFramework
    import XMPPFrameworkSwift
#endif

class XMPPPresenceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testParsingIdleSince() {
        let sinceString = "1969-07-21T02:56:15Z"
        let since = Date.from(xmppDateTimeString: sinceString)!
        let xmlString = """
        <presence from='juliet@capulet.com/balcony'>
          <show>away</show>
          <idle xmlns='urn:xmpp:idle:1' since='\(sinceString)'/>
        </presence>
        """
        
        let presence = try! XMPPPresence(xmlString: xmlString)
        XCTAssertEqual(since, presence.idleSince)
    }
    
    func testSettingIdleSince() {
        let xmlString = """
        <presence from='juliet@capulet.com/balcony'>
            <show>away</show>
        </presence>
        """
        
        let presence = try! XMPPPresence(xmlString: xmlString)
        
        let sinceString = "1969-07-21T02:56:15Z"
        let since = Date.from(xmppDateTimeString: sinceString)!
        XCTAssertNil(presence.idleSince)
        presence.addIdle(since: since)
        XCTAssertEqual(since, presence.idleSince)
        XCTAssertEqual(sinceString, presence.idleSince?.xmppDateTimeString)
    }
    

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
