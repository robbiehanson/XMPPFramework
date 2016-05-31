//
//  XMPPStreamTest.m
//  XMPPFrameworkTests
//
//  Created by Andres Canal on 5/26/16.
//
//

#import "XMPPMockStream.h"

@implementation XMPPMockStream

- (void)fakeMessageResponse:(XMPPMessage *) message {
	[((id<XMPPStreamDelegate>)self.delegate) xmppStream:self didReceiveMessage:message];
}

- (void)fakeIQResponse:(XMPPIQ *) iq {
	[((id<XMPPStreamDelegate>)self.delegate) xmppStream:self didReceiveIQ:iq];
}

- (void)addDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue{
	[super addDelegate:delegate delegateQueue:delegateQueue];
	self.delegate = delegate;
}

- (void)sendElement:(NSXMLElement *)element {
	if(self.elementReceived) {
		self.elementReceived(element);
	}
}

@end