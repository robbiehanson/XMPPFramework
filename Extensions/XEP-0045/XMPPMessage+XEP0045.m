//
//  XMPPMessage+XEP0045.m
//
//  Created by Eric Chamberlain on 9/20/10.
//  Copyright 2010 RF.com. All rights reserved.
//

#import "XMPPMessage+XEP0045.h"
#import "NSXMLElementAdditions.h"


@implementation XMPPMessage(XEP0045)

- (BOOL)isGroupChatMessage {
    return [[[self attributeForName:@"type"] stringValue] isEqualToString:@"groupchat"];
}

- (BOOL)isGroupChatMessageWithBody {
    if([self isGroupChatMessage]) {
        NSString *body = [[self elementForName:@"body"] stringValue];
        
        return ((body != nil) && ([body length] > 0));
    }
    
    return NO;
}

@end
