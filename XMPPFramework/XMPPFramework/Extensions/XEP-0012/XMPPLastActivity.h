//
//  XMPPLastActivity.h
//  XMPPFramework
//
//  Created by Sean Batson on 12-07-01.
//  Copyright (c) 2012 Baseva, Inc. All rights reserved.
//

#import "XMPPModule.h"
@class XMPPJID;
@class XMPPStream;
@class XMPPIQ;
@class XMPPMessage;

@interface XMPPLastActivity : XMPPModule

- (void)requestWhenLastSeen:(XMPPJID *)jid;
@end

@protocol XMPPLastActivityDelegate <NSObject>

@optional
- (void)xmppLastSeen:(XMPPLastActivity*)sender didResponseWithLastSeenIQ:(XMPPIQ *)iq;
- (void)xmppLastSeen:(XMPPLastActivity*)sender didResponseWithLastSeenError:(XMPPIQ *)iq;
@end