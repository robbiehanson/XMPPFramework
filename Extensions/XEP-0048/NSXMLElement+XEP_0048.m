//
//  NSXMLElement+XEP_0048.m
//  XMPPFramework
//
//  Created by Chris Ballinger on 11/10/17.
//  Copyright © 2017 Chris Ballinger. All rights reserved.
//

#import "NSXMLElement+XEP_0048.h"
#import "NSXMLElement+XMPP.h"
#import <objc/runtime.h>

#define let __auto_type const

@implementation NSXMLElement (XEP_0048)

- (XMPPBookmarksStorageElement*) bookmarksStorageElement {
    NSXMLElement *element = [NSXMLElement elementWithName:XMPPBookmarkConstants.storageElement xmlns:XMPPBookmarkConstants.xmlns];
    return [XMPPBookmarksStorageElement bookmarksStorageElementFromElement:element];
}
@end

@implementation XMPPBookmarksStorageElement

+ (nullable XMPPBookmarksStorageElement*)bookmarksStorageElementFromElement:(NSXMLElement*)element {
    NSParameterAssert(element);
    if (!element ||
        ![element.name isEqualToString:XMPPBookmarkConstants.storageElement] ||
        ![element.xmlns isEqualToString:XMPPBookmarkConstants.xmlns]) {
        return nil;
    }
    object_setClass(element, XMPPBookmarksStorageElement.class);
    return (XMPPBookmarksStorageElement*)element;
}

- (instancetype) initWithBookmarks:(NSArray<id<XMPPBookmark>>*)bookmarks {
    if (self = [super initWithName:XMPPBookmarkConstants.storageElement xmlns:XMPPBookmarkConstants.xmlns]) {
        [bookmarks enumerateObjectsUsingBlock:^(id<XMPPBookmark> _Nonnull bookmark, NSUInteger idx, BOOL * _Nonnull stop) {
            NSXMLElement *bookmarkElement = bookmark.bookmarkElement;
            [self addChild:bookmarkElement];
        }];
    }
    return self;
}

- (NSArray<id<XMPPBookmark>>*)bookmarks {
    let conferences = self.conferenceBookmarks;
    let urls = self.urlBookmarks;
    NSMutableArray<id<XMPPBookmark>> *bookmarks = [NSMutableArray arrayWithCapacity:conferences.count + urls.count];
    [bookmarks addObjectsFromArray:conferences];
    [bookmarks addObjectsFromArray:urls];
    return bookmarks;
}


- (NSArray<__kindof id<XMPPBookmark>>*)bookmarksWithElementName:(NSString*)elementName class:(Class)class {
    NSArray<NSXMLElement*> *bookmarkElements = [self elementsForName:elementName];
    NSMutableArray<id<XMPPBookmark>> *bookmarks = [[NSMutableArray alloc] initWithCapacity:bookmarkElements.count];
    [bookmarkElements enumerateObjectsUsingBlock:^(NSXMLElement * _Nonnull bookmarkElement, NSUInteger idx, BOOL * _Nonnull stop) {
        id<XMPPBookmark> bookmark = [[class alloc] initWithBookmarkElement:bookmarkElement];
        if (bookmark) {
            [bookmarks addObject:bookmark];
        }
    }];
    return bookmarks;
}

- (NSArray<XMPPConferenceBookmark*>*)conferenceBookmarks {
    return [self bookmarksWithElementName:XMPPConferenceBookmark.elementName class:XMPPConferenceBookmark.class];
}

- (NSArray<XMPPURLBookmark*>*)urlBookmarks {
    return [self bookmarksWithElementName:XMPPURLBookmark.elementName class:XMPPURLBookmark.class];
}

@end


@implementation XMPPConferenceBookmark
@synthesize name = _name;

- (instancetype) initWithJID:(XMPPJID*)jid {
    return [self initWithJID:jid name:nil nick:nil autoJoin:NO password:nil];
}

- (instancetype) initWithJID:(XMPPJID*)jid
                        name:(nullable NSString*)name
                        nick:(nullable NSString*)nick
                    autoJoin:(BOOL)autoJoin {
    return [self initWithJID:jid name:name nick:nick autoJoin:autoJoin password:nil];
}

- (instancetype) initWithJID:(XMPPJID*)jid
                        name:(nullable NSString*)name
                        nick:(nullable NSString*)nick
                    autoJoin:(BOOL)autoJoin
                    password:(nullable NSString*)password {
    if (self = [super init]) {
        _jid = jid;
        _name = [name copy];
        _nick = [nick copy];
        _autoJoin = autoJoin;
        _password = [password copy];
    }
    return self;
}

- (nullable instancetype) initWithBookmarkElement:(NSXMLElement*)bookmarkElement {
    NSParameterAssert(bookmarkElement);
    if (!bookmarkElement) { return nil; }
    if (![bookmarkElement.name isEqualToString:self.class.elementName]) {
        return nil;
    }
    NSString *jidString = [bookmarkElement attributeStringValueForName:XMPPBookmarkConstants.jidAttribute];
    if (!jidString.length) {
        return nil;
    }
    XMPPJID *jid = [XMPPJID jidWithString:jidString];
    if (!jid) {
        return nil;
    }
    BOOL autojoin = [bookmarkElement attributeBoolValueForName:XMPPBookmarkConstants.autojoinAttribute withDefaultValue:NO];
    NSString *name = [bookmarkElement attributeStringValueForName:XMPPBookmarkConstants.nameAttribute];
    
    NSString *nick = [bookmarkElement elementForName:XMPPBookmarkConstants.nickElement].stringValue;
    NSString *password = [bookmarkElement elementForName:XMPPBookmarkConstants.passwordElement].stringValue;
    return [self initWithJID:jid name:name nick:nick autoJoin:autojoin password:password];
}

- (NSXMLElement*) bookmarkElement {
    NSXMLElement *conference = [NSXMLElement elementWithName:self.class.elementName];
    
    [conference addAttributeWithName:XMPPBookmarkConstants.jidAttribute stringValue:self.jid.bare];
    
    if (self.name.length) {
        [conference addAttributeWithName:XMPPBookmarkConstants.nameAttribute stringValue:self.name];
    }
    [conference addAttributeWithName:XMPPBookmarkConstants.autojoinAttribute boolValue:self.autoJoin];
    
    if (self.nick.length) {
        NSXMLElement *nick = [NSXMLElement elementWithName:XMPPBookmarkConstants.nickElement stringValue:self.nick];
        [conference addChild:nick];
    }
    if (self.password.length) {
        NSXMLElement *password = [NSXMLElement elementWithName:XMPPBookmarkConstants.passwordElement stringValue:self.password];
        [conference addChild:password];
    }
    
    return conference;
}

+ (NSString*) elementName {
    return XMPPBookmarkConstants.conferenceElement;
}

@end

@implementation XMPPURLBookmark
@synthesize name = _name;

- (instancetype) initWithURL:(NSURL*)url {
    return [self initWithURL:url name:nil];
}

- (instancetype) initWithURL:(NSURL*)url
                        name:(nullable NSString*)name {
    if (self = [super init]) {
        _url = [url copy];
        _name = [name copy];
    }
    return self;
}

- (nullable instancetype) initWithBookmarkElement:(NSXMLElement*)bookmarkElement {
    NSParameterAssert(bookmarkElement);
    if (!bookmarkElement) { return nil; }
    if (![bookmarkElement.name isEqualToString:self.class.elementName]) {
        return nil;
    }
    NSString *urlString = [bookmarkElement attributeStringValueForName:XMPPBookmarkConstants.urlAttribute];
    if (!urlString) { return nil; }
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) { return nil; }
    
    NSString *name = [bookmarkElement attributeStringValueForName:XMPPBookmarkConstants.nameAttribute];
    return [self initWithURL:url name:name];
}

- (NSXMLElement*)bookmarkElement {
    NSXMLElement *urlElement = [NSXMLElement elementWithName:self.class.elementName];
    if (self.name.length) {
        [urlElement addAttributeWithName:XMPPBookmarkConstants.nameAttribute stringValue:self.name];
    }
    [urlElement addAttributeWithName:XMPPBookmarkConstants.urlAttribute stringValue:self.url.absoluteString];
    return urlElement;
}

+ (NSString*) elementName {
    return XMPPBookmarkConstants.urlElement;
}

@end

@implementation XMPPBookmarkConstants
+ (NSString*) xmlns {
    return @"storage:bookmarks";
}
+ (NSString*) storageElement {
    return @"storage";
}
+ (NSString*) conferenceElement {
    return @"conference";
}
+ (NSString*) urlElement {
    return @"url";
}
+ (NSString*) urlAttribute {
    return @"url";
}
+ (NSString*) passwordElement {
    return @"password";
}
+ (NSString*) nickElement {
    return @"nick";
}
+ (NSString*) nameAttribute {
    return @"name";
}
+ (NSString*) autojoinAttribute {
    return @"autojoin";
}
+ (NSString*) jidAttribute {
    return @"jid";
}
@end
