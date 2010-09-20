//
//  XMPPMessage+XEP0045.h
//
//  Created by Eric Chamberlain on 9/20/10.
//  Copyright 2010 RF.com. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "XMPPMessage.h"

@interface XMPPMessage(XEP0045)

- (BOOL)isGroupChatMessage;
- (BOOL)isGroupChatMessageWithBody;

@end
