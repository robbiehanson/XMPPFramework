//
//  XMPPModule.swift
//  XMPPFramework
//
//  Created by Chris Ballinger on 11/14/17.
//  Copyright © 2017 XMPPFramework. All rights reserved.
//

import Foundation

// MARK: - Multicast Delegate
public extension XMPPModule {
    
    /**
     * Multicast helper which, when used with the invoke function in the class extension,
     * helps with code completion of the intended delegate methods.
     *
     * Important: You must create a stub extension on Multicast conforming to the
     *            delegate type(s) your module will broadcast.
     *
     * For example, in a XMPPModule subclass called XMPPBookmarksModule
     * with a multicast delegate called XMPPBookmarksDelegate, somewhere
     * you will need to create an empty class extension like this:
     *
     *   extension GCDMulticastDelegate: XMPPBookmarksDelegate {}
     *
     * Then in your code you may safely call:
     *
     *   multicast.invoke(ofType: XMPPBookmarksDelegate.self, { (multicast) in
     *       multicast.xmppBookmarks!(self, didNotRetrieveBookmarks: obj as? XMPPIQ)
     *   })
     */
    public var multicast: GCDMulticastDelegate {
        return __multicastDelegate as! GCDMulticastDelegate
    }
    
    /**
     * This helper helps smooth things over with the multicastDelegate.
     * Normally you'd have to repeatedly downcast 'Any' to 'AnyObject' every time
     * you want to send an arbitrary invocation to the multicastDelegate.
     *
     * Note: You must use '!'  instead of '?' in your method call
     *       otherwise the invocation will be ignored.
     *
     * For example, in your XMPPModule subclass:
     *
     * multicastDelegate.xmppBookmarks!(self, didRetrieve: bookmarks, responseIq: responseIq)
     *
     */
    public var multicastDelegate: AnyObject {
        return __multicastDelegate as AnyObject
    }
}

// MARK: - Synchronization
public extension XMPPModule {
    
    /**
     * Dispatches block synchronously or asynchronously on moduleQueue, or
     * executes directly if we're already on the moduleQueue.
     * This is most useful for synchronizing external read
     * access to properties when writing XMPPModule subclasses.
     *
     *  if (dispatch_get_specific(moduleQueueTag))
     *      block();
     *  else
     *      dispatch_sync(moduleQueue, block); (or dispatch_async)
     */
    public func performBlock(async: Bool = false, _ block: @escaping ()->()) {
        if async {
            __performBlockAsync(block)
        } else {
            __perform(block)
        }
    }
}
