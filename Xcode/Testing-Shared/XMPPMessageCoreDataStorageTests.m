//
//  XMPPMessageCoreDataStorageTests.m
//  XMPPFrameworkTests
//
//  Created by Piotr Wegrzynek on 10/08/2017.
//
//

#import <XCTest/XCTest.h>
@import XMPPFramework;

@interface XMPPMessageCoreDataStorageTests : XCTestCase

@property (nonatomic, strong) XMPPMessageCoreDataStorage *storage;

@end

@implementation XMPPMessageCoreDataStorageTests

- (void)setUp
{
    [super setUp];
    
    self.storage = [[XMPPMessageCoreDataStorage alloc] initWithDatabaseFilename:NSStringFromSelector(self.invocation.selector)
                                                                   storeOptions:nil];
    self.storage.autoRemovePreviousDatabaseFile = YES;
}

- (void)testMessageTransientPropertyDirectUpdates
{
    XMPPMessageCoreDataStorageObject *message =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    message.fromJID = [XMPPJID jidWithString:@"user1@domain1/resource1"];
    message.toJID = [XMPPJID jidWithString:@"user2@domain2/resource2"];
    
    [self.storage.mainThreadManagedObjectContext save:NULL];
    [self.storage.mainThreadManagedObjectContext refreshObject:message mergeChanges:NO];
    
    XCTAssertEqualObjects(message.fromJID, [XMPPJID jidWithString:@"user1@domain1/resource1"]);
    XCTAssertEqualObjects(message.toJID, [XMPPJID jidWithString:@"user2@domain2/resource2"]);
}

- (void)testMessageTransientPropertyMergeUpdates
{
    XMPPMessageCoreDataStorageObject *message =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    message.fromJID = [XMPPJID jidWithString:@"user1@domain1/resource1"];
    message.toJID = [XMPPJID jidWithString:@"user2@domain2/resource2"];
    
    [self.storage.mainThreadManagedObjectContext save:NULL];
    
    [self expectationForMainThreadStorageManagedObjectsChangeNotificationWithUserInfoKey:NSRefreshedObjectsKey count:1 handler:
     ^BOOL(__kindof NSManagedObject *object) {
         return [object isKindOfClass:[XMPPMessageCoreDataStorageObject class]];
     }];
    
    [self.storage scheduleBlock:^{
        XMPPMessageCoreDataStorageObject *storageMessage = [self.storage.managedObjectContext objectWithID:message.objectID];
        storageMessage.fromJID = [XMPPJID jidWithString:@"user1a@domain1a/resource1a"];
        storageMessage.toJID = [XMPPJID jidWithString:@"user2a@domain2a/resource2a"];
        [self.storage save];
    }];
    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        XCTAssert([message.fromJID isEqualToJID:[XMPPJID jidWithString:@"user1a@domain1a/resource1a"]]);
        XCTAssert([message.toJID isEqualToJID:[XMPPJID jidWithString:@"user2a@domain2a/resource2a"]]);
    }];
}

- (void)testMessageTransientPropertyKeyValueObserving
{
    XMPPMessageCoreDataStorageObject *message =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    
    [self keyValueObservingExpectationForObject:message
                                        keyPath:NSStringFromSelector(@selector(fromJID))
                                  expectedValue:[XMPPJID jidWithString:@"user1@domain1/resource1"]];
    [self keyValueObservingExpectationForObject:message
                                        keyPath:NSStringFromSelector(@selector(toJID))
                                  expectedValue:[XMPPJID jidWithString:@"user2@domain2/resource2"]];
    
    message.fromJID = [XMPPJID jidWithString:@"user1@domain1/resource1"];
    message.toJID = [XMPPJID jidWithString:@"user2@domain2/resource2"];
    
    [self waitForExpectationsWithTimeout:0 handler:nil];
}

- (void)testIncomingMessageRegistration
{
    NSDictionary<NSString *, NSNumber *> *messageTypes = @{@"chat": @(XMPPMessageTypeChat),
                                                           @"error": @(XMPPMessageTypeError),
                                                           @"groupchat": @(XMPPMessageTypeGroupchat),
                                                           @"headline": @(XMPPMessageTypeHeadline),
                                                           @"normal": @(XMPPMessageTypeNormal)};
    
    for (NSString *typeString in messageTypes) {
        NSMutableString *messageString = [NSMutableString string];
        [messageString appendFormat: @"<message from='user1@domain1/resource1' to='user2@domain2/resource2' type='%@' id='messageID'>", typeString];
        [messageString appendString: @"     <body>body</body>"];
        [messageString appendString: @"     <subject>subject</subject>"];
        [messageString appendString: @"     <thread>thread</thread>"];
        [messageString appendString: @"</message>"];
        
        XMPPMessageCoreDataStorageObject *message =
        [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
        message.direction = XMPPMessageDirectionIncoming;
        [message registerIncomingMessageStreamEventID:[NSString stringWithFormat:@"eventID_%@", typeString]
                                            streamJID:[XMPPJID jidWithString:@"user2@domain2/resource2"]
                                 streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]];
        [message registerIncomingMessageCore:[[XMPPMessage alloc] initWithXMLString:messageString error:NULL]];
        
        XCTAssertEqualObjects(message.fromJID, [XMPPJID jidWithString:@"user1@domain1/resource1"]);
        XCTAssertEqualObjects(message.toJID, [XMPPJID jidWithString:@"user2@domain2/resource2"]);
        XCTAssertEqualObjects(message.body, @"body");
        XCTAssertEqualObjects(message.stanzaID, @"messageID");
        XCTAssertEqualObjects(message.subject, @"subject");
        XCTAssertEqualObjects(message.thread, @"thread");
        XCTAssertEqual(message.type, messageTypes[typeString].intValue);
        XCTAssertEqualObjects([message streamJID], [XMPPJID jidWithString:@"user2@domain2/resource2"]);
        XCTAssertEqualObjects([message streamTimestamp], [NSDate dateWithTimeIntervalSinceReferenceDate:0]);
    }
}

- (void)testOutgoingMessageRegistration
{
    XMPPMessageCoreDataStorageObject *message =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    message.direction = XMPPMessageDirectionOutgoing;
    [message registerOutgoingMessageStreamEventID:@"outgoingMessageEventID"];
    
    XMPPMessageCoreDataStorageObject *foundMessage = [XMPPMessageCoreDataStorageObject findWithStreamEventID:@"outgoingMessageEventID"
                                                                                      inManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    
    XCTAssertEqualObjects(message, foundMessage);
}

- (void)testSentMessageRegistration
{
    XMPPMessageCoreDataStorageObject *message =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    message.direction = XMPPMessageDirectionOutgoing;
    [message registerOutgoingMessageStreamEventID:@"outgoingMessageEventID"];
    [message registerOutgoingMessageStreamJID:[XMPPJID jidWithString:@"user@domain/resource"]
                         streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]];
    
    XCTAssertEqualObjects([message streamJID], [XMPPJID jidWithString:@"user@domain/resource"]);
    XCTAssertEqualObjects([message streamTimestamp], [NSDate dateWithTimeIntervalSinceReferenceDate:0]);
}

- (void)testRepeatedSentMessageRegistration
{
    XMPPMessageCoreDataStorageObject *message =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    message.direction = XMPPMessageDirectionOutgoing;
    [message registerOutgoingMessageStreamEventID:@"initialEventID"];
    [message registerOutgoingMessageStreamJID:[XMPPJID jidWithString:@"user1@domain1/resource1"]
                         streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]];
    [message registerOutgoingMessageStreamEventID:@"subsequentEventID"];
    [message registerOutgoingMessageStreamJID:[XMPPJID jidWithString:@"user2@domain2/resource2"]
                         streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:1]];
    
    XCTAssertEqualObjects([message streamJID], [XMPPJID jidWithString:@"user2@domain2/resource2"]);
    XCTAssertEqualObjects([message streamTimestamp], [NSDate dateWithTimeIntervalSinceReferenceDate:1]);
}

- (void)testRetiredSentMessageRegistration
{
    XMPPMessageCoreDataStorageObject *message =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    message.direction = XMPPMessageDirectionOutgoing;
    [message registerOutgoingMessageStreamEventID:@"eventID"];
    [message retireStreamTimestamp];
    [message registerOutgoingMessageStreamJID:[XMPPJID jidWithString:@"user@domain/resource"]
                         streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]];
    
    XCTAssertEqualObjects([message streamJID], [XMPPJID jidWithString:@"user@domain/resource"]);
    XCTAssertEqualObjects([message streamTimestamp], [NSDate dateWithTimeIntervalSinceReferenceDate:0]);
}

- (void)testBasicStreamTimestampMessageContextFetch
{
    XMPPMessageCoreDataStorageObject *firstMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    firstMessage.direction = XMPPMessageDirectionIncoming;
    [firstMessage registerIncomingMessageStreamEventID:@"firstMessageEventID"
                                             streamJID:[XMPPJID jidWithString:@"user@domain/resource"]
                                  streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]];
    
    XMPPMessageCoreDataStorageObject *secondMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    secondMessage.direction = XMPPMessageDirectionIncoming;
    [secondMessage registerIncomingMessageStreamEventID:@"secondMessageEventID"
                                              streamJID:[XMPPJID jidWithString:@"user@domain/resource"]
                                   streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:1]];
    
    NSFetchRequest *fetchRequest =
    [XMPPMessageContextItemCoreDataStorageObject requestByTimestampsWithPredicate:[XMPPMessageContextItemCoreDataStorageObject streamTimestampKindPredicate]
                                                                 inAscendingOrder:YES
                                                         fromManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    NSArray<XMPPMessageContextItemCoreDataStorageObject *> *result = [self.storage.mainThreadManagedObjectContext executeFetchRequest:fetchRequest error:NULL];
    
    XCTAssertEqual(result.count, 2);
    XCTAssertEqualObjects(result[0].message, firstMessage);
    XCTAssertEqualObjects(result[1].message, secondMessage);
}

- (void)testRetiredStreamTimestampMessageContextFetch
{
    XMPPMessageCoreDataStorageObject *message =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    message.direction = XMPPMessageDirectionOutgoing;
    [message registerOutgoingMessageStreamEventID:@"retiredMessageEventID"];
    [message registerOutgoingMessageStreamJID:[XMPPJID jidWithString:@"user@domain/resource"]
                         streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]];
    [message registerOutgoingMessageStreamEventID:@"retiringMessageEventID"];
    [message registerOutgoingMessageStreamJID:[XMPPJID jidWithString:@"user@domain/resource"]
                         streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:1]];
    
    NSFetchRequest *fetchRequest =
    [XMPPMessageContextItemCoreDataStorageObject requestByTimestampsWithPredicate:[XMPPMessageContextItemCoreDataStorageObject streamTimestampKindPredicate]
                                                                 inAscendingOrder:YES
                                                         fromManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    NSArray<XMPPMessageContextItemCoreDataStorageObject *> *result = [self.storage.mainThreadManagedObjectContext executeFetchRequest:fetchRequest error:NULL];
    
    XCTAssertEqual(result.count, 1);
    XCTAssertEqualObjects([result[0].message streamTimestamp], [NSDate dateWithTimeIntervalSinceReferenceDate:1]);
}

- (void)testRelevantMessageJIDContextFetch
{
    XMPPMessageCoreDataStorageObject *incomingMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    incomingMessage.direction = XMPPMessageDirectionIncoming;
    [incomingMessage registerIncomingMessageStreamEventID:@"incomingMessageEventID"
                                                streamJID:[XMPPJID jidWithString:@"user1@domain1/resource1"]
                                     streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]];
    [incomingMessage registerIncomingMessageCore:[[XMPPMessage alloc] initWithXMLString:@"<message from='user2@domain2/resource2'/>" error:NULL]];
    
    XMPPMessageCoreDataStorageObject *outgoingMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    outgoingMessage.direction = XMPPMessageDirectionOutgoing;
    outgoingMessage.toJID = [XMPPJID jidWithString:@"user2@domain2/resource2"];
    [outgoingMessage registerOutgoingMessageStreamEventID:@"outgoingMessageEventID"];
    [outgoingMessage registerOutgoingMessageStreamJID:[XMPPJID jidWithString:@"user1@domain1/resource1"]
                                 streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:1]];
    
    NSPredicate *fromJIDPredicate =
    [XMPPMessageContextItemCoreDataStorageObject messageFromJIDPredicateWithValue:[XMPPJID jidWithString:@"user2@domain2/resource2"]
                                                                   compareOptions:XMPPJIDCompareFull];
    NSFetchRequest *fromJIDFetchRequest =
    [XMPPMessageContextItemCoreDataStorageObject requestByTimestampsWithPredicate:fromJIDPredicate
                                                                 inAscendingOrder:YES
                                                         fromManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    NSArray<XMPPMessageContextItemCoreDataStorageObject *> *fromJIDResult =
    [self.storage.mainThreadManagedObjectContext executeFetchRequest:fromJIDFetchRequest error:NULL];
    
    NSPredicate *toJIDPredicate = [XMPPMessageContextItemCoreDataStorageObject messageToJIDPredicateWithValue:[XMPPJID jidWithString:@"user2@domain2/resource2"]
                                                                                               compareOptions:XMPPJIDCompareFull];
    NSFetchRequest *toJIDFetchRequest =
    [XMPPMessageContextItemCoreDataStorageObject requestByTimestampsWithPredicate:toJIDPredicate
                                                                 inAscendingOrder:YES
                                                         fromManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    NSArray<XMPPMessageContextItemCoreDataStorageObject *> *toJIDResult =
    [self.storage.mainThreadManagedObjectContext executeFetchRequest:toJIDFetchRequest error:NULL];
    
    NSPredicate *remotePartyJIDPredicate =
    [XMPPMessageContextItemCoreDataStorageObject messageRemotePartyJIDPredicateWithValue:[XMPPJID jidWithString:@"user2@domain2/resource2"]
                                                                          compareOptions:XMPPJIDCompareFull];
    NSFetchRequest *remotePartyJIDFetchRequest =
    [XMPPMessageContextItemCoreDataStorageObject requestByTimestampsWithPredicate:remotePartyJIDPredicate
                                                                 inAscendingOrder:YES
                                                         fromManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    NSArray<XMPPMessageContextItemCoreDataStorageObject *> *remotePartyJIDResult =
    [self.storage.mainThreadManagedObjectContext executeFetchRequest:remotePartyJIDFetchRequest error:NULL];
    
    XCTAssertEqual(fromJIDResult.count, 1);
    XCTAssertEqualObjects(fromJIDResult[0].message, incomingMessage);
    
    XCTAssertEqual(toJIDResult.count, 1);
    XCTAssertEqualObjects(toJIDResult[0].message, outgoingMessage);
    
    XCTAssertEqual(remotePartyJIDResult.count, 2);
    XCTAssertEqualObjects(remotePartyJIDResult[0].message, incomingMessage);
    XCTAssertEqualObjects(remotePartyJIDResult[1].message, outgoingMessage);
}

- (void)testTimestampRangeContextFetch
{
    XMPPMessageCoreDataStorageObject *message =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    message.direction = XMPPMessageDirectionIncoming;
    [message registerIncomingMessageStreamEventID:@"eventID"
                                        streamJID:[XMPPJID jidWithString:@"user@domain/resource"]
                             streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]];
    
    NSPredicate *startEndPredicate =
    [XMPPMessageContextItemCoreDataStorageObject timestampRangePredicateWithStartValue:[NSDate dateWithTimeIntervalSinceReferenceDate:-1]
                                                                              endValue:[NSDate dateWithTimeIntervalSinceReferenceDate:1]];
    NSFetchRequest *startEndFetchRequest =
    [XMPPMessageContextItemCoreDataStorageObject requestByTimestampsWithPredicate:startEndPredicate
                                                                 inAscendingOrder:YES
                                                         fromManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    NSArray<XMPPMessageContextItemCoreDataStorageObject *> *startEndResult =
    [self.storage.mainThreadManagedObjectContext executeFetchRequest:startEndFetchRequest error:NULL];
    
    NSPredicate *startEndEdgeCasePredicate =
    [XMPPMessageContextItemCoreDataStorageObject timestampRangePredicateWithStartValue:[NSDate dateWithTimeIntervalSinceReferenceDate:0]
                                                                              endValue:[NSDate dateWithTimeIntervalSinceReferenceDate:0]];
    NSFetchRequest *startEndEdgeCaseFetchRequest =
    [XMPPMessageContextItemCoreDataStorageObject requestByTimestampsWithPredicate:startEndEdgeCasePredicate
                                                                 inAscendingOrder:YES
                                                         fromManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    NSArray<XMPPMessageContextItemCoreDataStorageObject *> *startEndEdgeCaseResult =
    [self.storage.mainThreadManagedObjectContext executeFetchRequest:startEndEdgeCaseFetchRequest error:NULL];
    
    NSPredicate *startPredicate =
    [XMPPMessageContextItemCoreDataStorageObject timestampRangePredicateWithStartValue:[NSDate dateWithTimeIntervalSinceReferenceDate:-1]
                                                                              endValue:nil];
    NSFetchRequest *startFetchRequest =
    [XMPPMessageContextItemCoreDataStorageObject requestByTimestampsWithPredicate:startPredicate
                                                                 inAscendingOrder:YES
                                                         fromManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    NSArray<XMPPMessageContextItemCoreDataStorageObject *> *startResult =
    [self.storage.mainThreadManagedObjectContext executeFetchRequest:startFetchRequest error:NULL];
    
    NSPredicate *startEdgeCasePredicate =
    [XMPPMessageContextItemCoreDataStorageObject timestampRangePredicateWithStartValue:[NSDate dateWithTimeIntervalSinceReferenceDate:0]
                                                                              endValue:nil];
    NSFetchRequest *startEdgeCaseFetchRequest =
    [XMPPMessageContextItemCoreDataStorageObject requestByTimestampsWithPredicate:startEdgeCasePredicate
                                                                 inAscendingOrder:YES
                                                         fromManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    NSArray<XMPPMessageContextItemCoreDataStorageObject *> *startEdgeCaseResult =
    [self.storage.mainThreadManagedObjectContext executeFetchRequest:startEdgeCaseFetchRequest error:NULL];
    
    NSPredicate *endPredicate =
    [XMPPMessageContextItemCoreDataStorageObject timestampRangePredicateWithStartValue:nil
                                                                              endValue:[NSDate dateWithTimeIntervalSinceReferenceDate:1]];
    NSFetchRequest *endFetchRequest =
    [XMPPMessageContextItemCoreDataStorageObject requestByTimestampsWithPredicate:endPredicate
                                                                 inAscendingOrder:YES
                                                         fromManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    NSArray<XMPPMessageContextItemCoreDataStorageObject *> *endResult =
    [self.storage.mainThreadManagedObjectContext executeFetchRequest:endFetchRequest error:NULL];
    
    NSPredicate *endEdgeCasePredicate =
    [XMPPMessageContextItemCoreDataStorageObject timestampRangePredicateWithStartValue:nil
                                                                              endValue:[NSDate dateWithTimeIntervalSinceReferenceDate:0]];
    NSFetchRequest *endEdgeCaseFetchRequest =
    [XMPPMessageContextItemCoreDataStorageObject requestByTimestampsWithPredicate:endEdgeCasePredicate
                                                                 inAscendingOrder:YES
                                                         fromManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    NSArray<XMPPMessageContextItemCoreDataStorageObject *> *endEdgeCaseResult =
    [self.storage.mainThreadManagedObjectContext executeFetchRequest:endEdgeCaseFetchRequest error:NULL];
    
    NSPredicate *missPredicate =
    [XMPPMessageContextItemCoreDataStorageObject timestampRangePredicateWithStartValue:[NSDate dateWithTimeIntervalSinceReferenceDate:1]
                                                                              endValue:[NSDate dateWithTimeIntervalSinceReferenceDate:2]];
    NSFetchRequest *missFetchRequest =
    [XMPPMessageContextItemCoreDataStorageObject requestByTimestampsWithPredicate:missPredicate
                                                                 inAscendingOrder:YES
                                                         fromManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    NSArray<XMPPMessageContextItemCoreDataStorageObject *> *missResult =
    [self.storage.mainThreadManagedObjectContext executeFetchRequest:missFetchRequest error:NULL];
    
    XCTAssertEqual(startEndResult.count, 1);
    XCTAssertEqualObjects(startEndResult[0].message, message);
    XCTAssertEqual(startEndEdgeCaseResult.count, 1);
    XCTAssertEqualObjects(startEndEdgeCaseResult[0].message, message);
    
    XCTAssertEqual(startResult.count, 1);
    XCTAssertEqualObjects(startResult[0].message, message);
    XCTAssertEqual(startEdgeCaseResult.count, 1);
    XCTAssertEqualObjects(startEdgeCaseResult[0].message, message);
    
    XCTAssertEqual(endResult.count, 1);
    XCTAssertEqualObjects(endResult[0].message, message);
    XCTAssertEqual(endEdgeCaseResult.count, 1);
    XCTAssertEqualObjects(endEdgeCaseResult[0].message, message);
    
    XCTAssertEqual(missResult.count, 0);
}

- (void)testMessageSubjectContextFetch
{
    XMPPMessageCoreDataStorageObject *matchingMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    matchingMessage.direction = XMPPMessageDirectionIncoming;
    [matchingMessage registerIncomingMessageStreamEventID:@"matchingMessageEventID"
                                                streamJID:[XMPPJID jidWithString:@"user@domain/resource"]
                                     streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]];
    matchingMessage.subject = @"I implore you!";
    
    XMPPMessageCoreDataStorageObject *otherMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    otherMessage.direction = XMPPMessageDirectionIncoming;
    [otherMessage registerIncomingMessageStreamEventID:@"otherMessageEventID"
                                             streamJID:[XMPPJID jidWithString:@"user@domain/resource"]
                                  streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:1]];
    
    XMPPMessageContentCompareOptions options = XMPPMessageContentCompareCaseInsensitive|XMPPMessageContentCompareDiacriticInsensitive;
    
    NSPredicate *equalityPredicate = [XMPPMessageContextItemCoreDataStorageObject messageSubjectPredicateWithValue:@"I implore you!"
                                                                                                   compareOperator:XMPPMessageContentCompareOperatorEquals
                                                                                                           options:options];
    NSPredicate *prefixPredicate = [XMPPMessageContextItemCoreDataStorageObject messageSubjectPredicateWithValue:@"i implore"
                                                                                                 compareOperator:XMPPMessageContentCompareOperatorBeginsWith
                                                                                                         options:options];
    NSPredicate *containmentPredicate =
    [XMPPMessageContextItemCoreDataStorageObject messageSubjectPredicateWithValue:@"implore"
                                                                  compareOperator:XMPPMessageContentCompareOperatorContains
                                                                          options:options];
    NSPredicate *suffixPredicate = [XMPPMessageContextItemCoreDataStorageObject messageSubjectPredicateWithValue:@"you!"
                                                                                                 compareOperator:XMPPMessageContentCompareOperatorEndsWith
                                                                                                         options:options];
    NSPredicate *likePredicate = [XMPPMessageContextItemCoreDataStorageObject messageSubjectPredicateWithValue:@"I implore *!"
                                                                                               compareOperator:XMPPMessageContentCompareOperatorLike
                                                                                                       options:options];
    NSPredicate *matchPredicate = [XMPPMessageContextItemCoreDataStorageObject messageSubjectPredicateWithValue:@"I implore .*!"
                                                                                                compareOperator:XMPPMessageContentCompareOperatorMatches
                                                                                                        options:options];
    
    for (NSPredicate *predicate in @[equalityPredicate, prefixPredicate, containmentPredicate, suffixPredicate, likePredicate, matchPredicate]) {
        NSFetchRequest *fetchRequest =
        [XMPPMessageContextItemCoreDataStorageObject requestByTimestampsWithPredicate:predicate
                                                                     inAscendingOrder:YES
                                                             fromManagedObjectContext:self.storage.mainThreadManagedObjectContext];
        NSArray<XMPPMessageContextItemCoreDataStorageObject *> *result = [self.storage.mainThreadManagedObjectContext executeFetchRequest:fetchRequest
                                                                                                                                    error:NULL];
        
        XCTAssertEqual(result.count, 1);
        XCTAssertEqualObjects(result[0].message, matchingMessage);
    }
}

- (void)testMessageBodyContextFetch
{
    XMPPMessageCoreDataStorageObject *matchingMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    matchingMessage.direction = XMPPMessageDirectionIncoming;
    [matchingMessage registerIncomingMessageStreamEventID:@"matchingMessageEventID"
                                                streamJID:[XMPPJID jidWithString:@"user@domain/resource"]
                                     streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]];
    matchingMessage.body = @"Wherefore art thou, Romeo?";
    
    XMPPMessageCoreDataStorageObject *otherMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    otherMessage.direction = XMPPMessageDirectionIncoming;
    [otherMessage registerIncomingMessageStreamEventID:@"otherMessageEventID"
                                             streamJID:[XMPPJID jidWithString:@"user@domain/resource"]
                                  streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:1]];
    
    XMPPMessageContentCompareOptions options = XMPPMessageContentCompareCaseInsensitive|XMPPMessageContentCompareDiacriticInsensitive;
    
    NSPredicate *equalityPredicate = [XMPPMessageContextItemCoreDataStorageObject messageBodyPredicateWithValue:@"Wherefore art thou, Romeo?"
                                                                                                compareOperator:XMPPMessageContentCompareOperatorEquals
                                                                                                        options:options];
    NSPredicate *prefixPredicate = [XMPPMessageContextItemCoreDataStorageObject messageBodyPredicateWithValue:@"wherefore"
                                                                                              compareOperator:XMPPMessageContentCompareOperatorBeginsWith
                                                                                                      options:options];
    NSPredicate *containmentPredicate = [XMPPMessageContextItemCoreDataStorageObject messageBodyPredicateWithValue:@"art thou"
                                                                                                   compareOperator:XMPPMessageContentCompareOperatorContains
                                                                                                           options:options];
    NSPredicate *suffixPredicate = [XMPPMessageContextItemCoreDataStorageObject messageBodyPredicateWithValue:@"romeo?"
                                                                                              compareOperator:XMPPMessageContentCompareOperatorEndsWith
                                                                                                      options:options];
    NSPredicate *likePredicate = [XMPPMessageContextItemCoreDataStorageObject messageBodyPredicateWithValue:@"Wherefore art thou, *"
                                                                                            compareOperator:XMPPMessageContentCompareOperatorLike
                                                                                                    options:options];
    NSPredicate *matchPredicate = [XMPPMessageContextItemCoreDataStorageObject messageBodyPredicateWithValue:@"Wherefore art thou, .*"
                                                                                             compareOperator:XMPPMessageContentCompareOperatorMatches
                                                                                                     options:options];
    
    for (NSPredicate *predicate in @[equalityPredicate, prefixPredicate, containmentPredicate, suffixPredicate, likePredicate, matchPredicate]) {
        NSFetchRequest *fetchRequest =
        [XMPPMessageContextItemCoreDataStorageObject requestByTimestampsWithPredicate:predicate
                                                                     inAscendingOrder:YES
                                                             fromManagedObjectContext:self.storage.mainThreadManagedObjectContext];
        NSArray<XMPPMessageContextItemCoreDataStorageObject *> *result = [self.storage.mainThreadManagedObjectContext executeFetchRequest:fetchRequest
                                                                                                                                    error:NULL];
        
        XCTAssertEqual(result.count, 1);
        XCTAssertEqualObjects(result[0].message, matchingMessage);
    }
}

- (void)testMessageThreadContextFetch
{
    XMPPMessageCoreDataStorageObject *matchingMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    matchingMessage.direction = XMPPMessageDirectionIncoming;
    [matchingMessage registerIncomingMessageStreamEventID:@"matchingMessageEventID"
                                                streamJID:[XMPPJID jidWithString:@"user@domain/resource"]
                                     streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]];
    matchingMessage.thread = @"e0ffe42b28561960c6b12b944a092794b9683a38";
    
    XMPPMessageCoreDataStorageObject *otherMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    otherMessage.direction = XMPPMessageDirectionIncoming;
    [otherMessage registerIncomingMessageStreamEventID:@"otherMessageEventID"
                                             streamJID:[XMPPJID jidWithString:@"user@domain/resource"]
                                  streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:1]];
    
    NSPredicate *predicate = [XMPPMessageContextItemCoreDataStorageObject messageThreadPredicateWithValue:@"e0ffe42b28561960c6b12b944a092794b9683a38"];
    NSFetchRequest *fetchRequest =
    [XMPPMessageContextItemCoreDataStorageObject requestByTimestampsWithPredicate:predicate
                                                                 inAscendingOrder:YES
                                                         fromManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    NSArray<XMPPMessageContextItemCoreDataStorageObject *> *result = [self.storage.mainThreadManagedObjectContext executeFetchRequest:fetchRequest error:NULL];
    
    XCTAssertEqual(result.count, 1);
    XCTAssertEqualObjects(result[0].message, matchingMessage);
}

- (void)testMessageTypeContextFetch
{
    NSArray *messageTypes = @[@(XMPPMessageTypeChat),
                              @(XMPPMessageTypeError),
                              @(XMPPMessageTypeGroupchat),
                              @(XMPPMessageTypeHeadline),
                              @(XMPPMessageTypeNormal)];
    for (NSNumber *typeNumber in messageTypes) {
        XMPPMessageCoreDataStorageObject *message =
        [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
        message.direction = XMPPMessageDirectionIncoming;
        [message registerIncomingMessageStreamEventID:[NSString stringWithFormat:@"message%@EventID", typeNumber]
                                            streamJID:[XMPPJID jidWithString:@"user@domain/resource"]
                                 streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]];
        message.stanzaID = [NSString stringWithFormat:@"message%@ID", typeNumber];
        message.type = typeNumber.integerValue;
    }
    
    for (NSNumber *typeNumber in messageTypes) {
        NSPredicate *predicate = [XMPPMessageContextItemCoreDataStorageObject messageTypePredicateWithValue:typeNumber.integerValue];
        NSFetchRequest *fetchRequest =
        [XMPPMessageContextItemCoreDataStorageObject requestByTimestampsWithPredicate:predicate
                                                                     inAscendingOrder:YES
                                                             fromManagedObjectContext:self.storage.mainThreadManagedObjectContext];
        NSArray<XMPPMessageContextItemCoreDataStorageObject *> *result = [self.storage.mainThreadManagedObjectContext executeFetchRequest:fetchRequest error:NULL];
        
        XCTAssertEqual(result.count, 1);
        XCTAssertEqualObjects(result[0].message.stanzaID, ([NSString stringWithFormat:@"message%@ID", typeNumber]));
    }
}

- (void)testCoreMessageCreation
{
    XMPPMessageCoreDataStorageObject *message =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    message.toJID = [XMPPJID jidWithString:@"user2@domain2/resource2"];
    message.body = @"body";
    message.stanzaID = @"messageID";
    message.subject = @"subject";
    message.thread = @"thread";
    
    NSDictionary<NSString *, NSNumber *> *messageTypes = @{@"chat": @(XMPPMessageTypeChat),
                                                           @"error": @(XMPPMessageTypeError),
                                                           @"groupchat": @(XMPPMessageTypeGroupchat),
                                                           @"headline": @(XMPPMessageTypeHeadline),
                                                           @"normal": @(XMPPMessageTypeNormal)};
    
    for (NSString *typeString in messageTypes){
        message.type = messageTypes[typeString].intValue;
        
        XMPPMessage *xmppMessage = [message coreMessage];
        
        XCTAssertEqualObjects([xmppMessage to], [XMPPJID jidWithString:@"user2@domain2/resource2"]);
        XCTAssertEqualObjects([xmppMessage body], @"body");
        XCTAssertEqualObjects([xmppMessage elementID], @"messageID");
        XCTAssertEqualObjects([xmppMessage subject], @"subject");
        XCTAssertEqualObjects([xmppMessage thread], @"thread");
        XCTAssertEqualObjects([xmppMessage type], typeString);
    }
}

- (XCTestExpectation *)expectationForMainThreadStorageManagedObjectsChangeNotificationWithUserInfoKey:(NSString *)userInfoKey count:(NSInteger)expectedObjectCount handler:(BOOL (^)(__kindof NSManagedObject *object))handler
{
    return [self expectationForNotification:NSManagedObjectContextObjectsDidChangeNotification object:self.storage.mainThreadManagedObjectContext handler:
            ^BOOL(NSNotification * _Nonnull notification) {
                return [notification.userInfo[userInfoKey] objectsPassingTest:^BOOL(id  _Nonnull obj, BOOL * _Nonnull stop) {
                    return handler ? handler(obj) : YES;
                }].count == expectedObjectCount;
            }];
}

@end
