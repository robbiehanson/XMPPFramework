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

- (instancetype)initWithPut:(NSString *)put andGet:(NSString *)get {
    NSParameterAssert(put != nil);
    NSParameterAssert(get != nil);
	self = [super init];
	if(self) {
		_get = [get copy];
		_put = [put copy];
	}
	return self;
}

- (nullable instancetype)initWithIQ:(XMPPIQ *)iq {
    NSParameterAssert(iq != nil);
    NSXMLElement *slot = [iq elementForName:@"slot"];
    NSString *put = [slot elementForName:@"put"].stringValue;
    NSString *get = [slot elementForName:@"get"].stringValue;
    if (!put || !get) {
        return nil;
    }
    return [self initWithPut:put andGet:get];
}

@end
