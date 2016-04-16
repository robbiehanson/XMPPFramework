//
//  XMPPStorageHintTests.m
//  XMPPFrameworkTests
//
//  Created by Chris Ballinger on 4/16/16.
//
//

#import <XCTest/XCTest.h>
@import XMPPFramework;

@interface XMPPStorageHintTests : XCTestCase

@end

@implementation XMPPStorageHintTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testStorageElements {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    XMPPMessage *message = [[XMPPMessage alloc] init];
    XMPPMessageStorage storage = [message storageHint];
    XCTAssertTrue(storage == XMPPMessageStorageUndefined);
    [message setStorageHint:XMPPMessageStorageStore];
    storage = [message storageHint];
    XCTAssertTrue(storage == XMPPMessageStorageStore);
}

@end
