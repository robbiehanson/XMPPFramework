//
//  XMPPStreamTest.h
//  XMPPFrameworkTests
//
//  Created by Andres Canal on 5/26/16.
//
//

#import <XMPPFramework/XMPPFramework.h>

@interface XMPPMockStream : XMPPStream

- (void)fakeIQResponse:(XMPPIQ *) iq;
- (void)fakeMessageResponse:(XMPPMessage *) message;

@property (nonatomic, copy) void (^elementReceived)(XMPPElement *element);

@end
