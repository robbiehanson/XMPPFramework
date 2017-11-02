//
//  XMPPStreamTest.m
//  XMPPFrameworkTests
//
//  Created by Andres Canal on 5/26/16.
//
//

#import "XMPPMockStream.h"

@interface XMPPElementEvent (PrivateAPI)

@property (nonatomic, assign, readwrite, getter=isProcessingCompleted) BOOL processingCompleted;

- (instancetype)initWithStream:(XMPPStream *)xmppStream uniqueID:(NSString *)uniqueID myJID:(XMPPJID *)myJID timestamp:(NSDate *)timestamp;

@end

@implementation XMPPMockStream

- (id) init {
    if (self = [super init]) {
        [super setValue:@(STATE_XMPP_CONNECTED) forKey:@"state"];
        [super setValue:[XMPPJID jidWithString:@"user@domain/resource"] forKey:@"myJID"];
    }
    return self;
}

- (BOOL) isAuthenticated {
    return YES;
}

- (void)fakeResponse:(NSXMLElement*)element {
    [self injectElement:element];
}

- (void)fakeMessageResponse:(XMPPMessage *) message {
    [self injectElement:message];
}

- (void)fakeIQResponse:(XMPPIQ *) iq {
    [self injectElement:iq];
}

- (void)fakeCurrentEventWithID:(NSString *)fakeEventID timestamp:(NSDate *)fakeEventTimestamp forActionWithBlock:(dispatch_block_t)block
{
    XMPPElementEvent *fakeEvent = [[XMPPElementEvent alloc] initWithStream:self uniqueID:fakeEventID myJID:self.myJID timestamp:fakeEventTimestamp];
    GCDMulticastDelegateInvocationContext *fakeInvocationContext = [[GCDMulticastDelegateInvocationContext alloc] initWithValue:fakeEvent];
    
    [fakeInvocationContext becomeCurrentOnQueue:self.xmppQueue forActionWithBlock:block];
    
    dispatch_group_notify(fakeInvocationContext.continuityGroup, self.xmppQueue, ^{
        fakeEvent.processingCompleted = YES;
        [[self valueForKey:@"multicastDelegate"] xmppStream:self didFinishProcessingElementEvent:fakeEvent];
    });
}

- (void)sendElement:(XMPPElement *)element {
    [super sendElement:element];
	if(self.elementReceived) {
		self.elementReceived(element);
	}
}

@end
