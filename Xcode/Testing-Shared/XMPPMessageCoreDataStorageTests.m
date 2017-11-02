//
//  XMPPMessageCoreDataStorageTests.m
//  XMPPFrameworkTests
//
//  Created by Piotr Wegrzynek on 10/08/2017.
//
//

#import <XCTest/XCTest.h>
#import "XMPPMockStream.h"
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

- (void)testIncomingMessageEventStorageTransactionBatching
{
    // Delayed saving would interfere with the test objective, i.e. ensuring the actions are performed in a single batch
    self.storage.saveThreshold = 0;
    
    XMPPMockStream *mockStream = [[XMPPMockStream alloc] init];
    mockStream.myJID = [XMPPJID jidWithString:@"romeo@example.net"];
    
    [self expectationForMainThreadStorageManagedObjectsChangeNotificationWithUserInfoKey:NSInsertedObjectsKey count:1 handler:
     ^BOOL(__kindof NSManagedObject *object) {
         return [object isKindOfClass:[XMPPMessageCoreDataStorageObject class]];
     }];
    
    [self provideTransactionForFakeIncomingMessageEventInStream:mockStream withID:@"eventID" timestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0] block:
     ^(XMPPMessageCoreDataStorageTransaction *transaction) {
         [transaction scheduleStorageUpdateWithBlock:^(XMPPMessageCoreDataStorageObject * _Nonnull messageObject) {
             messageObject.fromJID = [XMPPJID jidWithString:@"juliet@example.com"];
             messageObject.toJID = [XMPPJID jidWithString:@"romeo@example.net"];
         }];
        
         [transaction scheduleStorageUpdateWithBlock:^(XMPPMessageCoreDataStorageObject * _Nonnull messageObject) {
             messageObject.body = @"Art thou not Romeo, and a Montague?";
         }];
     }];
    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        XMPPMessageCoreDataStorageObject *message = [XMPPMessageCoreDataStorageObject findWithStreamEventID:@"eventID"
                                                                                     inManagedObjectContext:self.storage.mainThreadManagedObjectContext];
        XCTAssertNotNil(message);
        XCTAssertEqual(message.direction, XMPPMessageDirectionIncoming);
        XCTAssertEqualObjects([message streamJID], [XMPPJID jidWithString:@"romeo@example.net"]);
        XCTAssertEqualObjects([message streamTimestamp], [NSDate dateWithTimeIntervalSinceReferenceDate:0]);
        XCTAssertEqualObjects([message fromJID], [XMPPJID jidWithString:@"juliet@example.com"]);
        XCTAssertEqualObjects([message toJID], [XMPPJID jidWithString:@"romeo@example.net"]);
        XCTAssertEqualObjects([message body], @"Art thou not Romeo, and a Montague?");
    }];
}

- (void)testOutgoingMessageStorageInsertion
{
    XMPPMessageCoreDataStorageObject *message = [self.storage insertOutgoingMessageStorageObject];
    XCTAssertEqual(message.direction, XMPPMessageDirectionOutgoing);
}

- (void)testOutgoingMessageEventStorageTransactionBatching
{
    // Delayed saving would interfere with the test objective, i.e. ensuring the actions are performed in a single batch
    self.storage.saveThreshold = 0;
    
    XMPPMockStream *mockStream = [[XMPPMockStream alloc] init];
    mockStream.myJID = [XMPPJID jidWithString:@"juliet@example.com"];
    
    XMPPMessageCoreDataStorageObject *message = [self.storage insertOutgoingMessageStorageObject];
    [message registerOutgoingMessageStreamEventID:@"eventID"];
    [self.storage.mainThreadManagedObjectContext save:NULL];
    
    [self expectationForMainThreadStorageManagedObjectsChangeNotificationWithUserInfoKey:NSRefreshedObjectsKey count:1 handler:
     ^BOOL(__kindof NSManagedObject *object) {
         return [object isKindOfClass:[XMPPMessageCoreDataStorageObject class]];
     }];
    
    [self provideTransactionForFakeOutgoingMessageEventInStream:mockStream withID:@"eventID" timestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0] block:
     ^(XMPPMessageCoreDataStorageTransaction *transaction) {
         [transaction scheduleStorageUpdateWithBlock:^(XMPPMessageCoreDataStorageObject * _Nonnull messageObject) {
             messageObject.fromJID = [XMPPJID jidWithString:@"juliet@example.com"];
             messageObject.toJID = [XMPPJID jidWithString:@"romeo@example.net"];
         }];
         
         [transaction scheduleStorageUpdateWithBlock:^(XMPPMessageCoreDataStorageObject * _Nonnull messageObject) {
             messageObject.body = @"Art thou not Romeo, and a Montague?";
         }];
     }];
    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        XMPPMessageCoreDataStorageObject *updatedMessage = [XMPPMessageCoreDataStorageObject findWithStreamEventID:@"eventID"
                                                                                            inManagedObjectContext:self.storage.mainThreadManagedObjectContext];
        XCTAssertEqualObjects(updatedMessage, message);
        XCTAssertEqualObjects([updatedMessage streamJID], [XMPPJID jidWithString:@"juliet@example.com"]);
        XCTAssertEqualObjects([updatedMessage streamTimestamp], [NSDate dateWithTimeIntervalSinceReferenceDate:0]);
        XCTAssertEqualObjects([updatedMessage fromJID], [XMPPJID jidWithString:@"juliet@example.com"]);
        XCTAssertEqualObjects([updatedMessage toJID], [XMPPJID jidWithString:@"romeo@example.net"]);
        XCTAssertEqualObjects([updatedMessage body], @"Art thou not Romeo, and a Montague?");
    }];
}

- (void)provideTransactionForFakeIncomingMessageEventInStream:(XMPPMockStream *)stream withID:(NSString *)eventID timestamp:(NSDate *)timestamp block:(void (^)(XMPPMessageCoreDataStorageTransaction *transaction))block
{
    [stream fakeCurrentEventWithID:eventID timestamp:timestamp forActionWithBlock:^{
        [self.storage provideTransactionForIncomingMessageEvent:[stream currentElementEvent] withHandler:block];
    }];
}

- (void)provideTransactionForFakeOutgoingMessageEventInStream:(XMPPMockStream *)stream withID:(NSString *)eventID timestamp:(NSDate *)timestamp block:(void (^)(XMPPMessageCoreDataStorageTransaction *transaction))block
{
    [stream fakeCurrentEventWithID:eventID timestamp:timestamp forActionWithBlock:^{
        [self.storage provideTransactionForOutgoingMessageEvent:[stream currentElementEvent] withHandler:block];
    }];
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

@implementation XMPPMessageCoreDataStorageTests (XMPPOneToOneChat)

- (void)testIncomingChatMessageHandling
{
    XMPPMockStream *mockStream = [[XMPPMockStream alloc] init];
    mockStream.myJID = [XMPPJID jidWithString:@"romeo@example.net"];
    
    XMPPMessage *message = [[XMPPMessage alloc] initWithXMLString:
                            @"<message from='juliet@example.com'"
                            @"         to='romeo@example.net'"
                            @"         type='chat'>"
                            @"  <body>Art thou not Romeo, and a Montague?</body>"
                            @"</message>"
                                                            error:nil];
    
    [self expectationForMainThreadStorageManagedObjectsChangeNotificationWithUserInfoKey:NSInsertedObjectsKey count:1 handler:
     ^BOOL(__kindof NSManagedObject *object) {
         return [object isKindOfClass:[XMPPMessageCoreDataStorageObject class]];
     }];
    
    [self provideTransactionForFakeIncomingMessageEventInStream:mockStream withID:@"eventID" timestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0] block:
     ^(XMPPMessageCoreDataStorageTransaction *transaction) {
         [transaction storeReceivedChatMessage:message];
     }];
    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        NSFetchRequest *fetchRequest = [XMPPMessageCoreDataStorageObject xmpp_fetchRequestInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
        NSArray<XMPPMessageCoreDataStorageObject *> *fetchResult =
        [self.storage.mainThreadManagedObjectContext xmpp_executeForcedSuccessFetchRequest:fetchRequest];
        
        XCTAssertEqual(fetchResult.count, 1);
        XCTAssertEqualObjects(fetchResult.firstObject.fromJID, [XMPPJID jidWithString:@"juliet@example.com"]);
        XCTAssertEqualObjects(fetchResult.firstObject.toJID, [XMPPJID jidWithString:@"romeo@example.net"]);
        XCTAssertEqualObjects(fetchResult.firstObject.body, @"Art thou not Romeo, and a Montague?");
        XCTAssertEqual(fetchResult.firstObject.direction, XMPPMessageDirectionIncoming);
        XCTAssertEqual(fetchResult.firstObject.type, XMPPMessageTypeChat);
        XCTAssertEqualObjects([fetchResult.firstObject streamJID], [XMPPJID jidWithString:@"romeo@example.net"]);
        XCTAssertEqualObjects([fetchResult.firstObject streamTimestamp], [NSDate dateWithTimeIntervalSinceReferenceDate:0]);
    }];
}

- (void)testSentChatMessageHandling
{
    XMPPMessageCoreDataStorageObject *message = [self.storage insertOutgoingMessageStorageObject];
    [message registerOutgoingMessageStreamEventID:@"eventID"];
    [self.storage.mainThreadManagedObjectContext save:NULL];
    
    XMPPMockStream *mockStream = [[XMPPMockStream alloc] init];
    mockStream.myJID = [XMPPJID jidWithString:@"juliet@example.com"];
    
    [self expectationForNotification:NSManagedObjectContextObjectsDidChangeNotification object:self.storage.mainThreadManagedObjectContext handler:nil];
    
    [self provideTransactionForFakeOutgoingMessageEventInStream:mockStream withID:@"eventID" timestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0] block:
     ^(XMPPMessageCoreDataStorageTransaction *transaction) {
         [transaction registerSentChatMessage];
     }];
    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        XCTAssertEqualObjects([message streamJID], [XMPPJID jidWithString:@"juliet@example.com"]);
        XCTAssertEqualObjects([message streamTimestamp], [NSDate dateWithTimeIntervalSinceReferenceDate:0]);
    }];
}

@end

@implementation XMPPMessageCoreDataStorageTests (XMPPMUCLight)

- (void)testIncomingRoomLightMessageHandling
{
    XMPPMockStream *mockStream = [[XMPPMockStream alloc] init];
    mockStream.myJID = [XMPPJID jidWithString:@"crone1@shakespeare.lit"];
    
    XMPPMessage *message = [[XMPPMessage alloc] initWithXMLString:
                            @"<message id='msg111' type='groupchat'"
                            @"  from='coven@muclight.shakespeare.lit/hag66@shakespeare.lit'"
                            @"  to='crone1@shakespeare.lit'>"
                            @"  <body>Harpier cries: 'tis time, 'tis time.</body>"
                            @"</message>"
                                                            error:nil];
    
    [self expectationForMainThreadStorageManagedObjectsChangeNotificationWithUserInfoKey:NSInsertedObjectsKey count:1 handler:
     ^BOOL(__kindof NSManagedObject *object) {
         return [object isKindOfClass:[XMPPMessageCoreDataStorageObject class]];
     }];
    
    [self provideTransactionForFakeIncomingMessageEventInStream:mockStream withID:@"eventID" timestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0] block:
     ^(XMPPMessageCoreDataStorageTransaction *transaction) {
         [transaction storeReceivedRoomLightMessage:message];
     }];
    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        XMPPMessageCoreDataStorageObject *message = [XMPPMessageCoreDataStorageObject findWithUniqueStanzaID:@"msg111"
                                                                                      inManagedObjectContext:self.storage.mainThreadManagedObjectContext];
        
        XCTAssertNotNil(message);
        XCTAssertEqualObjects(message.fromJID, [XMPPJID jidWithString:@"coven@muclight.shakespeare.lit/hag66@shakespeare.lit"]);
        XCTAssertEqualObjects(message.toJID, [XMPPJID jidWithString:@"crone1@shakespeare.lit"]);
        XCTAssertEqualObjects(message.body, @"Harpier cries: 'tis time, 'tis time.");
        XCTAssertEqual(message.direction, XMPPMessageDirectionIncoming);
        XCTAssertEqualObjects(message.stanzaID, @"msg111");
        XCTAssertEqual(message.type, XMPPMessageTypeGroupchat);
        XCTAssertEqualObjects([message streamJID], [XMPPJID jidWithString:@"crone1@shakespeare.lit"]);
        XCTAssertEqualObjects([message streamTimestamp], [NSDate dateWithTimeIntervalSinceReferenceDate:0]);
    }];
}

- (void)testOutgoingRoomLightMessageHandling
{
    XMPPMessageCoreDataStorageObject *messageObject = [self.storage insertOutgoingMessageStorageObject];
    messageObject.stanzaID = @"msg111";
    [messageObject registerOutgoingMessageStreamEventID:@"eventID"];
    [self.storage.mainThreadManagedObjectContext save:NULL];
 
    XMPPMockStream *mockStream = [[XMPPMockStream alloc] init];
    mockStream.myJID = [XMPPJID jidWithString:@"hag66@shakespeare.lit/pda"];
    
    [self expectationForNotification:NSManagedObjectContextObjectsDidChangeNotification object:self.storage.mainThreadManagedObjectContext handler:nil];
    
    [self provideTransactionForFakeOutgoingMessageEventInStream:mockStream withID:@"eventID" timestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0] block:
     ^(XMPPMessageCoreDataStorageTransaction *transaction) {
         [transaction registerSentRoomLightMessage];
     }];
    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        XMPPMessageCoreDataStorageObject *messageObject = [XMPPMessageCoreDataStorageObject findWithUniqueStanzaID:@"msg111"
                                                                                            inManagedObjectContext:self.storage.mainThreadManagedObjectContext];
        
        XCTAssertEqualObjects([messageObject streamJID], [XMPPJID jidWithString:@"hag66@shakespeare.lit/pda"]);
        XCTAssertEqualObjects([messageObject streamTimestamp], [NSDate dateWithTimeIntervalSinceReferenceDate:0]);
    }];
}

- (void)testPingbackRoomLightMessageHandling
{
    XMPPMessageCoreDataStorageObject *sentMessageObject = [self.storage insertOutgoingMessageStorageObject];
    sentMessageObject.stanzaID = @"msg111";
    [self.storage.mainThreadManagedObjectContext save:NULL];
    
    XMPPMockStream *mockStream = [[XMPPMockStream alloc] init];
    
    XMPPMessage *pingbackMessage = [[XMPPMessage alloc] initWithXMLString:
                                    @"<message id='msg111' type='groupchat'"
                                    @"  from='coven@muclight.shakespeare.lit/hag66@shakespeare.lit'"
                                    @"  to='crone1@shakespeare.lit'>"
                                    @"  <body>Harpier cries: 'tis time, 'tis time.</body>"
                                    @"</message>"
                                                                    error:nil];
    
    [self expectationForNotification:NSManagedObjectContextObjectsDidChangeNotification
                              object:self.storage.mainThreadManagedObjectContext
                             handler:nil].inverted = YES;
    
    [self provideTransactionForFakeIncomingMessageEventInStream:mockStream withID:@"eventID" timestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0] block:
     ^(XMPPMessageCoreDataStorageTransaction *transaction) {
         [transaction storeReceivedRoomLightMessage:pingbackMessage];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testMyIncomingRoomLightMessageCheck
{
    XMPPMessageCoreDataStorageObject *myMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    myMessage.direction = XMPPMessageDirectionIncoming;
    myMessage.type = XMPPMessageTypeGroupchat;
    myMessage.fromJID = [XMPPJID jidWithString:@"coven@muclight.shakespeare.lit/hag66@shakespeare.lit"];
    [myMessage registerIncomingMessageStreamEventID:@"myMessageEventID"
                                        streamJID:[XMPPJID jidWithString:@"hag66@shakespeare.lit/pda"]
                             streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]];
    
    XMPPMessageCoreDataStorageObject *otherMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    otherMessage.direction = XMPPMessageDirectionIncoming;
    otherMessage.type = XMPPMessageTypeGroupchat;
    otherMessage.fromJID = [XMPPJID jidWithString:@"coven@muclight.shakespeare.lit/crone1@shakespeare.lit"];
    [otherMessage registerIncomingMessageStreamEventID:@"otherMessageEventID"
                                        streamJID:[XMPPJID jidWithString:@"hag66@shakespeare.lit/pda"]
                             streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]];
    
    XCTAssertTrue([myMessage isMyIncomingRoomLightMessage]);
    XCTAssertFalse([otherMessage isMyIncomingRoomLightMessage]);
}

- (void)testRoomLightMessageLookup
{
    XMPPMessageCoreDataStorageObject *matchingOutgoingMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    matchingOutgoingMessage.direction = XMPPMessageDirectionOutgoing;
    matchingOutgoingMessage.toJID = [XMPPJID jidWithString:@"coven@muclight.shakespeare.lit"];
    [matchingOutgoingMessage registerOutgoingMessageStreamEventID:@"eventID1"];
    [matchingOutgoingMessage registerOutgoingMessageStreamJID:[XMPPJID jidWithString:@"hag66@shakespeare.lit/pda"]
                                         streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]];
    
    XMPPMessageCoreDataStorageObject *otherOutgoingMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    otherOutgoingMessage.direction = XMPPMessageDirectionOutgoing;
    otherOutgoingMessage.toJID = [XMPPJID jidWithString:@"hag66@shakespeare.lit/pda"];
    [otherOutgoingMessage registerOutgoingMessageStreamEventID:@"eventID2"];
    [otherOutgoingMessage registerOutgoingMessageStreamJID:[XMPPJID jidWithString:@"hag66@shakespeare.lit/pda"]
                                      streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:1]];
    
    XMPPMessageCoreDataStorageObject *matchingIncomingMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    matchingIncomingMessage.direction = XMPPMessageDirectionIncoming;
    [matchingIncomingMessage registerIncomingMessageStreamEventID:@"eventID3"
                                                        streamJID:[XMPPJID jidWithString:@"hag66@shakespeare.lit/pda"]
                                             streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:2]];
    matchingIncomingMessage.fromJID = [XMPPJID jidWithString:@"coven@muclight.shakespeare.lit/hag66@shakespeare.lit"];
    
    XMPPMessageCoreDataStorageObject *otherIncomingMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    otherIncomingMessage.direction = XMPPMessageDirectionIncoming;
    [otherIncomingMessage registerIncomingMessageStreamEventID:@"eventID4"
                                                     streamJID:[XMPPJID jidWithString:@"hag66@shakespeare.lit/pda"]
                                          streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:3]];
    otherIncomingMessage.fromJID = [XMPPJID jidWithString:@"hag66@shakespeare.lit/pda"];
    
    NSPredicate *predicate =
    [XMPPMessageContextItemCoreDataStorageObject messageRemotePartyJIDPredicateWithValue:[XMPPJID jidWithString:@"coven@muclight.shakespeare.lit"]
                                                                          compareOptions:XMPPJIDCompareBare];
    NSFetchRequest *fetchRequest = [XMPPMessageContextItemCoreDataStorageObject requestByTimestampsWithPredicate:predicate
                                                                                                inAscendingOrder:YES
                                                                                        fromManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    
    NSArray<XMPPMessageContextItemCoreDataStorageObject *> *fetchResult =
    [self.storage.mainThreadManagedObjectContext xmpp_executeForcedSuccessFetchRequest:fetchRequest];
    
    XCTAssertEqual(fetchResult.count, 2);
    XCTAssertEqualObjects(fetchResult[0].message, matchingOutgoingMessage);
    XCTAssertEqualObjects(fetchResult[1].message, matchingIncomingMessage);
}

@end

@implementation XMPPMessageCoreDataStorageTests (XMPPDelayedDeliveryMessageStorage)

- (void)testDelayedDeliveryDirectStorage
{
    XMPPMessageCoreDataStorageObject *message =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    message.direction = XMPPMessageDirectionOutgoing;
    
    [message setDelayedDeliveryDate:[NSDate dateWithTimeIntervalSinceReferenceDate:0]
                               from:[XMPPJID jidWithString:@"domain"]
                  reasonDescription:@"Test"];
    
    XCTAssertEqualObjects([message delayedDeliveryDate], [NSDate dateWithTimeIntervalSinceReferenceDate:0]);
    XCTAssertEqualObjects([message delayedDeliveryFrom], [XMPPJID jidWithString:@"domain"]);
    XCTAssertEqualObjects([message delayedDeliveryReasonDescription], @"Test");
}

- (void)testDelayedDeliveryStreamEventHandling
{
    XMPPMockStream *mockStream = [[XMPPMockStream alloc] init];
    
    XMPPMessage *message = [[XMPPMessage alloc] initWithXMLString:
                            @"<message>"
                            @"  <delay xmlns='urn:xmpp:delay'"
                            @"     from='capulet.com'"
                            @"     stamp='2002-09-10T23:08:25Z'"
                            @"  >Offline Storage</delay>"
                            @"</message>"
                                                            error:nil];
    
    [self expectationForMainThreadStorageManagedObjectsChangeNotificationWithUserInfoKey:NSInsertedObjectsKey count:1 handler:
     ^BOOL(__kindof NSManagedObject *object) {
         return [object isKindOfClass:[XMPPMessageCoreDataStorageObject class]];
     }];
    
    [self provideTransactionForFakeIncomingMessageEventInStream:mockStream withID:@"eventID" timestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0] block:
     ^(XMPPMessageCoreDataStorageTransaction *transaction) {
         [transaction registerDelayedDeliveryForReceivedMessage:message];
     }];
    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        NSFetchRequest *fetchRequest = [XMPPMessageCoreDataStorageObject xmpp_fetchRequestInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
        NSArray<XMPPMessageCoreDataStorageObject *> *fetchResult =
        [self.storage.mainThreadManagedObjectContext xmpp_executeForcedSuccessFetchRequest:fetchRequest];
        
        XCTAssertEqual(fetchResult.count, 1);
        XCTAssertEqualObjects([fetchResult.firstObject delayedDeliveryDate], [NSDate dateWithXmppDateTimeString:@"2002-09-10T23:08:25Z"]);
        XCTAssertEqualObjects([fetchResult.firstObject delayedDeliveryFrom], [XMPPJID jidWithString:@"capulet.com"]);
        XCTAssertEqualObjects([fetchResult.firstObject delayedDeliveryReasonDescription], @"Offline Storage");
    }];
}

- (void)testDelayedDeliveryTimestampMessageContextFetch
{
    XMPPMessageCoreDataStorageObject *shorterDelayMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    shorterDelayMessage.direction = XMPPMessageDirectionOutgoing;
    [shorterDelayMessage registerOutgoingMessageStreamEventID:@"earlierEventID"];
    [shorterDelayMessage registerOutgoingMessageStreamJID:[XMPPJID jidWithString:@"juliet@example.com"]
                                     streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]];
    
    XMPPMessageCoreDataStorageObject *longerDelayMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    longerDelayMessage.direction = XMPPMessageDirectionOutgoing;
    [longerDelayMessage registerOutgoingMessageStreamEventID:@"laterEventID"];
    [longerDelayMessage registerOutgoingMessageStreamJID:[XMPPJID jidWithString:@"juliet@example.com"]
                                    streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:1]];
    
    [shorterDelayMessage setDelayedDeliveryDate:[NSDate dateWithTimeIntervalSinceReferenceDate:-1] from:nil reasonDescription:@"Shorter delay"];
    [longerDelayMessage setDelayedDeliveryDate:[NSDate dateWithTimeIntervalSinceReferenceDate:-2] from:nil reasonDescription:@"Longer delay"];
    
    NSPredicate *predicate = [XMPPMessageContextItemCoreDataStorageObject delayedDeliveryTimestampKindPredicate];
    NSFetchRequest *fetchRequest =
    [XMPPMessageContextItemCoreDataStorageObject requestByTimestampsWithPredicate:predicate
                                                                 inAscendingOrder:YES
                                                         fromManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    NSArray<XMPPMessageContextItemCoreDataStorageObject *> *result = [self.storage.mainThreadManagedObjectContext executeFetchRequest:fetchRequest
                                                                                                                                error:NULL];
    
    XCTAssertEqual(result.count, 2);
    XCTAssertEqualObjects(result[0].message, longerDelayMessage);
    XCTAssertEqualObjects(result[1].message, shorterDelayMessage);
}

- (void)testDelayedDeliveryStreamTimestampDisplacementMessageContextFetch
{
    XMPPMessageCoreDataStorageObject *liveMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    liveMessage.direction = XMPPMessageDirectionOutgoing;
    liveMessage.stanzaID = @"liveMessageID";
    [liveMessage registerOutgoingMessageStreamEventID:@"liveMessageEventID"];
    [liveMessage registerOutgoingMessageStreamJID:[XMPPJID jidWithString:@"juliet@example.com"]
                             streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]];
    
    XMPPMessageCoreDataStorageObject *delayedDeliveryMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    delayedDeliveryMessage.direction = XMPPMessageDirectionOutgoing;
    [delayedDeliveryMessage registerOutgoingMessageStreamEventID:@"delayedDeliveryMessageEventID"];
    [delayedDeliveryMessage registerOutgoingMessageStreamJID:[XMPPJID jidWithString:@"juliet@example.com"]
                                        streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:1]];
    
    [delayedDeliveryMessage setDelayedDeliveryDate:[NSDate dateWithTimeIntervalSinceReferenceDate:-1] from:nil reasonDescription:nil];
    
    NSPredicate *predicate =
    [NSCompoundPredicate orPredicateWithSubpredicates:@[[XMPPMessageContextItemCoreDataStorageObject streamTimestampKindPredicate],
                                                        [XMPPMessageContextItemCoreDataStorageObject delayedDeliveryTimestampKindPredicate]]];
    NSFetchRequest *fetchRequest =
    [XMPPMessageContextItemCoreDataStorageObject requestByTimestampsWithPredicate:predicate
                                                                 inAscendingOrder:YES
                                                         fromManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    NSArray<XMPPMessageContextItemCoreDataStorageObject *> *result = [self.storage.mainThreadManagedObjectContext executeFetchRequest:fetchRequest
                                                                                                                                error:NULL];
    
    XCTAssertEqual(result.count, 2);
    XCTAssertEqualObjects(result[0].message, delayedDeliveryMessage);
    XCTAssertEqualObjects(result[1].message, liveMessage);
}

@end

@implementation XMPPMessageCoreDataStorageTests (XMPPMessageArchiveManagementLocalStorage)

- (void)testMessageArchiveBasicStorage
{
    XMPPMockStream *mockStream = [[XMPPMockStream alloc] init];
    NSXMLElement *resultItem = [self fakeMessageArchiveResultItemWithID:@"28482-98726-73623" includingPayload:YES];
    
    [self expectationForMainThreadStorageManagedObjectsChangeNotificationWithUserInfoKey:NSInsertedObjectsKey count:1 handler:
     ^BOOL(__kindof NSManagedObject *object) {
         return [object isKindOfClass:[XMPPMessageCoreDataStorageObject class]];
     }];
    
    [self provideTransactionForFakeIncomingMessageEventInStream:mockStream withID:@"eventID" timestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0] block:
     ^(XMPPMessageCoreDataStorageTransaction *transaction) {
         [transaction storeMessageArchiveQueryResultItem:resultItem inMode:XMPPMessageArchiveQueryResultStorageModeComplete];
     }];
    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        NSFetchRequest *fetchRequest = [XMPPMessageCoreDataStorageObject xmpp_fetchRequestInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
        NSArray<XMPPMessageCoreDataStorageObject *> *fetchResult =
        [self.storage.mainThreadManagedObjectContext xmpp_executeForcedSuccessFetchRequest:fetchRequest];
        
        XCTAssertEqual(fetchResult.count, 1);
        XCTAssertEqualObjects([fetchResult.firstObject messageArchiveID], @"28482-98726-73623");
        XCTAssertEqualObjects([fetchResult.firstObject messageArchiveDate], [NSDate dateWithXmppDateTimeString:@"2010-07-10T23:08:25Z"]);
        XCTAssertEqualObjects([fetchResult.firstObject body], @"Hail to thee");
    }];
}

- (void)testMessageArchivePartialResultPageTimestampContextFetch
{
    XMPPMockStream *mockStream = [[XMPPMockStream alloc] init];
    NSXMLElement *resultItem = [self fakeMessageArchiveResultItemWithID:@"28482-98726-73623" includingPayload:YES];
    
    [self expectationForMainThreadStorageManagedObjectsChangeNotificationWithUserInfoKey:NSInsertedObjectsKey count:1 handler:
     ^BOOL(__kindof NSManagedObject *object) {
         return [object isKindOfClass:[XMPPMessageCoreDataStorageObject class]];
     }];
    
    [self provideTransactionForFakeIncomingMessageEventInStream:mockStream withID:@"eventID" timestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0] block:
     ^(XMPPMessageCoreDataStorageTransaction *transaction) {
         [transaction storeMessageArchiveQueryResultItem:resultItem inMode:XMPPMessageArchiveQueryResultStorageModeMetadataOnly];
     }];
    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        NSPredicate *predicate = [XMPPMessageContextItemCoreDataStorageObject
                                  messageArchiveTimestampKindPredicateWithOptions:XMPPMessageArchiveTimestampContextIncludingPartialResultPages];
        NSFetchRequest *fetchRequest =
        [XMPPMessageContextItemCoreDataStorageObject requestByTimestampsWithPredicate:predicate
                                                                     inAscendingOrder:YES
                                                             fromManagedObjectContext:self.storage.mainThreadManagedObjectContext];
        NSArray<XMPPMessageContextItemCoreDataStorageObject *> *fetchResult =
        [self.storage.mainThreadManagedObjectContext xmpp_executeForcedSuccessFetchRequest:fetchRequest];
        
        XCTAssertEqual(fetchResult.count, 1);
        XCTAssertEqualObjects([fetchResult.firstObject.message messageArchiveID], @"28482-98726-73623");
    }];
}

- (void)testMessageArchiveFinalizedResultPageTimestampContextFetch
{
    XMPPMockStream *mockStream = [[XMPPMockStream alloc] init];
    NSXMLElement *partialResultPageItem = [self fakeMessageArchiveResultItemWithID:@"partialResultPageArchiveID" includingPayload:YES];
    NSXMLElement *completeResultPageItem = [self fakeMessageArchiveResultItemWithID:@"completeResultPageArchiveID" includingPayload:YES];
    
    for (NSString *messageID in @[@"partialResultPageArchiveID", @"completeResultPageArchiveID"]) {
        [self expectationForMainThreadStorageManagedObjectsChangeNotificationWithUserInfoKey:NSInsertedObjectsKey count:1 handler:
         ^BOOL(__kindof NSManagedObject *object) {
             return [object isKindOfClass:[XMPPMessageCoreDataStorageObject class]] && [[object messageArchiveID] isEqualToString:messageID];
         }];
    }
    
    [self provideTransactionForFakeIncomingMessageEventInStream:mockStream
                                                         withID:@"partialResultPageEventID"
                                                      timestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]
                                                          block:
     ^(XMPPMessageCoreDataStorageTransaction *transaction) {
         [transaction storeMessageArchiveQueryResultItem:partialResultPageItem inMode:XMPPMessageArchiveQueryResultStorageModeMetadataOnly];
     }];
    
    [self provideTransactionForFakeIncomingMessageEventInStream:mockStream
                                                         withID:@"completeResultPageEventID"
                                                      timestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]
                                                          block:
     ^(XMPPMessageCoreDataStorageTransaction *transaction) {
         [transaction storeMessageArchiveQueryResultItem:completeResultPageItem inMode:XMPPMessageArchiveQueryResultStorageModeMetadataOnly];
     }];
    
    [self waitForExpectationsWithTimeout:5 handler:nil];
    
    [self expectationForNotification:NSManagedObjectContextObjectsDidChangeNotification object:self.storage.mainThreadManagedObjectContext handler:nil];
    
    [self.storage finalizeResultSetPageWithMessageArchiveIDs:@[@"completeResultPageArchiveID"]];
    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        NSPredicate *predicate = [XMPPMessageContextItemCoreDataStorageObject messageArchiveTimestampKindPredicateWithOptions:0];
        NSFetchRequest *fetchRequest =
        [XMPPMessageContextItemCoreDataStorageObject requestByTimestampsWithPredicate:predicate
                                                                     inAscendingOrder:YES
                                                             fromManagedObjectContext:self.storage.mainThreadManagedObjectContext];
        NSArray<XMPPMessageContextItemCoreDataStorageObject *> *fetchResult =
        [self.storage.mainThreadManagedObjectContext xmpp_executeForcedSuccessFetchRequest:fetchRequest];
        
        XCTAssertEqual(fetchResult.count, 1);
        XCTAssertEqualObjects([fetchResult.firstObject.message messageArchiveID], @"completeResultPageArchiveID");
    }];
}

- (void)testMessageArchiveDeletedResultItemTimestampContextFetch
{
    XMPPMockStream *mockStream = [[XMPPMockStream alloc] init];
    NSXMLElement *resultItem = [self fakeMessageArchiveResultItemWithID:@"partialResultPageArchiveID" includingPayload:YES];
    NSXMLElement *resultPlaceholderItem = [self fakeMessageArchiveResultItemWithID:@"deletedResultItemArchiveID" includingPayload:NO];
    
    for (NSString *archiveID in @[@"partialResultPageArchiveID", @"deletedResultItemArchiveID"]) {
        [self expectationForMainThreadStorageManagedObjectsChangeNotificationWithUserInfoKey:NSInsertedObjectsKey count:1 handler:
         ^BOOL(__kindof NSManagedObject *object) {
             return [object isKindOfClass:[XMPPMessageCoreDataStorageObject class]] && [[object messageArchiveID] isEqualToString:archiveID];
         }];
    }
    
    [self provideTransactionForFakeIncomingMessageEventInStream:mockStream
                                                         withID:@"partialResultPageEventID"
                                                      timestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]
                                                          block:
     ^(XMPPMessageCoreDataStorageTransaction *transaction) {
         [transaction storeMessageArchiveQueryResultItem:resultItem inMode:XMPPMessageArchiveQueryResultStorageModeMetadataOnly];
     }];
    
    [self provideTransactionForFakeIncomingMessageEventInStream:mockStream
                                                         withID:@"deletedResultItemEventID"
                                                      timestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]
                                                          block:
     ^(XMPPMessageCoreDataStorageTransaction *transaction) {
         [transaction storeMessageArchiveQueryResultItem:resultPlaceholderItem inMode:XMPPMessageArchiveQueryResultStorageModeMetadataOnly];
     }];
    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        NSPredicate *predicate = [XMPPMessageContextItemCoreDataStorageObject
                                  messageArchiveTimestampKindPredicateWithOptions:XMPPMessageArchiveTimestampContextIncludingDeletedResultItems];
        NSFetchRequest *fetchRequest =
        [XMPPMessageContextItemCoreDataStorageObject requestByTimestampsWithPredicate:predicate
                                                                     inAscendingOrder:YES
                                                             fromManagedObjectContext:self.storage.mainThreadManagedObjectContext];
        NSArray<XMPPMessageContextItemCoreDataStorageObject *> *fetchResult =
        [self.storage.mainThreadManagedObjectContext xmpp_executeForcedSuccessFetchRequest:fetchRequest];
        
        XCTAssertEqual(fetchResult.count, 1);
        XCTAssertEqualObjects([fetchResult.firstObject.message messageArchiveID], @"deletedResultItemArchiveID");
    }];
}

- (void)testMessageArchiveDuplicateArchiveID
{
    XMPPMockStream *mockStream = [[XMPPMockStream alloc] init];
    NSXMLElement *resultItem = [self fakeMessageArchiveResultItemWithID:@"28482-98726-73623" includingPayload:YES];
    
    [self expectationForMainThreadStorageManagedObjectsChangeNotificationWithUserInfoKey:NSInsertedObjectsKey count:1 handler:
     ^BOOL(__kindof NSManagedObject *object) {
         return [object isKindOfClass:[XMPPMessageCoreDataStorageObject class]];
     }];
    
    [self provideTransactionForFakeIncomingMessageEventInStream:mockStream
                                                         withID:@"originalEventID"
                                                      timestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]
                                                          block:
     ^(XMPPMessageCoreDataStorageTransaction *transaction) {
         [transaction storeMessageArchiveQueryResultItem:resultItem inMode:XMPPMessageArchiveQueryResultStorageModeMetadataOnly];
     }];
    
    [self waitForExpectationsWithTimeout:5 handler:nil];
    
    [self expectationForMainThreadStorageManagedObjectsChangeNotificationWithUserInfoKey:NSInsertedObjectsKey count:1 handler:
     ^BOOL(__kindof NSManagedObject *object) {
         return [object isKindOfClass:[XMPPMessageCoreDataStorageObject class]];
     }].inverted = YES;
    
    [self provideTransactionForFakeIncomingMessageEventInStream:mockStream
                                                         withID:@"duplicateEventID"
                                                      timestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:1]
                                                          block:
     ^(XMPPMessageCoreDataStorageTransaction *transaction) {
         [transaction storeMessageArchiveQueryResultItem:resultItem inMode:XMPPMessageArchiveQueryResultStorageModeMetadataOnly];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testMessageArchiveDuplicateStanzaID
{
    XMPPMockStream *mockStream = [[XMPPMockStream alloc] init];
    
    XMPPMessageCoreDataStorageObject *liveMessageObject =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    liveMessageObject.direction = XMPPMessageDirectionIncoming;
    liveMessageObject.stanzaID = @"123";
    [self.storage.mainThreadManagedObjectContext save:NULL];
    
    NSXMLElement *resultItem = [self fakeMessageArchiveResultItemWithID:@"28482-98726-73623" includingPayload:YES];
    
    [self expectationForMainThreadStorageManagedObjectsChangeNotificationWithUserInfoKey:NSInsertedObjectsKey count:1 handler:
     ^BOOL(__kindof NSManagedObject *object) {
         return [object isKindOfClass:[XMPPMessageCoreDataStorageObject class]];
     }].inverted = YES;
    
    [self provideTransactionForFakeIncomingMessageEventInStream:mockStream
                                                         withID:@"archivedMessageEventID"
                                                      timestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]
                                                          block:
     ^(XMPPMessageCoreDataStorageTransaction *transaction) {
         [transaction storeMessageArchiveQueryResultItem:resultItem inMode:XMPPMessageArchiveQueryResultStorageModeMetadataOnly];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testMessageArchiveStreamTimestampDisplacementContextFetch
{
    XMPPMockStream *mockStream = [[XMPPMockStream alloc] init];
    
    XMPPMessageCoreDataStorageObject *liveMessageObject =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    liveMessageObject.direction = XMPPMessageDirectionIncoming;
    liveMessageObject.stanzaID = @"liveMessageID";
    [liveMessageObject registerIncomingMessageStreamEventID:@"liveMessageEventID"
                                                  streamJID:mockStream.myJID
                                       streamEventTimestamp:[NSDate dateWithXmppDateTimeString:@"2010-07-10T23:08:26Z"]];
    [self.storage.mainThreadManagedObjectContext save:NULL];
    
    NSXMLElement *resultItem = [self fakeMessageArchiveResultItemWithID:@"28482-98726-73623" includingPayload:YES];
    
    [self expectationForMainThreadStorageManagedObjectsChangeNotificationWithUserInfoKey:NSInsertedObjectsKey count:1 handler:
     ^BOOL(__kindof NSManagedObject *object) {
         return [object isKindOfClass:[XMPPMessageCoreDataStorageObject class]];
     }];
    
    [self provideTransactionForFakeIncomingMessageEventInStream:mockStream
                                                         withID:@"archivedMessageEventID"
                                                      timestamp:[NSDate dateWithXmppDateTimeString:@"2010-07-10T23:08:27Z"]
                                                          block:
     ^(XMPPMessageCoreDataStorageTransaction *transaction) {
         [transaction storeMessageArchiveQueryResultItem:resultItem inMode:XMPPMessageArchiveQueryResultStorageModeMetadataOnly];
     }];
    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        NSPredicate *streamTimestampPredicate = [XMPPMessageContextItemCoreDataStorageObject streamTimestampKindPredicate];
        NSPredicate *messageArchiveTimestampPredicate =
        [XMPPMessageContextItemCoreDataStorageObject
         messageArchiveTimestampKindPredicateWithOptions:XMPPMessageArchiveTimestampContextIncludingPartialResultPages];
        NSPredicate *predicate = [NSCompoundPredicate orPredicateWithSubpredicates:@[streamTimestampPredicate, messageArchiveTimestampPredicate]];
        
        NSFetchRequest *fetchRequest =
        [XMPPMessageContextItemCoreDataStorageObject requestByTimestampsWithPredicate:predicate
                                                                     inAscendingOrder:YES
                                                             fromManagedObjectContext:self.storage.mainThreadManagedObjectContext];
        NSArray<XMPPMessageContextItemCoreDataStorageObject *> *result = [self.storage.mainThreadManagedObjectContext executeFetchRequest:fetchRequest
                                                                                                                                    error:NULL];
        
        XCTAssertEqual(result.count, 2);
        XCTAssertEqualObjects([result[0].message messageArchiveID], @"28482-98726-73623");
        XCTAssertEqualObjects(result[1].message.stanzaID, @"liveMessageID");
    }];
}

- (void)testMyArchivedChatMessage
{
    XMPPMockStream *mockStream = [[XMPPMockStream alloc] init];
    mockStream.myJID = [XMPPJID jidWithString:@"witch@shakespeare.lit"];
    
    NSXMLElement *resultItem = [self fakeMessageArchiveResultItemWithID:@"28482-98726-73623" includingPayload:YES];
    
    [self expectationForMainThreadStorageManagedObjectsChangeNotificationWithUserInfoKey:NSInsertedObjectsKey count:1 handler:
     ^BOOL(__kindof NSManagedObject *object) {
         return [object isKindOfClass:[XMPPMessageCoreDataStorageObject class]];
     }];
    
    [self provideTransactionForFakeIncomingMessageEventInStream:mockStream withID:@"eventID" timestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0] block:
     ^(XMPPMessageCoreDataStorageTransaction *transaction) {
         [transaction storeMessageArchiveQueryResultItem:resultItem inMode:XMPPMessageArchiveQueryResultStorageModeComplete];
     }];
    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        NSFetchRequest *fetchRequest = [XMPPMessageCoreDataStorageObject xmpp_fetchRequestInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
        NSArray<XMPPMessageCoreDataStorageObject *> *fetchResult =
        [self.storage.mainThreadManagedObjectContext xmpp_executeForcedSuccessFetchRequest:fetchRequest];
        
        XCTAssertEqual(fetchResult.count, 1);
        XCTAssertTrue([fetchResult.firstObject isMyArchivedChatMessage]);
    }];
}

- (NSXMLElement *)fakeMessageArchiveResultItemWithID:(NSString *)messageArchiveID includingPayload:(BOOL)shouldIncludePayload
{
    NSMutableString *resultItemString = [[NSMutableString alloc] init];
    [resultItemString appendFormat:@"<result xmlns='urn:xmpp:mam:2' queryid='f27' id='%@'>", messageArchiveID];
    [resultItemString appendString:@"  <forwarded xmlns='urn:xmpp:forward:0'>"
                                   @"    <delay xmlns='urn:xmpp:delay' stamp='2010-07-10T23:08:25Z'/>"];
    if (shouldIncludePayload) {
        [resultItemString appendString:@"<message xmlns='jabber:client' type='chat' id='123' from='witch@shakespeare.lit' to='macbeth@shakespeare.lit'>"
                                       @"  <body>Hail to thee</body>"
                                       @"</message>"];
    }
    [resultItemString appendString:@"  </forwarded>"
                                   @"</result>"];
    
    return [[NSXMLElement alloc] initWithXMLString:resultItemString error:NULL];
}

@end

@implementation XMPPMessageCoreDataStorageTests (XMPPManagedMessagingStorage)

- (void)testManagedMessagingPlainMessageUnspecifiedStatus
{
    XMPPMessageCoreDataStorageObject *message =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    XCTAssertEqual([message managedMessagingStatus], XMPPManagedMessagingStatusUnspecified);
}

- (void)testManagedMessagingOutgoingMessageRegistration
{
    XMPPMessageCoreDataStorageObject *message =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    message.direction = XMPPMessageDirectionOutgoing;
    [message registerOutgoingMessageStreamEventID:@"managedMessageEventID"];
    [self.storage.mainThreadManagedObjectContext save:NULL];
    
    [self expectationForNotification:NSManagedObjectContextObjectsDidChangeNotification object:self.storage.mainThreadManagedObjectContext handler:nil];
    
    [self provideTransactionForFakeOutgoingMessageEventInStream:[[XMPPMockStream alloc] init]
                                                         withID:@"managedMessageEventID"
                                                      timestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]
                                                          block:
     ^(XMPPMessageCoreDataStorageTransaction *transaction) {
         [transaction registerSentManagedMessage];
     }];
    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        XCTAssertEqual([message managedMessagingStatus], XMPPManagedMessagingStatusPendingAcknowledgement);
    }];
}

- (void)testManagedMessagingSentMessageConfirmation
{
    XMPPMessageCoreDataStorageObject *message =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    message.stanzaID = @"confirmedMessageID";
    message.direction = XMPPMessageDirectionOutgoing;
    [message registerOutgoingMessageStreamEventID:@"confirmedMessageEventID"];
    [self.storage.mainThreadManagedObjectContext save:NULL];

    [self expectationForNotification:NSManagedObjectContextObjectsDidChangeNotification object:self.storage.mainThreadManagedObjectContext handler:nil];

    [self provideTransactionForFakeOutgoingMessageEventInStream:[[XMPPMockStream alloc] init]
                                                         withID:@"confirmedMessageEventID"
                                                      timestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]
                                                          block:
     ^(XMPPMessageCoreDataStorageTransaction *transaction) {
         [transaction registerSentManagedMessage];
     }];

    [self waitForExpectationsWithTimeout:5 handler:nil];

    [self expectationForNotification:NSManagedObjectContextObjectsDidChangeNotification object:self.storage.mainThreadManagedObjectContext handler:nil];

    [self.storage registerAcknowledgedManagedMessageIDs:@[@"confirmedMessageID"]];

    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        XCTAssertEqual([message managedMessagingStatus], XMPPManagedMessagingStatusAcknowledged);
    }];
}

- (void)testManagedMessagingFailureRegistration
{
    XMPPMessageCoreDataStorageObject *message =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    message.direction = XMPPMessageDirectionOutgoing;
    [message registerOutgoingMessageStreamEventID:@"unconfirmedMessageEventID"];
    [self.storage.mainThreadManagedObjectContext save:NULL];

    [self expectationForNotification:NSManagedObjectContextObjectsDidChangeNotification object:self.storage.mainThreadManagedObjectContext handler:nil];

    [self provideTransactionForFakeOutgoingMessageEventInStream:[[XMPPMockStream alloc] init]
                                                         withID:@"unconfirmedMessageEventID"
                                                      timestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]
                                                          block:
     ^(XMPPMessageCoreDataStorageTransaction *transaction) {
         [transaction registerSentManagedMessage];
     }];

    [self waitForExpectationsWithTimeout:5 handler:nil];

    [self expectationForNotification:NSManagedObjectContextObjectsDidChangeNotification object:self.storage.mainThreadManagedObjectContext handler:nil];

    [self.storage registerFailureForUnacknowledgedManagedMessages];

    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        XCTAssertEqual([message managedMessagingStatus], XMPPManagedMessagingStatusUnacknowledged);
    }];
}

@end

@implementation XMPPMessageCoreDataStorageTests (XMPPMessageDeliveryReceiptsStorage)

- (void)testMessageDeliveryReceiptStorage
{
    XMPPMessageCoreDataStorageObject *fakeSentMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    fakeSentMessage.stanzaID = @"richard2-4.1.247";
    [self.storage.mainThreadManagedObjectContext save:NULL];
    
    [self expectationForMainThreadStorageManagedObjectsChangeNotificationWithUserInfoKey:NSInsertedObjectsKey count:1 handler:
     ^BOOL(__kindof NSManagedObject *object) {
         return [object isKindOfClass:[XMPPMessageCoreDataStorageObject class]];
     }];
    
    [self provideTransactionForFakeIncomingMessageEventInStream:[[XMPPMockStream alloc] init]
                                                         withID:@"deliveryReceiptEventID"
                                                      timestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]
                                                          block:
     ^(XMPPMessageCoreDataStorageTransaction *transaction) {
         [transaction storeReceivedDeliveryReceiptResponseMessage:[self fakeDeliveryReceiptResponseMessage]];
     }];
    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        XCTAssertTrue([fakeSentMessage hasAssociatedDeliveryReceiptResponseMessage]);
        
        XMPPMessageCoreDataStorageObject *deliveryReceiptMessage =
        [XMPPMessageCoreDataStorageObject findWithUniqueStanzaID:@"bi29sg183b4v"
                                          inManagedObjectContext:self.storage.mainThreadManagedObjectContext];
        XCTAssertEqualObjects([deliveryReceiptMessage messageDeliveryReceiptResponseID], @"richard2-4.1.247");
    }];
}

- (void)testMessageDeliveryReceiptLookup
{
    XMPPMessageCoreDataStorageObject *fakeSentMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    fakeSentMessage.stanzaID = @"richard2-4.1.247";
    [self.storage.mainThreadManagedObjectContext save:NULL];
    
    [self expectationForMainThreadStorageManagedObjectsChangeNotificationWithUserInfoKey:NSInsertedObjectsKey count:1 handler:
     ^BOOL(__kindof NSManagedObject *object) {
         return [object isKindOfClass:[XMPPMessageCoreDataStorageObject class]];
     }];

    [self provideTransactionForFakeIncomingMessageEventInStream:[[XMPPMockStream alloc] init]
                                                         withID:@"deliveryReceiptEventID"
                                                      timestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]
                                                          block:
     ^(XMPPMessageCoreDataStorageTransaction *transaction) {
         [transaction storeReceivedDeliveryReceiptResponseMessage:[self fakeDeliveryReceiptResponseMessage]];
     }];

    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        XMPPMessageCoreDataStorageObject *deliveryReceiptMessage =
        [XMPPMessageCoreDataStorageObject findDeliveryReceiptResponseForMessageWithID:@"richard2-4.1.247"
                                                               inManagedObjectContext:self.storage.mainThreadManagedObjectContext];
        XCTAssertEqualObjects(deliveryReceiptMessage.stanzaID, @"bi29sg183b4v");
    }];
}

- (XMPPMessage *)fakeDeliveryReceiptResponseMessage
{
    return [[XMPPMessage alloc] initWithXMLString:
            @"<message"
            @"    from='kingrichard@royalty.england.lit/throne'"
            @"    id='bi29sg183b4v'"
            @"    to='northumberland@shakespeare.lit/westminster'>"
            @"  <received xmlns='urn:xmpp:receipts' id='richard2-4.1.247'/>"
            @"</message>"
                                            error:NULL];
}

@end

@implementation XMPPMessageCoreDataStorageTests (XMPPOutOfBandResourceMessagingStorage)

- (void)testOutOfBandResourceAssignment
{
    XMPPMessageCoreDataStorageObject *resourceWithDescriptionMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    resourceWithDescriptionMessage.direction = XMPPMessageDirectionOutgoing;
    
    XMPPMessageCoreDataStorageObject *resourceWithoutDescriptionMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    resourceWithoutDescriptionMessage.direction = XMPPMessageDirectionOutgoing;
    
    [resourceWithDescriptionMessage assignOutOfBandResourceWithInternalID:@"resourceID1" description:@"A license to Jabber!"];
    [resourceWithoutDescriptionMessage assignOutOfBandResourceWithInternalID:@"resourceID2" description:nil];
    
    XCTAssertEqualObjects([resourceWithDescriptionMessage outOfBandResourceInternalID], @"resourceID1");
    XCTAssertEqualObjects([resourceWithDescriptionMessage outOfBandResourceDescription], @"A license to Jabber!");
    XCTAssertEqualObjects([resourceWithoutDescriptionMessage outOfBandResourceInternalID], @"resourceID2");
    XCTAssertNil([resourceWithoutDescriptionMessage outOfBandResourceDescription]);
}

- (void)testOutOfBandResourceURIRegistration
{
    XMPPMessageCoreDataStorageObject *message =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    message.direction = XMPPMessageDirectionOutgoing;
    
    [message assignOutOfBandResourceWithInternalID:@"resourceID1" description:@"A license to Jabber!"];
    [message setAssignedOutOfBandResourceURIString:@"http://www.jabber.org/images/psa-license.jpg"];
    
    XCTAssertEqualObjects([message outOfBandResourceURIString], @"http://www.jabber.org/images/psa-license.jpg");
}

- (void)testOutOfBandResourceIncomingMessageStorage
{
    XMPPMessage *outOfBandResourceMessage = [[XMPPMessage alloc] initWithXMLString:
                                             @"<message from='stpeter@jabber.org/work'"
                                             @"         to='MaineBoy@jabber.org/home'>"
                                             @"  <body>Yeah, but do you have a license to Jabber?</body>"
                                             @"  <x xmlns='jabber:x:oob'>"
                                             @"    <url>http://www.jabber.org/images/psa-license.jpg</url>"
                                             @"    <desc>A license to Jabber!</desc>"
                                             @"  </x>"
                                             @"</message>"
                                                                             error:NULL];
    
    [self expectationForMainThreadStorageManagedObjectsChangeNotificationWithUserInfoKey:NSInsertedObjectsKey count:1 handler:
     ^BOOL(__kindof NSManagedObject *object) {
         return [object isKindOfClass:[XMPPMessageCoreDataStorageObject class]];
     }];
    
    [self provideTransactionForFakeIncomingMessageEventInStream:[[XMPPMockStream alloc] init]
                                                         withID:@"eventID"
                                                      timestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]
                                                          block:
     ^(XMPPMessageCoreDataStorageTransaction *transaction) {
         [transaction registerOutOfBandResourceForReceivedMessage:outOfBandResourceMessage];
     }];
    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        NSFetchRequest *fetchRequest = [XMPPMessageCoreDataStorageObject xmpp_fetchRequestInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
        NSArray<XMPPMessageCoreDataStorageObject *> *fetchResult =
        [self.storage.mainThreadManagedObjectContext xmpp_executeForcedSuccessFetchRequest:fetchRequest];
        
        XCTAssertEqual(fetchResult.count, 1);
        XCTAssertNotNil([fetchResult.firstObject outOfBandResourceInternalID]);
        XCTAssertEqualObjects([fetchResult.firstObject outOfBandResourceURIString], @"http://www.jabber.org/images/psa-license.jpg");
        XCTAssertEqualObjects([fetchResult.firstObject outOfBandResourceDescription], @"A license to Jabber!");
    }];
}

@end

@implementation XMPPMessageCoreDataStorageTests (XMPPLastMessageCorrectionStorage)

- (void)testMessageCorrectionDirectStorage
{
    XMPPMessageCoreDataStorageObject *originalMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    originalMessage.stanzaID = @"originalMessageID";
    
    XMPPMessageCoreDataStorageObject *correctedMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    correctedMessage.direction = XMPPMessageDirectionOutgoing;
    [correctedMessage assignMessageCorrectionID:@"originalMessageID"];
    
    XCTAssertTrue([originalMessage hasAssociatedCorrectionMessage]);
    XCTAssertEqualObjects([correctedMessage messageCorrectionID], @"originalMessageID");
}

- (void)testMessageCorrectionStreamEventHandling
{
    XMPPMessageCoreDataStorageObject *originalMessageObject =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    originalMessageObject.stanzaID = @"originalMessageID";
    [self.storage.mainThreadManagedObjectContext save:NULL];
    
    XMPPMessage *correctedMessage = [self fakeCorrectedMessageWithOriginalMessageID:@"originalMessageID"];
    
    [self expectationForMainThreadStorageManagedObjectsChangeNotificationWithUserInfoKey:NSInsertedObjectsKey count:1 handler:
     ^BOOL(__kindof NSManagedObject *object) {
         return [object isKindOfClass:[XMPPMessageCoreDataStorageObject class]];
     }];
    
    [self provideTransactionForFakeIncomingMessageEventInStream:[[XMPPMockStream alloc] init]
                                                         withID:@"messageCorrectionEventID"
                                                      timestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]
                                                          block:
     ^(XMPPMessageCoreDataStorageTransaction *transaction) {
         [transaction registerOriginalMessageIDForReceivedCorrectedMessage:correctedMessage];
     }];

    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        XMPPMessageCoreDataStorageObject *correctedMessage =
        [XMPPMessageCoreDataStorageObject findWithStreamEventID:@"messageCorrectionEventID" inManagedObjectContext:self.storage.mainThreadManagedObjectContext];
        
        XCTAssertTrue([originalMessageObject hasAssociatedCorrectionMessage]);
        XCTAssertEqualObjects([correctedMessage messageCorrectionID], originalMessageObject.stanzaID);
    }];
}

- (void)testMessageCorrectionLookup
{
    XMPPMessageCoreDataStorageObject *originalMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    originalMessage.stanzaID = @"originalMessageID";
    
    XMPPMessageCoreDataStorageObject *correctedMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    correctedMessage.direction = XMPPMessageDirectionOutgoing;
    [correctedMessage assignMessageCorrectionID:@"originalMessageID"];

    XMPPMessageCoreDataStorageObject *lookedUpCorrectedMessage =
    [XMPPMessageCoreDataStorageObject findCorrectionForMessageWithID:@"originalMessageID" inManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    
    XCTAssertEqualObjects(correctedMessage, lookedUpCorrectedMessage);
}

- (void)testMessageCorrectionStreamContextFetch
{
    XMPPMessageCoreDataStorageObject *originalMessageObject =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    originalMessageObject.direction = XMPPMessageDirectionIncoming;
    originalMessageObject.stanzaID = @"originalMessageID";
    [originalMessageObject registerIncomingMessageStreamEventID:@"originalMessageEventID"
                                                      streamJID:[[XMPPMockStream alloc] init].myJID
                                           streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]];
    [self.storage.mainThreadManagedObjectContext save:NULL];
    
    XMPPMessage *correctedMessage = [self fakeCorrectedMessageWithOriginalMessageID:@"originalMessageID"];
    
    [self expectationForMainThreadStorageManagedObjectsChangeNotificationWithUserInfoKey:NSInsertedObjectsKey count:1 handler:
     ^BOOL(__kindof NSManagedObject *object) {
         return [object isKindOfClass:[XMPPMessageCoreDataStorageObject class]];
     }];
    
    [self provideTransactionForFakeIncomingMessageEventInStream:[[XMPPMockStream alloc] init]
                                                         withID:@"messageCorrectionEventID"
                                                      timestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:1]
                                                          block:
     ^(XMPPMessageCoreDataStorageTransaction *transaction) {
         [transaction registerOriginalMessageIDForReceivedCorrectedMessage:correctedMessage];
     }];
    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        NSFetchRequest *fetchRequest =
        [XMPPMessageContextItemCoreDataStorageObject requestByTimestampsWithPredicate:[XMPPMessageContextItemCoreDataStorageObject streamTimestampKindPredicate]
                                                                     inAscendingOrder:YES
                                                             fromManagedObjectContext:self.storage.mainThreadManagedObjectContext];
        NSArray<XMPPMessageContextItemCoreDataStorageObject *> *fetchResult =
        [self.storage.mainThreadManagedObjectContext xmpp_executeForcedSuccessFetchRequest:fetchRequest];
        
        XCTAssertEqual(fetchResult.count, 1);
        XCTAssertEqualObjects(fetchResult.firstObject.message, originalMessageObject);
    }];
}

- (XMPPMessage *)fakeCorrectedMessageWithOriginalMessageID:(NSString *)originalMessageID
{
    return [[XMPPMessage alloc] initWithXMLString:
            [NSString stringWithFormat:
             @"<message to='juliet@capulet.net/balcony' id='good1'>"
             @"  <body>But soft, what light through yonder window breaks?</body>"
             @"  <replace id='%@' xmlns='urn:xmpp:message-correct:0'/>"
             @"</message>", originalMessageID]
                                            error:NULL];
}

@end

@implementation XMPPMessageCoreDataStorageTests (XEP_0245)

- (void)testMeCommandPrefixDetection
{
    XMPPMessageCoreDataStorageObject *meCommandMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    meCommandMessage.body = @"/me shrugs in disgust";
    
    XMPPMessageCoreDataStorageObject *plainMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    plainMessage.body = @"Atlas shrugs in disgust";
    
    XMPPMessageCoreDataStorageObject *nonAnchoredMePrefixMessage =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    nonAnchoredMePrefixMessage.body = @" /me shrugs in disgust";
    
    XCTAssertEqualObjects([meCommandMessage meCommandText], @"shrugs in disgust");
    XCTAssertNil([plainMessage meCommandText]);
    XCTAssertNil([nonAnchoredMePrefixMessage meCommandText]);
}

- (void)testIncomingMessageMeCommandSubjectJID
{
    XMPPMessageCoreDataStorageObject *message =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    message.fromJID = [XMPPJID jidWithString:@"olympians@chat.gods.lit/Atlas"];
    message.body = @"/me shrugs in disgust";
    
    XCTAssertEqualObjects([message meCommandSubjectJID], [XMPPJID jidWithString:@"olympians@chat.gods.lit/Atlas"]);
}

- (void)testOutgoingMessageMeCommandSubjectJID
{
    XMPPMessageCoreDataStorageObject *message =
    [XMPPMessageCoreDataStorageObject xmpp_insertNewObjectInManagedObjectContext:self.storage.mainThreadManagedObjectContext];
    message.direction = XMPPMessageDirectionOutgoing;
    message.body = @"/me shrugs in disgust";
    [message registerOutgoingMessageStreamEventID:@"eventID"];
    [message registerOutgoingMessageStreamJID:[XMPPJID jidWithString:@"atlas@chat.gods.lit"]
                             streamEventTimestamp:[NSDate dateWithTimeIntervalSinceReferenceDate:0]];
    
    XCTAssertEqualObjects([message meCommandSubjectJID], [XMPPJID jidWithString:@"atlas@chat.gods.lit"]);
}

@end
