//
//  XMPPPresence+XEP_0319.swift
//  XMPPFramework
//
//  Created by Chris Ballinger on 12/7/17.
//  Copyright © 2017 XMPPFramework. All rights reserved.
//

import Foundation
import KissXML
#if canImport(XMPPFramework)
import XMPPFramework
#endif

/// XEP-0319: Last User Interaction in Presence
/// This specification defines a way to communicate time of last user interaction with her system using XMPP presence notifications.
/// https://xmpp.org/extensions/xep-0319.html
public extension XMPPPresence {
    /// 'urn:xmpp:idle:1'
    @objc static let idleXmlns = "urn:xmpp:idle:1"
    
    @objc var idleSince: Date? {
        guard let idleElement = element(forName: "idle", xmlns: XMPPPresence.idleXmlns),
            let sinceString = idleElement.attributeStringValue(forName: "since"),
            let since = Date.from(xmppDateTimeString: sinceString) else {
            return nil
        }
        return since
    }
    
    @objc func addIdle(since: Date) {
        let dateString = since.xmppDateTimeString
        let idleElement = XMLElement(name: "idle", xmlns: XMPPPresence.idleXmlns)
        idleElement.addAttribute(withName: "since", stringValue: dateString)
        addChild(idleElement)
    }
    
    convenience init(type: PresenceType? = nil,
                            show: ShowType? = nil,
                            status: String? = nil,
                            idle since: Date? = nil,
                            to jid: XMPPJID? = nil) {
        self.init(type: type, show: show, status: status, to: jid)
        if let since = since {
            addIdle(since: since)
        }
    }
}
