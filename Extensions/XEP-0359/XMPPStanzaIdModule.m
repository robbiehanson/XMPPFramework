//
//  XMPPStanzaIdModule.m
//  XMPPFramework
//
//  Created by Chris Ballinger on 10/14/17.
//  Copyright © 2017 Chris Ballinger. All rights reserved.
//

#import "XMPPStanzaIdModule.h"
#import "XMPPMessage.h"
#import "XMPPMessage+XEP_0359.h"

@implementation XMPPStanzaIdModule
// MARK: Setup
@synthesize autoAddOriginId = _autoAddOriginId;
@synthesize copyElementIdIfPresent = _copyElementIdIfPresent;

- (instancetype) initWithDispatchQueue:(dispatch_queue_t)queue {
    if (self = [super initWithDispatchQueue:queue]) {
        _autoAddOriginId = YES;
        _copyElementIdIfPresent = YES;
    }
    return self;
}

// MARK: Properties

- (void) setAutoAddOriginId:(BOOL)autoAddOriginId {
    [self performBlockAsync:^{
        _autoAddOriginId = autoAddOriginId;
    }];
}

- (BOOL) autoAddOriginId {
    __block BOOL autoAddOriginId = NO;
    [self performBlock:^{
        autoAddOriginId = _autoAddOriginId;
    }];
    return autoAddOriginId;
}

- (BOOL) copyElementIdIfPresent {
    __block BOOL copyElementIdIfPresent = NO;
    [self performBlock:^{
        copyElementIdIfPresent = _copyElementIdIfPresent;
    }];
    return copyElementIdIfPresent;
}

- (void) setCopyElementIdIfPresent:(BOOL)copyElementIdIfPresent {
    [self performBlockAsync:^{
        _copyElementIdIfPresent = copyElementIdIfPresent;
    }];
}

// MARK: XMPPStreamDelegate

- (nullable XMPPMessage *)xmppStream:(XMPPStream *)sender willSendMessage:(XMPPMessage *)message {
    // Do not add originId if already present,
    // or if autoAddOriginId is disabled
    if (message.originId.length ||
        !self.autoAddOriginId) {
        return message;
    }
    NSString *originId = [NSUUID UUID].UUIDString;
    
    // Copy existing elementId if desired,
    // otherwise use the new UUID
    NSString *elementId = message.elementID;
    if (elementId.length &&
        self.copyElementIdIfPresent) {
        originId = elementId;
    }
    
    [message addOriginId:originId];
    
    [self performBlockAsync:^{
        [multicastDelegate stanzaIdModule:self didAddOriginId:originId toMessage:message];
    }];
    
    return message;
}

@end
