//
//  XMPPStreamTest.m
//  XMPPFrameworkTests
//
//  Created by Andres Canal on 5/26/16.
//
//

#import "XMPPMockStream.h"

@implementation XMPPMockStream

- (id) init {
    if (self = [super init]) {
        [super setValue:@(STATE_XMPP_CONNECTED) forKey:@"state"];
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

- (void)sendElement:(XMPPElement *)element {
    [super sendElement:element];
	if(self.elementReceived) {
		self.elementReceived(element);
	}
}

@end
