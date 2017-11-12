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

