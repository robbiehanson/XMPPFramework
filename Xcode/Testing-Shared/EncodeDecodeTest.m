//
//  EncodeDecodeTest.m
//  XMPPFrameworkTests
//
//  Created by Paul Melnikow on 4/18/15.
//  Copyright (c) 2015 Paul Melnikow. All rights reserved.
//

#import <XCTest/XCTest.h>
@import XMPPFramework;

@interface EncodeDecodeTest : XCTestCase

@end

@implementation EncodeDecodeTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testCopy
{
    XMPPJID *jid1 = [XMPPJID jidWithString:@"user@domain.com/resource"];
    XMPPJID *jid2 = [jid1 copy];
    
    XCTAssert([jid1 isKindOfClass:[XMPPJID class]], @"A1");
    XCTAssert([jid2 isKindOfClass:[XMPPJID class]], @"A2");
    
    XMPPIQ *iq1 = [XMPPIQ iqWithType:@"get" to:jid1 elementID:@"abc123"];
    XMPPIQ *iq2 = [iq1 copy];
    
    XCTAssert([iq1 isKindOfClass:[XMPPIQ class]], @"B1");
    XCTAssert([iq2 isKindOfClass:[XMPPIQ class]], @"B2");
    
    XMPPMessage *message1 = [XMPPMessage messageWithType:@"chat" to:jid1];
    XMPPMessage *message2 = [message1 copy];
    
    XCTAssert([message1 isKindOfClass:[XMPPMessage class]], @"C1");
    XCTAssert([message2 isKindOfClass:[XMPPMessage class]], @"C2");
    
    XMPPPresence *presence1 = [XMPPPresence presenceWithType:@"subscribe" to:jid1];
    XMPPPresence *presence2 = [presence1 copy];
    
    XCTAssert([presence1 isKindOfClass:[XMPPPresence class]], @"D1");
    XCTAssert([presence2 isKindOfClass:[XMPPPresence class]], @"D2");
}

- (void)testArchive
{
    NSMutableDictionary *dict1 = [NSMutableDictionary dictionaryWithCapacity:4];
    
    XMPPJID *jid1 = [XMPPJID jidWithString:@"user@domain.com/resource"];
    [dict1 setObject:jid1 forKey:@"jid"];
    
    XMPPIQ *iq1 = [XMPPIQ iqWithType:@"get" to:jid1 elementID:@"abc123"];
    [dict1 setObject:iq1 forKey:@"iq"];
    
    XMPPMessage *message1 = [XMPPMessage messageWithType:@"chat" to:jid1];
    [dict1 setObject:message1 forKey:@"message"];
    
    XMPPPresence *presence1 = [XMPPPresence presenceWithType:@"subscribe" to:jid1];
    [dict1 setObject:presence1 forKey:@"presence"];
    
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:dict1];
    
    NSDictionary *dict2 = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
    
    XMPPJID *jid2 = [dict2 objectForKey:@"jid"];
    
    XCTAssert([jid1 isKindOfClass:[XMPPJID class]], @"A1");
    XCTAssert([jid2 isKindOfClass:[XMPPJID class]], @"A2");
    
    XMPPIQ *iq2 = [dict2 objectForKey:@"iq"];
    
    XCTAssert([iq1 isKindOfClass:[XMPPIQ class]], @"B1");
    XCTAssert([iq2 isKindOfClass:[XMPPIQ class]], @"B2");
    
    XMPPMessage *message2 = [dict2 objectForKey:@"message"];
    
    XCTAssert([message1 isKindOfClass:[XMPPMessage class]], @"C1");
    XCTAssert([message2 isKindOfClass:[XMPPMessage class]], @"C2");
    
    XMPPPresence *presence2 = [dict2 objectForKey:@"presence"];
    
    XCTAssert([presence1 isKindOfClass:[XMPPPresence class]], @"D1");
    XCTAssert([presence2 isKindOfClass:[XMPPPresence class]], @"D2");
}

@end
