//
//  XMPPBookmarksStorageElement.h
//  XMPPFramework
//
//  Created by Chris Ballinger on 11/12/17.
//  Copyright © 2017 robbiehanson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XMPPBookmark.h"

NS_ASSUME_NONNULL_BEGIN
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
NS_ASSUME_NONNULL_END
