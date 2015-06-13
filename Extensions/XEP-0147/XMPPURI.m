//
//  XMPPURI.m
//  XMPPFramework
//
//  Created by Christopher Ballinger on 5/15/15.
//  Copyright (c) 2015 Chris Ballinger. All rights reserved.
//

#import "XMPPURI.h"

@implementation XMPPURI

- (instancetype) initWithURIString:(NSString *)uriString {
    if (self = [super init]) {
        [self parseURIString:uriString];
    }
    return self;
}

- (instancetype) initWithURL:(NSURL *)url {
    if (self = [self initWithURIString:url.absoluteString]) {
    }
    return self;
}

- (instancetype) initWithJID:(XMPPJID*)jid
                 queryAction:(NSString*)queryAction
             queryParameters:(NSDictionary*)queryParameters {
    if (self = [super init]) {
        _jid = [jid copy];
        _queryAction = [queryAction copy];
        _queryParameters = [queryParameters copy];
    }
    return self;
}

- (NSString*) uriString {
    NSMutableString *uriString = [NSMutableString stringWithFormat:@"xmpp:%@", self.jid.bare];
    if (self.queryAction) {
        [uriString appendFormat:@"?%@", self.queryAction];
    }
    NSMutableCharacterSet *allowedCharacterSet = NSCharacterSet.URLQueryAllowedCharacterSet.mutableCopy;
    [allowedCharacterSet removeCharactersInString:@"'"]; // what other characters should be removed?
    [self.queryParameters enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
        NSString *value = [obj stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacterSet];
        [uriString appendFormat:@";%@=%@", key, value];
    }];
    return uriString;
}

- (void) parseURIString:(NSString*)uriString {
    NSString *authority = nil;
    // Parse authority component
    if ([uriString containsString:@"://"]) {
        NSRange fullRange = NSMakeRange(0, uriString.length);
        NSRange startRange = [uriString rangeOfString:@"://"];
        NSUInteger trailingLocation = startRange.location + startRange.length;
        NSRange trailingRange = NSMakeRange(trailingLocation, uriString.length - trailingLocation);
        NSRange endRange = [uriString rangeOfString:@"/" options:0 range:trailingRange];
        NSUInteger authorityLocation = startRange.location + startRange.length;
        NSRange authorityRange = NSMakeRange(authorityLocation, endRange.location - authorityLocation);
        authority = [uriString substringWithRange:authorityRange];
        NSString *stringToRemove = [NSString stringWithFormat:@"://%@/", authority];
        uriString = [uriString stringByReplacingOccurrencesOfString:stringToRemove withString:@":" options:0 range:fullRange];
    }
    if (authority) {
        _accountJID = [XMPPJID jidWithString:authority];
    }
    
    NSArray *uriComponents = [uriString componentsSeparatedByString:@":"];
    NSString *scheme = nil;
    NSString *jidString = nil;
    
    if (uriComponents.count >= 2) {
        scheme = uriComponents[0];
        NSString *path = uriComponents[1];
        if ([path containsString:@"?"]) {
            NSArray *queryComponents = [path componentsSeparatedByString:@"?"];
            jidString = queryComponents[0];
            NSString *query = queryComponents[1];
            NSArray *queryKeys = [query componentsSeparatedByString:@";"];
            
            NSMutableDictionary *queryParameters = [NSMutableDictionary dictionaryWithCapacity:queryKeys.count];
            [queryKeys enumerateObjectsUsingBlock:^(NSString *queryItem, NSUInteger idx, BOOL *stop) {
                if (idx == 0) {
                    _queryAction = queryItem;
                } else {
                    NSArray *keyValue = [queryItem componentsSeparatedByString:@"="];
                    if (keyValue.count == 2) {
                        NSString *key = keyValue[0];
                        NSString *value = [keyValue[1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                        if (key && value) {
                            queryParameters[key] = value;
                        }
                    }
                }
            }];
            _queryParameters = queryParameters;
        } else {
            jidString = path;
        }
    }
    if (jidString) {
        _jid = [XMPPJID jidWithString:jidString];
    }
}

@end
