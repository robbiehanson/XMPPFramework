//
//  Date+XEP_0082.swift
//  XMPPFramework
//
//  Created by Chris Ballinger on 12/7/17.
//  Copyright © 2017 XMPPFramework. All rights reserved.
//

import Foundation
#if canImport(XMPPFramework)
import XMPPFramework
#endif

public extension Date {
    
    static func from(xmppDateString: String) -> Date? {
        if let date = XMPPDateTimeProfiles.parseDate(xmppDateString) {
            return date as Date
        }
        return nil
    }
    
    static func from(xmppTimeString: String) -> Date? {
        if let date = XMPPDateTimeProfiles.parseTime(xmppTimeString) {
            return date as Date
        }
        return nil
    }
    
    static func from(xmppDateTimeString: String) -> Date? {
        if let date = XMPPDateTimeProfiles.parseDateTime(xmppDateTimeString) {
            return date as Date
        }
        return nil
    }
    
    var xmppDateString: String {
        return (self as NSDate).xmppDateString
    }
    
    var xmppTimeString: String {
        return (self as NSDate).xmppTimeString
    }
    
    var xmppDateTimeString: String {
        return (self as NSDate).xmppDateTimeString
    }
}
