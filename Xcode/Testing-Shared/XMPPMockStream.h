//
//  XMPPStreamTest.h
//  XMPPFrameworkTests
//
//  Created by Andres Canal on 5/26/16.
//
//

@import XMPPFramework;

NS_ASSUME_NONNULL_BEGIN
/**
 * This class is used so you can more easily test your XMPPModules
 * to mock responses to received elements.
 */
@interface XMPPMockStream : XMPPStream

// The below fakeResponse methods are all equivalent
// and simply call XMPPStream's internal injectElement: method

- (void)fakeResponse:(NSXMLElement*)element;
- (void)fakeIQResponse:(XMPPIQ *) iq;
- (void)fakeMessageResponse:(XMPPMessage *) message;

/** This is always called on XMPPStream's xmppQueue */
@property (nonatomic, copy, nullable) void (^elementReceived)(__kindof XMPPElement *element);

@end
NS_ASSUME_NONNULL_END
