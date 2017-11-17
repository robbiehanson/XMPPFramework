//
//  NSXMLElement+XEP_0048.h
//  XMPPFramework
//
//  Created by Chris Ballinger on 11/10/17.
//  Copyright © 2017 Chris Ballinger. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XMPPJID.h"
#import "XMPPElement.h"

NS_ASSUME_NONNULL_BEGIN

@class XMPPConferenceBookmark, XMPPURLBookmark, XMPPBookmarksStorageElement;
@protocol XMPPBookmark;

/**
 * XEP-0048: Bookmarks
 *
 * This specification defines an XML data format for use by XMPP clients in storing bookmarks to mult-user chatrooms and web pages. The chatroom bookmarking function includes the ability to auto-join rooms on login.
 * https://xmpp.org/extensions/xep-0048.html
 */
@interface NSXMLElement (XEP_0048)

/** Extracts child element of type <storage xmlns='storage:bookmarks'> */
@property (nonatomic, readonly, nullable) XMPPBookmarksStorageElement *bookmarksStorageElement;

@end




/** XML Constants */
@interface XMPPBookmarkConstants : NSObject

/** "storage:bookmarks" */
@property (nonatomic, class, readonly) NSString *xmlns;

// MARK: Elements

/** "storage" */
@property (nonatomic, class, readonly) NSString *storageElement;
/** "conference" */
@property (nonatomic, class, readonly) NSString *conferenceElement;
/** "url" */
@property (nonatomic, class, readonly) NSString *urlElement;
/** "nick" */
@property (nonatomic, class, readonly) NSString *nickElement;
/** "password" */
@property (nonatomic, class, readonly) NSString *passwordElement;

// MARK: Attributes

/** "name" */
@property (nonatomic, class, readonly) NSString *nameAttribute;
/** "autojoin" */
@property (nonatomic, class, readonly) NSString *autojoinAttribute;
/** "jid" */
@property (nonatomic, class, readonly) NSString *jidAttribute;
/** "url" */
@property (nonatomic, class, readonly) NSString *urlAttribute;

- (instancetype) init NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
