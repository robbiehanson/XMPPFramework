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


/** <storage xmlns='storage:bookmarks'> */
@interface XMPPBookmarksStorageElement : NSXMLElement

/** Converts element in place */
+ (nullable XMPPBookmarksStorageElement*)bookmarksStorageElementFromElement:(NSXMLElement*)element;

/** Create new <storage xmlns='storage:bookmarks'> element from bookmarks */
- (instancetype) initWithBookmarks:(NSArray<id<XMPPBookmark>>*)bookmarks;

@property (nonatomic, strong, readonly) NSArray<id<XMPPBookmark>> *bookmarks;
@property (nonatomic, strong, readonly) NSArray<XMPPConferenceBookmark*> *conferenceBookmarks;
@property (nonatomic, strong, readonly) NSArray<XMPPURLBookmark*> *urlBookmarks;

@end

@protocol XMPPBookmark <NSObject>
@required
/** A friendly name for the bookmark. */
@property (nonatomic, copy, readonly, nullable) NSString *name;
/** <conference> or <url> element representation */
@property (nonatomic, readonly) NSXMLElement *bookmarkElement;
/** Must be <conference> or <url> element */
- (nullable instancetype) initWithBookmarkElement:(NSXMLElement*)bookmarkElement;
/** Element name, either <conference> or <url> */
@property (nonatomic, class, readonly) NSString *elementName;
@end

@interface XMPPConferenceBookmark : NSObject <XMPPBookmark>
/** The JabberID of the chat room. */
@property (nonatomic, strong, readonly) XMPPJID *jid;
/** Whether the client should automatically join the conference room on login. */
@property (nonatomic, readonly) BOOL autoJoin;
/** The user's preferred roomnick for the chatroom. */
@property (nonatomic, copy, readonly, nullable) NSString *nick;
/** ⚠️ Unencrypted string for the password needed to enter a password-protected room. For security reasons, use of this element is NOT RECOMMENDED. */
@property (nonatomic, copy, readonly, nullable) NSString *password;

- (instancetype) init NS_UNAVAILABLE;
- (instancetype) initWithJID:(XMPPJID*)jid;
- (instancetype) initWithJID:(XMPPJID*)jid
                        name:(nullable NSString*)name
                        nick:(nullable NSString*)nick
                    autoJoin:(BOOL)autoJoin;

/** Using a password is NOT RECOMMENDED because it is stored on the server unencrypted. */
- (instancetype) initWithJID:(XMPPJID*)jid
                        name:(nullable NSString*)name
                        nick:(nullable NSString*)nick
                    autoJoin:(BOOL)autoJoin
                    password:(nullable NSString*)password NS_DESIGNATED_INITIALIZER;

@end

@interface XMPPURLBookmark: NSObject <XMPPBookmark>
/** The HTTP or HTTPS URL of the web page. */
@property (nonatomic, copy, readonly) NSURL *url;

- (instancetype) init NS_UNAVAILABLE;
- (instancetype) initWithURL:(NSURL*)url;
- (instancetype) initWithURL:(NSURL*)url
                        name:(nullable NSString*)name NS_DESIGNATED_INITIALIZER;
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
