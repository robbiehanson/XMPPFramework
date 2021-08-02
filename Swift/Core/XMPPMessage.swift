//
//  XMPPMessage.swift
//  XMPPFramework
//
//  Created by Chris Ballinger on 11/21/17.
//  Copyright © 2017 XMPPFramework. All rights reserved.
//

import Foundation
#if canImport(XMPPFramework)
import XMPPFramework
#endif

public extension XMPPMessage {
    enum MessageType: String {
        case chat
        case error
        case groupchat
        case headline
        case normal
    }
    
    var messageType: MessageType? {
        guard let type = self.type else {
            return nil
        }
        return MessageType(rawValue: type)
    }
    
    convenience init(messageType: MessageType? = nil,
                            to: XMPPJID? = nil,
                            elementID: String? = nil,
                            child: XMLElement? = nil) {
        self.init(type: messageType?.rawValue, to: to, elementID: elementID, child: child)
    }
}
