//
//  XMPPvCardTempTests.swift
//  XMPPFrameworkSwiftTests
//
//  Created by Oleg Langer on 07.04.20.
//

import XCTest
#if SWIFT_PACKAGE
    import XMPPFramework
    import XMPPFrameworkSwift
#endif

class XMPPvCardTempTests: XCTestCase {
    var xmlString: String!
    var sut: XMPPvCardTemp!
    
    override func setUp() {
        xmlString = """
        <vCard xmlns="vcard-temp">
            <NICKNAME>DESKTOP</NICKNAME>
            <EMAIL>
                <INTERNET/>
                <USERID>q_dekstop@example.com</USERID>
            </EMAIL>
            <TEL>
                <WORK/>
                <VOICE/>
                <NUMBER>303-308-3282</NUMBER>
            </TEL>
        </vCard>
        """
        let element = try! XMLElement(xmlString: xmlString)
        sut = XMPPvCardTemp.vCardTemp(from: element)
    }

    func testCreateFromXMLString() {
        XCTAssertNotNil(sut)
    }
    
    func testGetEmailAddress() {
        XCTAssertEqual(sut.emailAddresses.count, 1)
        let email = sut.emailAddresses.first
        XCTAssertNotNil(email)
        XCTAssertEqual(email?.userid, "q_dekstop@example.com")
        XCTAssertEqual(email?.isInternet, true)
    }
    
    func testRemoveEmailAddress() {
        let email = sut.emailAddresses.first!
        sut.removeEmailAddress(email)
        
        XCTAssertEqual(sut.emailAddresses.count, 0)
    }
    
    func testAddEmailAddress() {
        // Remove all first
        sut.clearEmailAddresses()
        
        let element = XMLElement(name: "EMAIL")
        let newMail = XMPPvCardTempEmail.vCardEmail(from: element)
        newMail.isWork = true
        newMail.userid = "new_mail@example.com"
        sut.addEmailAddress(newMail)
        
        XCTAssertEqual(sut.emailAddresses.first, newMail)
    }
    
    func testGetTelecomAddress() {
        XCTAssertEqual(sut.telecomsAddresses.count, 1)
        let tel = sut.telecomsAddresses.first!
        XCTAssertTrue(tel.isWork)
        XCTAssertTrue(tel.isVoice)
        XCTAssertEqual(tel.number, "303-308-3282")
    }
    
    func testRemoveTelecomAddresses() {
        let tel = sut.telecomsAddresses.first!
        sut.removeTelecomsAddress(tel)
        XCTAssertEqual(sut.telecomsAddresses.count, 0)
    }
    
    func testAddTelecomAddress() {
        sut.clearTelecomsAddresses()
        
        let element = XMLElement(name: "TEL")
        let newTel = XMPPvCardTempTel.vCardTel(from: element)
        newTel.isCell = true
        newTel.number = "101"
        sut.addTelecomsAddress(newTel)
        
        XCTAssertEqual(sut.telecomsAddresses.count, 1)
        XCTAssertEqual(sut.telecomsAddresses.first!, newTel)
    }
}
