//
//  XMPPBookmarksStorageElement.m
//  XMPPFramework
//
//  Created by Chris Ballinger on 11/12/17.
//  Copyright © 2017 robbiehanson. All rights reserved.
//

#import "XMPPBookmarksStorageElement.h"
#import "NSXMLElement+XEP_0048.h"
#import "NSXMLElement+XMPP.h"
#import "XMPPBookmark.h"
#import <objc/runtime.h>

#define let __auto_type const

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
            [self addChild:bookmark.element];
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
        id<XMPPBookmark> bookmark = [class bookmarkFromElement:bookmarkElement];
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
