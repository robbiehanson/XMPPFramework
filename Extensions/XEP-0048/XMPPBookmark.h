//
//  XMPPBookmark.h
//  XMPPFramework
//
//  Created by Chris Ballinger on 11/12/17.
//  Copyright © 2017 robbiehanson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XMPPJID.h"
#import "XMPPElement.h"

NS_ASSUME_NONNULL_BEGIN
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
NS_ASSUME_NONNULL_END
