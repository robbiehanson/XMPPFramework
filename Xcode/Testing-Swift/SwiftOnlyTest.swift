//
//  SwiftOnlyTest.swift
//  XMPPFrameworkSwiftTests
//
//  Created by Chris Ballinger on 11/12/17.
//

import XCTest

#if COCOAPODS
    import XMPPFramework
#else
    import XMPPFrameworkSwift
#endif

class SwiftOnlyTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSwiftOnlyFeature() {
        XCTAssertTrue(XMPPFrameworkSwiftAvailable)
    }
}
