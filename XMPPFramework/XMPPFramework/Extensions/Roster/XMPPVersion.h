//
//  XMPPVersion.h
//  SMSPlus
//
//  Created by admin on 11-02-05.
//  Copyright 2011 Baseva Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "XMPPModule.h"

@class XMPPJID;
@class XMPPStream;
@class XMPPIQ;

@protocol XMPPVersionDelegate;

@interface XMPPVersion : XMPPModule {
	
}

- (id)initWithXMPPStream:(XMPPStream *)xmppStream;

@end

@protocol XMPPVersionDelegate
@optional

- (void)xmppVersion:(XMPPVersion *)sender didReceiveVersion:(XMPPIQ *)version;

@end
