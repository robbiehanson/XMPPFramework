//
//  XMPPRoomLightCoreDataStorageTests.m
//  XMPPFrameworkTests
//
//  Created by Andres on 6/9/16.
//
//

#import <XCTest/XCTest.h>
#import "XMPPMockStream.h"
@import XMPPFramework;

@interface XMPPRoomLightCoreDataStorageTests : XCTestCase <XMPPRoomLightDelegate>

@property (nonatomic, strong) XCTestExpectation *delegateResponseExpectation;
@property BOOL checkDelegate;
@end

@implementation XMPPRoomLightCoreDataStorageTests

- (void)testReceiveMessageWithoutStorage{
	self.checkDelegate = true;

	self.delegateResponseExpectation = [self expectationWithDescription:@"receive message"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	streamTest.myJID = [XMPPJID jidWithString:@"myUser@domain.com"];

	XMPPJID *jid = [XMPPJID jidWithString:@"room@domain.com"];
	XMPPRoomLight *roomLight = [[XMPPRoomLight alloc] initWithRoomLightStorage:nil jid:jid roomname:@"test" dispatchQueue:nil];
	[roomLight addDelegate:self delegateQueue:dispatch_get_main_queue()];
	[roomLight activate:streamTest];

	[streamTest fakeMessageResponse:[self fakeIncomingMessage]];
	[self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)testReceiveMessageWithStorage{
	self.checkDelegate = false;
	XCTestExpectation *expectation = [self expectationWithDescription:@"receive message and correctly stored"];

	XMPPRoomLightCoreDataStorage *storage = [[XMPPRoomLightCoreDataStorage alloc] initWithDatabaseFilename:@"test.sqlite" storeOptions:nil];
    storage.autoRemovePreviousDatabaseFile = YES;

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	streamTest.myJID = [XMPPJID jidWithString:@"myUser@domain.com"];
	XMPPJID *jid = [XMPPJID jidWithString:@"room@domain.com"];
	XMPPRoomLight *roomLight = [[XMPPRoomLight alloc] initWithRoomLightStorage:storage jid:jid roomname:@"test" dispatchQueue:nil];
	[roomLight addDelegate:self delegateQueue:dispatch_get_main_queue()];
	[roomLight activate:streamTest];

	[streamTest fakeMessageResponse:[self fakeIncomingMessage]];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		NSManagedObjectContext *context = [storage mainThreadManagedObjectContext];
		NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPRoomLightMessageCoreDataStorageObject"
												  inManagedObjectContext:context];

		NSPredicate *predicate = [NSPredicate predicateWithFormat:@"roomJIDStr = %@", jid.full];
		NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"localTimestamp" ascending:YES];

		NSFetchRequest *request = [[NSFetchRequest alloc] init];
		request.entity = entity;
		request.predicate = predicate;
		request.sortDescriptors = @[sortDescriptor];

		NSError *error;
		XMPPRoomLightMessageCoreDataStorageObject *roomMessage = [[context executeFetchRequest:request error:&error] firstObject];
		XCTAssertNil(error);
		XCTAssertEqualObjects(roomMessage.jid.full, @"room@domain.com/test.user@erlang-solutions.com");
		XCTAssertEqualObjects(roomMessage.body, @"Yo! 13");
		XCTAssertEqualObjects(roomMessage.nickname, @"test.user@erlang-solutions.com");
		XCTAssertFalse(roomMessage.isFromMe);

		[expectation fulfill];
	});

	[self waitForExpectationsWithTimeout:3 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)testImportMessage {
    self.checkDelegate = false;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"message imported"];
    
    XMPPRoomLightCoreDataStorage *storage = [[XMPPRoomLightCoreDataStorage alloc] initWithDatabaseFilename:@"test.sqlite" storeOptions:nil];
    storage.autoRemovePreviousDatabaseFile = YES;
    
    XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
    streamTest.myJID = [XMPPJID jidWithString:@"myUser@domain.com"];
    XMPPJID *jid = [XMPPJID jidWithString:@"room@domain.com"];
    XMPPRoomLight *roomLight = [[XMPPRoomLight alloc] initWithRoomLightStorage:storage jid:jid roomname:@"test" dispatchQueue:nil];
    
    [storage importRemoteArchiveMessage:[self fakeIncomingMessage] withTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0] inRoom:roomLight fromStream:streamTest];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSManagedObjectContext *context = [storage mainThreadManagedObjectContext];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPRoomLightMessageCoreDataStorageObject"
                                                  inManagedObjectContext:context];
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"roomJIDStr = %@", jid.full];
        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"localTimestamp" ascending:YES];
        
        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        request.entity = entity;
        request.predicate = predicate;
        request.sortDescriptors = @[sortDescriptor];
        
        NSError *error;
        XMPPRoomLightMessageCoreDataStorageObject *roomMessage = [[context executeFetchRequest:request error:&error] firstObject];
        XCTAssertNil(error);
        XCTAssertEqualObjects(roomMessage.jid.full, @"room@domain.com/test.user@erlang-solutions.com");
        XCTAssertEqualObjects(roomMessage.body, @"Yo! 13");
        XCTAssertEqualObjects(roomMessage.nickname, @"test.user@erlang-solutions.com");
        XCTAssertFalse(roomMessage.isFromMe);
        
        [expectation fulfill];
    });
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError * _Nullable error) {
        if(error){
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

- (void)testImportMessageUniquing {
    self.checkDelegate = false;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"only one of two messages imported"];
    
    XMPPRoomLightCoreDataStorage *storage = [[XMPPRoomLightCoreDataStorage alloc] initWithDatabaseFilename:@"test.sqlite" storeOptions:nil];
    storage.autoRemovePreviousDatabaseFile = YES;
    
    XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
    streamTest.myJID = [XMPPJID jidWithString:@"myUser@domain.com"];
    XMPPJID *jid = [XMPPJID jidWithString:@"room@domain.com"];
    XMPPRoomLight *roomLight = [[XMPPRoomLight alloc] initWithRoomLightStorage:storage jid:jid roomname:@"test" dispatchQueue:nil];
    
    [storage importRemoteArchiveMessage:[self fakeIncomingMessage] withTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0] inRoom:roomLight fromStream:streamTest];
    [storage importRemoteArchiveMessage:[self fakeIncomingMessage] withTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0] inRoom:roomLight fromStream:streamTest];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSManagedObjectContext *context = [storage mainThreadManagedObjectContext];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPRoomLightMessageCoreDataStorageObject"
                                                  inManagedObjectContext:context];
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"roomJIDStr = %@", jid.full];
        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"localTimestamp" ascending:YES];
        
        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        request.entity = entity;
        request.predicate = predicate;
        request.sortDescriptors = @[sortDescriptor];
        
        NSError *error;
        NSArray *messages = [context executeFetchRequest:request error:&error];
        XCTAssertNil(error);
        XCTAssertEqual(messages.count, 1);
        
        [expectation fulfill];
    });
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError * _Nullable error) {
        if(error){
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

- (void)xmppRoomLight:(XMPPRoomLight *)sender didReceiveMessage:(XMPPMessage *)message{
	if (self.checkDelegate) {
		[self.delegateResponseExpectation fulfill];
	}
}

- (XMPPMessage *)fakeIncomingMessage{
	NSMutableString *s = [NSMutableString string];
	[s appendString: @"<message xmlns='jabber:client' \
								 from='room@domain.com/test.user@erlang-solutions.com' \
								   to='test.user@erlang-solutions.com' \
								   id='C7A969D8-C711-4516-9313-10EA9927B39B' \
								 type='groupchat'>"];
	[s appendString: @"    <body>Yo! 13</body>'"];
	[s appendString: @"</message>"];

	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	return [XMPPMessage messageFromElement:[doc rootElement]];
}

@end
