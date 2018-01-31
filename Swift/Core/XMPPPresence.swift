//
//  XMPPPresence.swift
//  XMPPFramework
//
//  Created by Chris Ballinger on 11/21/17.
//  Copyright © 2017 XMPPFramework. All rights reserved.
//

import Foundation

public extension XMPPPresence {
    /// The 'type' attribute of a presence stanza is OPTIONAL. A presence stanza that does not possess a 'type' attribute is used to signal to the server that the sender is online and available for communication. If included, the 'type' attribute specifies a lack of availability, a request to manage a subscription to another entity's presence, a request for another entity's current presence, or an error related to a previously-sent presence stanza. If included, the 'type' attribute MUST have one of the following values
    public enum PresenceType: String {
        /// Signals that the entity is no longer available for communication.
        case unavailable
        /// The sender wishes to subscribe to the recipient's presence.
        case subscribe
        /// The sender has allowed the recipient to receive their presence.
        case subscribed
        /// The sender is unsubscribing from another entity's presence.
        case unsubscribe
        /// The subscription request has been denied or a previously-granted subscription has been cancelled.
        case unsubscribed
        ///  A request for an entity's current presence; SHOULD be generated only by a server on behalf of a user.
        case probe
        /// An error has occurred regarding processing or delivery of a previously-sent presence stanza.
        case error
    }
    
    /// The OPTIONAL <show/> element contains non-human-readable XML character data that specifies the particular availability status of an entity or specific resource. A presence stanza MUST NOT contain more than one <show/> element. The <show/> element MUST NOT possess any attributes. If provided, the XML character data value MUST be one of the following (additional availability types could be defined through a properly-namespaced child element of the presence stanza):
    public enum ShowType: String {
        /// The entity or resource is busy (dnd = "Do Not Disturb").
        case dnd
        /// The entity or resource is away for an extended period (xa = "eXtended Away").
        case xa
        ///  The entity or resource is temporarily away.
        case away
        /// The entity or resource is actively interested in chatting.
        case chat
        
        /// For backwards compatibility with XMPPPresenceShow enum
        public var showValue: XMPPPresenceShow {
            switch self {
            case .dnd:
                return .DND
            case .xa:
                return .XA
            case .away:
                return .away
            case .chat:
                return .chat
            }
        }
    }
    
    public var showType: ShowType? {
        guard let show = self.show else {
            return nil
        }
        return ShowType(rawValue: show)
    }
    
    public var presenceType: PresenceType? {
        guard let type = self.type else {
            return nil
        }
        return PresenceType(rawValue: type)
    }
    
    public convenience init(type: PresenceType? = nil,
                            show: ShowType? = nil,
                            status: String? = nil,
                            to jid: XMPPJID? = nil) {
        self.init(type: type?.rawValue, to: jid)
        if let show = show {
            let showElement = XMLElement(name: "show", stringValue: show.rawValue)
            addChild(showElement)
        }
        if let status = status {
            let statusElement = XMLElement(name: "status", stringValue: status)
            addChild(statusElement)
        }
    }
}
