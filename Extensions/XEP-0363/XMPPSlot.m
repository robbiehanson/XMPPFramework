//
//  XMPPSlot.m
//  Mangosta
//
//  Created by Andres Canal on 5/19/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

#import "XMPPSlot.h"
#import "NSXMLElement+XMPP.h"

@implementation XMPPSlot

- (instancetype) init {
    NSAssert(NO, @"Use designated initializer.");
    return nil;
}

- (instancetype)initWithPutURL:(NSURL *)putURL getURL:(NSURL *)getURL putHeaders:(nullable NSDictionary<NSString *,NSString *> *)putHeaders {
    NSParameterAssert(putURL != nil);
    NSParameterAssert(getURL != nil);
    if (self = [super init]) {
        _putURL = [putURL copy];
        _getURL = [getURL copy];
        if (putHeaders) {
            _putHeaders = [putHeaders copy];
        } else {
            _putHeaders = @{};
        }
    }
    return self;
}

- (nullable instancetype)initWithPut:(NSString *)put andGet:(NSString *)get {
    NSParameterAssert(put != nil);
    NSParameterAssert(get != nil);
    if (!put || !get) {
        return nil;
    }
    NSURL *putURL = [NSURL URLWithString:put];
    NSURL *getURL = [NSURL URLWithString:get];
    if (!putURL || !getURL) {
        return nil;
    }
    return [self initWithPutURL:putURL getURL:getURL putHeaders:@{}];
}

- (nullable instancetype)initWithIQ:(XMPPIQ *)iq {
    NSParameterAssert(iq != nil);
    NSXMLElement *slot = [iq elementForName:@"slot"];
    NSXMLElement *putElement = [slot elementForName:@"put"];
    NSXMLElement *getElement = [slot elementForName:@"get"];
    
    // Early versions of the spec didn't support headers
    // See https://xmpp.org/extensions/xep-0363.html
    NSString *putURLString = [putElement attributeStringValueForName:@"url"];
    if (!putURLString) {
        putURLString = putElement.stringValue;
    }
    NSString *getURLString = [getElement attributeStringValueForName:@"url"];
    if (!getURLString) {
        getURLString = getElement.stringValue;
    }
    
    if (!putURLString || !getURLString) {
        return nil;
    }
    NSURL *putURL = [NSURL URLWithString:putURLString];
    NSURL *getURL = [NSURL URLWithString:getURLString];
    if (!putURL || !getURL) {
        return nil;
    }
    NSArray <NSXMLElement*> *headers = [putElement elementsForName:@"header"];
    NSMutableDictionary<NSString*,NSString*> *putHeaders = [NSMutableDictionary dictionaryWithCapacity:headers.count];
    [headers enumerateObjectsUsingBlock:^(NSXMLElement * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *name = [obj attributeStringValueForName:@"name"];
        NSString *value = obj.stringValue;
        if (name && value) {
            [putHeaders setObject:value forKey:name];
        }
    }];
    return [self initWithPutURL:putURL getURL:getURL putHeaders:putHeaders];
}

- (NSURLRequest*) putRequest {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.putURL];
    request.HTTPMethod = @"PUT";
    [request setAllHTTPHeaderFields:self.putHeaders];
    return request;
}

- (NSString*) put {
    return self.putURL.absoluteString;
}

- (NSString*) get {
    return self.getURL.absoluteString;
}

@end
