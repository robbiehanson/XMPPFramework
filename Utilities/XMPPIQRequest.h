//
//  XMPPIQRequest.h
//  iPhoneXMPP
//
//  Created by studentdeng on 11-11-27.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XMPP.h"

@class XMPPIDTracker;

@interface XMPPIQRequest : XMPPModule {
    /**************************************
     * Inherited from XMPPModule:
     * 
     * 
     * dispatch_queue_t moduleQueue;
     * id multicastDelegate;
     ***************************************/
    
    XMPPIDTracker *xmppIDTracker;
    NSMutableDictionary *waitObjects;
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue;

- (XMPPIQ *)sendSyncEx:(XMPPIQ *)iq;

@end

@interface XMPPIQRequestPakage : NSObject
{
    XMPPIQ *iqReceive;
    XMPPElementReceipt *receipt;
}

@property (nonatomic, retain) XMPPIQ *iqReceive;
@property (nonatomic, retain) XMPPElementReceipt *receipt;

@end