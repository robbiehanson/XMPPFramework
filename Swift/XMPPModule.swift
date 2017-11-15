//
//  XMPPModule.swift
//  XMPPFramework
//
//  Created by Chris Ballinger on 11/14/17.
//  Copyright © 2017 XMPPFramework. All rights reserved.
//

import Foundation

public extension XMPPModule {
    /**
     * This helper helps smooth things over with the multicastDelegate.
     * Normally you'd have to downcast 'Any' to 'AnyObject' every time
     * you want to send a message to the multicastDelegate.
     *
     * Note: You must use '!'  instead of '?' otherwise the invocation will be ignored.
     *
     * For example, in your XMPPModule subclass:
     *
     * multicast.xmppBookmarks!(self, didRetrieve: bookmarks, responseIq: responseIq)
     *
     */
    public var multicast: AnyObject {
        return multicastDelegate as AnyObject
    }
}
