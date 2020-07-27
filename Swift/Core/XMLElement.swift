//
//  XMLElement.swift
//  XMPPFramework
//
//  Created by Chris Ballinger on 11/15/17.
//  Copyright © 2017 XMPPFramework. All rights reserved.
//

import Foundation
import KissXML

/**
 * For whatever reason Swift does not reliably import all of the methods from NSXMLElement+XMPP.h, possibly due to the typealias bug between DDXMLElement and XMLElement on iOS. To prevent this issue, we can simply reimplement the missing ones here.
 */
public extension XMLElement {
    
    // MARK: Extracting a single element.
    
    func element(forName name: String) -> XMLElement? {
        let elements = self.elements(forName: name)
        return elements.first
    }
    
    func element(forName name: String, xmlns: String) -> XMLElement? {
        let elements = self.elements(forLocalName: name, uri: xmlns)
        return elements.first
    }
}
