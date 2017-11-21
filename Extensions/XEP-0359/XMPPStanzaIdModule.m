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
#import "XMPPRoom.h"

@implementation XMPPStanzaIdModule
// MARK: Setup
@synthesize autoAddOriginId = _autoAddOriginId;
@synthesize copyElementIdIfPresent = _copyElementIdIfPresent;
@synthesize filterBlock = _filterBlock;

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

- (void) setFilterBlock:(BOOL (^)(XMPPStream *stream, XMPPMessage* message))filterBlock {
    [self performBlockAsync:^{
        _filterBlock = [filterBlock copy];
    }];
}

- (BOOL (^)(XMPPStream *stream, XMPPMessage* message))filterBlock {
    __block BOOL (^filterBlock)(XMPPStream *stream, XMPPMessage* message) = nil;
    [self performBlock:^{
        filterBlock = _filterBlock;
    }];
    return filterBlock;
}

/** Returning YES means message is omitted from further processing */
- (BOOL) shouldFilterMessage:(XMPPMessage*)message {
    // Attaching origin-id to MUC invite elements is rejected by some servers
    // Possibly other stanzas as well
    NSXMLElement *mucUserElement = [message elementForName:@"x" xmlns:XMPPMUCUserNamespace];
    if ([mucUserElement elementForName:@"invite"]) {
        return YES;
    }
    return NO;
}

// MARK: XMPPStreamDelegate

- (nullable XMPPMessage *)xmppStream:(XMPPStream *)sender willSendMessage:(XMPPMessage *)message {
    // Do not add originId if already present,
    // or if autoAddOriginId is disabled
    if (message.originId.length ||
        !self.autoAddOriginId) {
        return message;
    }
    
    // Filter out message types known not to work with origin-id
    if ([self shouldFilterMessage:message]) {
        return message;
    }
    
    // User-filtering of messages
    BOOL (^filterBlock)(XMPPStream *stream, XMPPMessage* message) = self.filterBlock;
    if (filterBlock && !filterBlock(sender, message)) {
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
