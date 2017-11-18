//
//  XMPPBookmarksModule.swift
//  XMPPFramework
//
//  Created by Chris Ballinger on 11/14/17.
//  Copyright © 2017 Chris Ballinger. All rights reserved.
//

import Foundation

#if COCOAPODS
    import CocoaLumberjack
#else
    import CocoaLumberjackSwift
#endif
    
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
    @discardableResult override public func activate(_ xmppStream: XMPPStream) -> Bool {
        guard super.activate(xmppStream) else {
            return false
        }
        performBlock(async: true) {
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
    
    // MARK: - Public API with multicast response via XMPPBookmarksDelegate
    
    /// Fetches all of your stored bookmarks on the server and responds via XMPPBookmarksDelegate
    @objc public func fetchBookmarks() {
        fetchBookmarks({ (_bookmarks, _responseIq) in
            guard let bookmarks = _bookmarks, let responseIq = _responseIq else {
                self.multicast.invoke(ofType: XMPPBookmarksDelegate.self, { (multicast) in
                    multicast.xmppBookmarks!(self, didNotRetrieveBookmarks: _responseIq)
                })
                return
            }
            self.multicast.invoke(ofType: XMPPBookmarksDelegate.self, { (multicast) in
                multicast.xmppBookmarks!(self, didRetrieve: bookmarks, responseIq: responseIq)
            })
        })
    }
    
    /// Overwrites bookmarks on the server and responds via XMPPBookmarksDelegate
    @objc public func publishBookmarks(_ bookmarks: [XMPPBookmark]) {
        publishBookmarks(bookmarks, completion: { (success, responseIq) in
            if success, let responseIq = responseIq {
                self.multicast.invoke(ofType: XMPPBookmarksDelegate.self, { (multicast) in
                    multicast.xmppBookmarks!(self, didPublish: bookmarks, responseIq: responseIq)
                })
            } else {
                self.multicast.invoke(ofType: XMPPBookmarksDelegate.self, { (multicast) in
                    multicast.xmppBookmarks!(self, didNotPublishBookmarks: responseIq)
                })
            }
        })
    }
    
    // MARK: - Public API with Block response only
    
    /// Fetches bookmarks from server. Block response only (will not trigger MulticastDelegate)
    @objc public func fetchBookmarks(_ completion: @escaping (_ bookmarks: [XMPPBookmark]?, _ responseIq: XMPPIQ?)->(), completionQueue: DispatchQueue? = nil) {
        let storage = XMLElement.storage
        let query = XMLElement.query(child: storage)
        let get = XMPPIQ(iqType: .get, child: query)
        
        // Executes completion block on proper queue
        let completionHandler = { (_ bookmarks: [XMPPBookmark]?, _ responseIq: XMPPIQ?)->() in
            if let completionQueue = completionQueue {
                completionQueue.async {
                    completion(bookmarks, responseIq)
                }
            } else {
                completion(bookmarks, responseIq)
            }
        }
        
        // Handles response from XMPPIDTracker
        let iqHandler = { (_ obj: Any, _ info: XMPPTrackingInfo) in
            guard let responseIq = obj as? XMPPIQ,
                let iqType = responseIq.iqType,
                let query = responseIq.query,
                let storage = query.bookmarksStorageElement,
                iqType != .error else {
                    completionHandler(nil, obj as? XMPPIQ)
                    return
            }
            let bookmarks = storage.bookmarks
            completionHandler(bookmarks, responseIq)
        }
        performBlock(async: true) {
            self.tracker?.add(get, block: iqHandler, timeout: 30.0)
            self.xmppStream?.send(get)
        }
    }
    
    /// Fetches and publishes a merged set of bookmarks on the server. The response block will be nil if there was a failure, or the merged set if successful. Block response only (will not trigger MulticastDelegate)
    @objc public func fetchAndPublish(bookmarksToAdd: [XMPPBookmark], bookmarksToRemove: [XMPPBookmark]? = nil, completion: @escaping (_ bookmarks: [XMPPBookmark]?, _ responseIq: XMPPIQ?)->(), completionQueue: DispatchQueue? = nil) {
        
        // Executes completion block on proper queue
        let completionHandler = { (_ bookmarks: [XMPPBookmark]?, _ responseIq: XMPPIQ?)->() in
            if let completionQueue = completionQueue {
                completionQueue.async {
                    completion(bookmarks, responseIq)
                }
            } else {
                completion(bookmarks, responseIq)
            }
        }
        
        fetchBookmarks({ (responseBookmarks, responseIq) in
            if let responseBookmarks = responseBookmarks {
                let newBookmarks = self.merge(original: responseBookmarks, adding: bookmarksToAdd, removing: bookmarksToRemove ?? [])
                self.publishBookmarks(newBookmarks, completion: { (success, responseIq) in
                    if !success {
                        completionHandler(nil, responseIq)
                    } else {
                        completionHandler(newBookmarks, responseIq)
                    }
                }, completionQueue: completionQueue)
            } else {
                completionHandler(nil, responseIq)
            }
        }, completionQueue: completionQueue)
    }

    
    /// Overwrites bookmarks on the server. Block response only (will not trigger MulticastDelegate)
    @objc public func publishBookmarks(_ bookmarks: [XMPPBookmark], completion: @escaping (_ success: Bool, _ responseIq: XMPPIQ?)->(), completionQueue: DispatchQueue? = nil) {
        let storage = XMLElement.storage
        let query = XMLElement.query(child: storage)
        let set = XMPPIQ(iqType: .set, child: query)
        
        bookmarks.forEach { (bookmark) in
            let element = bookmark.element.copy() as! XMLElement
            storage.addChild(element)
        }
        
        // Executes completion block on proper queue
        let completionHandler = { (_ success: Bool, _ responseIq: XMPPIQ?)->() in
            if let completionQueue = completionQueue {
                completionQueue.async {
                    completion(success, responseIq)
                }
            } else {
                completion(success, responseIq)
            }
        }
        
        // Handles response from XMPPIDTracker
        let iqHandler = { (_ obj: Any, _ info: XMPPTrackingInfo) in
            guard let responseIq = obj as? XMPPIQ,
                let iqType = responseIq.iqType,
                iqType == .result else {
                    completionHandler(false, obj as? XMPPIQ)
                    return
            }
            completionHandler(true, responseIq)
        }
        performBlock(async: true) {
            self.tracker?.add(set, block: iqHandler, timeout: 30.0)
            self.xmppStream?.send(set)
        }
    }
    
    // MARK: - Private Methods
    
    /// Merges bookmarks allowing only one unique value of conference.jid or url.url
    /// overwriting the contents of original with new values if there is collision
    private func merge(original: [XMPPBookmark], adding: [XMPPBookmark], removing: [XMPPBookmark]) -> [XMPPBookmark] {
        var bookmarksDict: [String:XMPPBookmark] = [:]
        
        let keyForBookmark = { (_ bookmark: XMPPBookmark) -> String? in
            if let conference = bookmark as? XMPPConferenceBookmark,
                let jidString = conference.jid?.full {
                return jidString
            } else if let url = bookmark as? XMPPURLBookmark,
                let urlString = url.url?.absoluteString {
                return urlString
            }
            return nil
        }
        
        let mergeBookmark = { (_ bookmark: XMPPBookmark) in
            if let key = keyForBookmark(bookmark) {
                bookmarksDict[key] = bookmark
            }
        }
        
        original.forEach(mergeBookmark)
        adding.forEach(mergeBookmark)
        removing.forEach { (bookmark) in
            if let key = keyForBookmark(bookmark) {
                bookmarksDict.removeValue(forKey: key)
            }
        }
        
        let merged = [XMPPBookmark](bookmarksDict.values)
        return merged
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

/// This is required for the Swift invoke helper forced downcast.
extension GCDMulticastDelegate: XMPPBookmarksDelegate {}

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
