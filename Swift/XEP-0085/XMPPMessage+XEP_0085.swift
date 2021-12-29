//
//  XMPPMessage+XEP_0085.swift
//  XMPPFramework
//
//  Created by Chris Ballinger on 11/21/17.
//  Copyright © 2017 XMPPFramework. All rights reserved.
//

import Foundation
#if canImport(XMPPFramework)
import XMPPFramework
#endif

/// XEP-0085: Chat States
/// https://xmpp.org/extensions/xep-0085.html
public extension XMPPMessage {
    enum ChatState: String {
        case active
        case composing
        case paused
        case inactive
        case gone
    }
    
    var chatState: ChatState? {
        guard let chatState = self.chatStateValue else {
            return nil
        }
        return ChatState(rawValue: chatState)
    }
    
    func addChatState(_ chatState: ChatState) {
        let element = XMLElement(name: chatState.rawValue, xmlns: ChatStatesXmlns)
        addChild(element)
    }
}
