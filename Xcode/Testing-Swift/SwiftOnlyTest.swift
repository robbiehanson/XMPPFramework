//
//  SwiftOnlyTest.swift
//  XMPPFrameworkSwiftTests
//
//  Created by Chris Ballinger on 11/12/17.
//

import XCTest
import XMPPFrameworkSwift

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
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let element = XMPPElement()
        XCTAssertNotNil(element.swiftTest)
    }
    
}
