//
//  GCDMulticastDelegate.swift
//  XMPPFramework
//
//  Created by Chris Ballinger on 11/15/17.
//  Copyright © 2017 XMPPFramework. All rights reserved.
//

import Foundation

/**
 * This helper makes it slightly easier to call the MulticastDelegate
 * with the caveat that you must create an empty GCDMulticastDelegate class extension
 * for the protocols you'd like it to handle.
 *
 * For example, in a XMPPModule subclass called XMPPBookmarksModule
 * with a multicast delegate called XMPPBookmarksDelegate, somewhere
 * you will need to create an empty class extension like this:
 *
 * extension GCDMulticastDelegate: XMPPBookmarksDelegate {}
 *
 * This will prevent your code from crashing during the forced cast.
 */
extension GCDMulticastDelegate {
    /**
     * This is a helper mainly to provide better code completion.
     *
     * multicast.invoke(ofType: XMPPBookmarksDelegate.self, { (multicast) in
     *     multicast.xmppBookmarks!(self, didNotRetrieveBookmarks: obj as? XMPPIQ)
     * })
     */
    public func invoke<T>(ofType: T.Type, _ invocation: (_ multicast: T) -> ()) {
        // Crashing here? See the documentation above.
        // You must implement a stub extension on GCDMulticastDelegate conforming to the
        // delegate type you are attempting to downcast.
        invocation(self as! T)
    }
}

