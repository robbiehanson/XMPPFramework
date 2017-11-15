//
//  XMPPBookmarksModule.swift
//  XMPPFramework
//
//  Created by Chris Ballinger on 11/14/17.
//  Copyright © 2017 Chris Ballinger. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

@objc public enum XMPPBookmarksMode: Int {
    /// Private XML Storage (XEP-0049)
    /// https://xmpp.org/extensions/xep-0049.html
    case privateXmlStorage
    
    /// Recommended by spec, but unimplemented
    // case pubsub
}

@objc public protocol XMPPBookmarksDelegate: NSObjectProtocol {
    @objc optional func xmppBookmarks(_ sender: XMPPBookmarksModule, didRetrieve bookmarks: [XMPPBookmark], responseIq: XMPPIQ)
    @objc optional func xmppBookmarks(_ sender: XMPPBookmarksModule, didNotRetrieveBookmarks errorIq: XMPPIQ?)
    
    @objc optional func xmppBookmarks(_ sender: XMPPBookmarksModule, didPublish bookmarks: [XMPPBookmark], responseIq: XMPPIQ)
    @objc optional func xmppBookmarks(_ sender: XMPPBookmarksModule, didNotPublishBookmarks errorIq: XMPPIQ?)
}

/// XEP-0048: Booksmarks
///
/// This specification defines an XML data format for use by XMPP clients in storing bookmarks to mult-user chatrooms and web pages. The chatroom bookmarking function includes the ability to auto-join rooms on login.
/// https://xmpp.org/extensions/xep-0048.html
public class XMPPBookmarksModule: XMPPModule {
    
    // MARK: - Properties
    @objc public let mode: XMPPBookmarksMode
    private var tracker: XMPPIDTracker?
    
    // MARK: - Init
    
    /// Right now there's only one mode (privateXmlStorage)
    @objc public init(mode: XMPPBookmarksMode,
                      dispatchQueue: DispatchQueue? = nil) {
        self.mode = mode
        super.init(dispatchQueue: dispatchQueue)
    }
    
    // MARK: - XMPPModule Overrides
    override public func activate(_ xmppStream: XMPPStream) -> Bool {
        guard super.activate(xmppStream) else {
            return false
        }
        performBlockAsync {
            self.tracker = XMPPIDTracker(stream: self.xmppStream, dispatchQueue: self.moduleQueue)
        }
        return true
    }
    
    override public func deactivate() {
        performBlock {
            self.tracker?.removeAllIDs()
            self.tracker = nil
        }
        super.deactivate()
    }
    
    // MARK: - Public API
    
    /// Fetches all of your stored bookmarks on the server
    @objc public func fetchBookmarks() {
        let storage = XMLElement.storage
        let query = XMLElement.query(child: storage)
        let get = XMPPIQ(iqType: .get, child: query)
        
        let handler = { (_ obj: Any, _ info: XMPPTrackingInfo) in
            guard let responseIq = obj as? XMPPIQ,
                let iqType = responseIq.iqType,
                let query = responseIq.query,
                let storage = query.bookmarksStorageElement,
                iqType != .error else {
                    self.multicast.xmppBookmarks!(self, didNotRetrieveBookmarks: obj as? XMPPIQ)
                    return
            }
            
            let bookmarks = storage.bookmarks
            self.multicast.xmppBookmarks!(self, didRetrieve: bookmarks, responseIq: responseIq)
        }
        performBlockAsync {
            self.tracker?.add(get, block: handler, timeout: 30.0)
            self.xmppStream?.send(get)
        }
    }
}

// MARK: - XMPPStreamDelegate

extension XMPPBookmarksModule: XMPPStreamDelegate {
    public func xmppStream(_ sender: XMPPStream, didReceive iq: XMPPIQ) -> Bool {
        guard let type = iq.iqType,
            type == .result || type == .error else {
            return false
        }
        var success = false
        // Some error responses for self or contacts don't have a "from"
        if iq.from == nil, let eid = iq.elementID {
            success = tracker?.invoke(forID: eid, with: iq) ?? false
        } else {
            success = tracker?.invoke(for: iq, with: iq) ?? false
        }
        return success
    }
}

// MARK: - Private Extensions
private extension XMPPIQ {
    var query: XMLElement? {
        return element(forName: PrivateXmlStorageConstants.queryElement, xmlns: PrivateXmlStorageConstants.xmlns)
    }
}

private extension XMLElement {
    static var storage: XMLElement {
        return XMLElement(name: XMPPBookmarkConstants.storageElement, xmlns: XMPPBookmarkConstants.xmlns)
    }
    
    static func query(child: XMLElement? = nil) -> XMLElement {
        let query = XMLElement(name: PrivateXmlStorageConstants.queryElement, xmlns: PrivateXmlStorageConstants.xmlns)
        if let child = child {
            query.addChild(child)
        }
        return query
    }
}

// MARK: - Constants
fileprivate struct PrivateXmlStorageConstants {
    static let xmlns = "jabber:iq:private"
    static let queryElement = "query"
}
