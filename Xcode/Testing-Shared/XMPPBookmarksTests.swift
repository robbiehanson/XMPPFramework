//
//  XMPPBookmarksTests.swift
//  XMPPFrameworkTests
//
//  Created by Chris Ballinger on 11/12/17.
//

import XCTest
import XMPPFramework

class XMPPBookmarksTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testStorageElement() {
        // conference
        let name = "Council of Oberon"
        let autojoin = "true"
        let jid = "council@conference.underhill.org"
        let nick = "Puck"
        let password = "test"
        // url
        let urlName = "Complete Works of Shakespeare"
        let urlString = "http://the-tech.mit.edu/Shakespeare/"
        
        let xmlString = """
        <storage xmlns='storage:bookmarks'>
          <conference name='\(name)'
                      autojoin='\(autojoin)'
                      jid='\(jid)'>
            <nick>\(nick)</nick>
            <password>\(password)</password>
          </conference>
          <url name='\(urlName)'
                url='\(urlString)'/>
        </storage>
        """
        let xml = try! XMLElement(xmlString: xmlString)
        
        let storage = XMPPBookmarksStorageElement(from: xml)!
        
        // Test conference
        
        let conference = storage.conferenceBookmarks.first!
        
        let testConference = { (_ conference: XMPPConferenceBookmark) in
            XCTAssertEqual(name, conference.bookmarkName)
            XCTAssertEqual(true, conference.autoJoin)
            XCTAssertEqual(jid, conference.jid?.bare)
            XCTAssertEqual(nick, conference.nick)
            XCTAssertEqual(password, conference.password)
        }
        testConference(conference)
        
        let outXml = conference.element
        let outConference = XMPPConferenceBookmark.fromElement(outXml)!
        testConference(outConference)
        
        // Test URL
        
        let url = storage.urlBookmarks.first!
        
        let testUrl = { (_ url: XMPPURLBookmark) in
            XCTAssertEqual(url.bookmarkName, urlName)
            XCTAssertEqual(url.url?.absoluteString, urlString)
        }
        testUrl(url)
        
        let outUrlXml = url.element
        let outUrl = XMPPURLBookmark.fromElement(outUrlXml)!
        testUrl(outUrl)
    }
    
}
