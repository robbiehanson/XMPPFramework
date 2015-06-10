//
//  XMPPURITests.m
//  ChatSecure
//
//  Created by Christopher Ballinger on 6/9/15.
//  Copyright (c) 2015 Chris Ballinger. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "XMPPURI.h"

@interface XMPPURITests : XCTestCase

@end

@implementation XMPPURITests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}


- (void) testXMPPURI {
    XMPPJID *jid = [XMPPJID jidWithString:@"romeo@montague.net"];
    NSString *queryAction = @"message";
    NSDictionary *queryParameters = @{@"subject": @"Test Message",
                                      @"body": @"Here's a test message"};
    XMPPURI *uriGeneration = [[XMPPURI alloc] initWithJID:jid queryAction:queryAction queryParameters:queryParameters];
    
    NSString *uriString = [uriGeneration uriString];
    NSURL *url = [NSURL URLWithString:uriString];
    
    XMPPURI *uriParsing = [[XMPPURI alloc] initWithURL:url];
    
    XCTAssertEqualObjects(jid.bare, uriParsing.jid.bare);
    XCTAssertEqualObjects(queryAction, uriParsing.queryAction);
    XCTAssertEqualObjects(queryParameters, uriParsing.queryParameters);
}

- (void) testSubscribeWithOTR {
    XMPPJID *jid = [XMPPJID jidWithString:@"romeo@montague.net"];
    NSString *queryAction = @"subscribe";
    NSString *fingerprint = @"8FBB10D4A2B73FAE935FF3AEBA5EFFE29A98966F";
    NSString *fingerprintKey = @"otr-fingerprint";
    NSDictionary *queryParameters = @{fingerprintKey: fingerprint};
    XMPPURI *uriGeneration = [[XMPPURI alloc] initWithJID:jid queryAction:queryAction queryParameters:queryParameters];
    
    NSString *uriString = [uriGeneration uriString];
    NSURL *url = [NSURL URLWithString:uriString];
    
    XMPPURI *uriParsing = [[XMPPURI alloc] initWithURL:url];
    
    XCTAssertEqualObjects(jid.bare, uriParsing.jid.bare);
    XCTAssertEqualObjects(queryAction, uriParsing.queryAction);
    XCTAssertEqualObjects(queryParameters, uriParsing.queryParameters);
    XCTAssertEqualObjects(fingerprint, uriParsing.queryParameters[fingerprintKey]);
}

@end
