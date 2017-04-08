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

- (instancetype)initWithPutURL:(NSURL *)putURL getURL:(NSURL *)getURL putHeaders:(nonnull NSDictionary<NSString *,NSString *> *)putHeaders {
    NSParameterAssert(putURL != nil);
    NSParameterAssert(getURL != nil);
    NSParameterAssert(putHeaders != nil);
    if (self = [super init]) {
        _putURL = [putURL copy];
        _getURL = [getURL copy];
        _putHeaders = [putHeaders copy];
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
    NSString *put = putElement.stringValue;
    NSString *get = [slot elementForName:@"get"].stringValue;
    if (!put || !get) {
        return nil;
    }
    NSURL *putURL = [NSURL URLWithString:put];
    NSURL *getURL = [NSURL URLWithString:get];
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
