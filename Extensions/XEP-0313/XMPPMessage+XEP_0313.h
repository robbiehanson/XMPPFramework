//
//  XMPPMessage+XEP_0313.h
//  XEP-0313 Message Archive Management
//
//  Created by Arslan Pervaiz on 03/6/16.
//  Copyright 2016 Vopium A/S. All rights reserved.
//

#import "XMPPMessage.h"
#import "XMPPFramework.h"

@interface XMPPMessage (XEP_0313)

- (BOOL) hasForwardedMessage;
- (NSString *)getResult;
- (XMPPMessage *) getforwardedMessage;


@end
