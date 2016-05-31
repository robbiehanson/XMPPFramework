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
    NSArray<NSValue*>* storageHints = [message storageHints];
    XCTAssertNotNil(storageHints);
    XCTAssertTrue(storageHints.count == 0);
    
    [message addStorageHint:XMPPMessageStorageNoCopy];
    [message addStorageHint:XMPPMessageStorageNoPermanentStore];
    [message addStorageHint:XMPPMessageStorageNoStore];
    [message addStorageHint:XMPPMessageStorageStore];
    // Should not be added
    [message addStorageHint:XMPPMessageStorageUnknown];
    storageHints = [message storageHints];
    XCTAssertNotNil(storageHints);
    XCTAssertTrue(storageHints.count == 4);
    
    BOOL result = [storageHints containsObject:@(XMPPMessageStorageNoCopy)];
    XCTAssertTrue(result);
    result = [storageHints containsObject:@(XMPPMessageStorageNoPermanentStore)];
    XCTAssertTrue(result);
    result = [storageHints containsObject:@(XMPPMessageStorageNoStore)];
    XCTAssertTrue(result);
    result = [storageHints containsObject:@(XMPPMessageStorageStore)];
    XCTAssertTrue(result);
    result = [storageHints containsObject:@(XMPPMessageStorageUnknown)];
    XCTAssertFalse(result);
}

@end
