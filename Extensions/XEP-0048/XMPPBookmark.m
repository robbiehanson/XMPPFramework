//
//  XMPPBookmark.m
//  XMPPFramework
//
//  Created by Chris Ballinger on 11/12/17.
//  Copyright © 2017 robbiehanson. All rights reserved.
//

#import "XMPPBookmark.h"
#import "NSXMLElement+XEP_0048.h"
#import "NSXMLElement+XMPP.h"
#import <objc/runtime.h>

@implementation XMPPConferenceBookmark

// MARK: Init

- (instancetype) initWithJID:(XMPPJID*)jid {
    return [self initWithJID:jid bookmarkName:nil nick:nil autoJoin:NO password:nil];
}

- (instancetype) initWithJID:(XMPPJID*)jid
                bookmarkName:(nullable NSString*)bookmarkName
                        nick:(nullable NSString*)nick
                    autoJoin:(BOOL)autoJoin {
    return [self initWithJID:jid bookmarkName:bookmarkName nick:nick autoJoin:autoJoin password:nil];
}

- (instancetype) initWithJID:(XMPPJID*)jid
                bookmarkName:(nullable NSString*)bookmarkName
                        nick:(nullable NSString*)nick
                    autoJoin:(BOOL)autoJoin
                    password:(nullable NSString*)password {
    if (self = [super initWithName:self.class.elementName]) {
        [self addAttributeWithName:XMPPBookmarkConstants.jidAttribute stringValue:jid.bare];
        
        if (bookmarkName.length) {
            [self addAttributeWithName:XMPPBookmarkConstants.nameAttribute stringValue:bookmarkName];
        }
        [self addAttributeWithName:XMPPBookmarkConstants.autojoinAttribute boolValue:autoJoin];
        
        if (nick.length) {
            NSXMLElement *nickElement = [NSXMLElement elementWithName:XMPPBookmarkConstants.nickElement stringValue:nick];
            [self addChild:nickElement];
        }
        if (password.length) {
            NSXMLElement *passwordElement = [NSXMLElement elementWithName:XMPPBookmarkConstants.passwordElement stringValue:password];
            [self addChild:passwordElement];
        }
    }
    return self;
}

// MARK: Properties

- (XMPPJID*) jid {
    NSString *jidString = [self attributeStringValueForName:XMPPBookmarkConstants.jidAttribute];
    if (!jidString) { return nil; }
    return [XMPPJID jidWithString:jidString];
}

- (BOOL) autoJoin {
    return [self attributeBoolValueForName:XMPPBookmarkConstants.autojoinAttribute withDefaultValue:NO];
}

- (NSString*) nick {
    return [self elementForName:XMPPBookmarkConstants.nickElement].stringValue;
}

- (NSString*) password {
    return [self elementForName:XMPPBookmarkConstants.passwordElement].stringValue;
}

// MARK: XMPPBookmark

+ (nullable instancetype) bookmarkFromElement:(NSXMLElement*)element {
    if (![element.name isEqualToString:self.class.elementName]) {
        return nil;
    }
    object_setClass(element, self.class);
    return (id)element;
}

- (NSString*) bookmarkName {
    return [self attributeStringValueForName:XMPPBookmarkConstants.nameAttribute];
}

+ (NSString*) elementName {
    return XMPPBookmarkConstants.conferenceElement;
}

- (NSXMLElement*) element {
    return self;
}

@end

@implementation XMPPURLBookmark

// MARK: Init

- (instancetype) initWithURL:(NSURL*)url {
    return [self initWithURL:url bookmarkName:nil];
}

- (instancetype) initWithURL:(NSURL*)url
                bookmarkName:(nullable NSString*)bookmarkName {
    if (self = [super initWithName:self.class.elementName]) {
        if (bookmarkName.length) {
            [self addAttributeWithName:XMPPBookmarkConstants.nameAttribute stringValue:bookmarkName];
        }
        [self addAttributeWithName:XMPPBookmarkConstants.urlAttribute stringValue:url.absoluteString];
    }
    return self;
}

// MARK: Properties

- (NSURL*) url {
    NSString *urlString = [self attributeStringValueForName:XMPPBookmarkConstants.urlAttribute];
    if (!urlString) { return nil; }
    NSURL *url = [NSURL URLWithString:urlString];
    return url;
}

// MARK: XMPPBookmark

+ (nullable instancetype) bookmarkFromElement:(NSXMLElement*)element {
    if (![element.name isEqualToString:self.class.elementName]) {
        return nil;
    }
    object_setClass(element, self.class);
    return (id)element;
}

- (NSString*) bookmarkName {
    return [self attributeStringValueForName:XMPPBookmarkConstants.nameAttribute];
}

+ (NSString*) elementName {
    return XMPPBookmarkConstants.urlElement;
}

- (NSXMLElement*) element {
    return self;
}

@end

