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

- (id)initWithPut:(NSString *)put andGet:(NSString *)get {

	self = [super init];
	if(self) {
		_get = get;
		_put = put;
	}
	return self;

}

- (id)initWithIQ:(XMPPIQ *)iq {

	self = [super init];
	if(self) {
		NSXMLElement *slot = [iq elementForName:@"slot"];
		_put = [[slot elementForName:@"put"].stringValue copy];
		_get = [[slot elementForName:@"get"].stringValue copy];
	}
	return self;

}

@end
