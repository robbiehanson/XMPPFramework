//
//  XMPPRoomLightTests.m
//  XMPPFrameworkTests
//
//  Created by Andres Canal on 5/31/16.
//
//

#import <XCTest/XCTest.h>
#import "XMPPMockStream.h"
#import "XMPPRoomLight.h"
#import "XMPPJID.h"

@interface XMPPRoomLightTests : XCTestCase

@property (nonatomic, strong) XCTestExpectation *delegateResponseExpectation;

@end

@implementation XMPPRoomLightTests

- (void)testInitWithDomain {
	XMPPRoomLight *roomLight = [[XMPPRoomLight alloc] initWithDomain:@"test-domain.com"];
	XCTAssertEqualObjects(roomLight.domain, @"test-domain.com");
}

- (void)testInitWithJIDAndRoomname {
	XMPPJID *jid = [XMPPJID jidWithUser:@"user" domain:@"domain.com" resource:@"resource"];
	XMPPRoomLight *roomLight = [[XMPPRoomLight alloc] initWithJID:jid roomname:@"room"];
	XCTAssertEqualObjects(roomLight.roomJID.full, @"user@domain.com/resource");
	XCTAssertEqualObjects(roomLight.roomname, @"room");
}

@end
