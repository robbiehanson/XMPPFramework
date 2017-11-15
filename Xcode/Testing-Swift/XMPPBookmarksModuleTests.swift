//
//  XMPPBookmarksModuleTests.swift
//  XMPPFrameworkSwiftTests
//
//  Created by Chris Ballinger on 11/14/17.
//

import XCTest

#if COCOAPODS
    import XMPPFramework
#else
    import XMPPFrameworkSwift
#endif

extension XMPPElement {
    func copyElementId(from: XMPPElement) {
        //self.removeAttribute(forName: "id")
        self.addAttribute(withName: "id", stringValue: from.elementID!)
    }
}

class XMPPBookmarksModuleTests: XCTestCase {
    
    let myJID = XMPPJID(string: "username@example.com/home")!
    let stream = XMPPMockStream()
    let bookmarksModule = XMPPBookmarksModule(mode: .privateXmlStorage)
    var expectation: XCTestExpectation? = nil

    override func setUp() {
        super.setUp()
        stream.myJID = myJID
        _ = bookmarksModule.activate(stream)
        bookmarksModule.addDelegate(self, delegateQueue: DispatchQueue.main)
    }
    
    override func tearDown() {
        bookmarksModule.removeDelegate(self)
        bookmarksModule.deactivate()
        super.tearDown()
    }

    func testRetreieveBookmarks() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let xmlString = """
        <iq type="result"
            from="\(myJID.full)"
            to="\(myJID.full)"
            id="1002">
            <query xmlns="jabber:iq:private">
                <storage xmlns='storage:bookmarks'>
                    <conference name='Council of Oberon'
                      autojoin='true'
                      jid='council@conference.underhill.org'>
                        <nick>Puck</nick>
                    </conference>
                    <url name='Complete Works of Shakespeare'
                    url='http://the-tech.mit.edu/Shakespeare/'/>
                </storage>
            </query>
        </iq>
        """
        let result = try! XMLElement(xmlString: xmlString)
        let resultIq = XMPPIQ(from: result)
        
        stream.elementReceived = { element in
            resultIq.copyElementId(from: element)
            self.stream.fakeIQResponse(resultIq)
        }
        bookmarksModule.fetchBookmarks()
        
        expectation = expectation(description: "retreiving bookmarks")
        waitForExpectations(timeout: 5) { (error) in
            
        }
    }


}

extension XMPPBookmarksModuleTests: XMPPBookmarksDelegate {
    func xmppBookmarks(_ sender: XMPPBookmarksModule, didRetrieve bookmarks: [XMPPBookmark], responseIq: XMPPIQ) {
        XCTAssert(bookmarks.count == 2)
        expectation?.fulfill()
    }
    
    func xmppBookmarks(_ sender: XMPPBookmarksModule, didNotRetrieveBookmarks errorIq: XMPPIQ?) {
        expectation?.fulfill()
    }
}
