//
//  XMPPMessage+XEP0045.h
//  talk
//
//  Created by Eric Chamberlain on 9/20/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "XMPPMessage.h"

@interface XMPPMessage(XEP0045)

- (BOOL)isGroupChatMessage;
- (BOOL)isGroupChatMessageWithBody;

@end
