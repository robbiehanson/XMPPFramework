//
//  XMPPLastActivityTest.m
//  XMPPFramework-Tests-Mac
//
//  Created by Daniel Rodríguez Troitiño on 02/02/13.
//  Copyright (c) 2013 XMPPFramework. All rights reserved.
//

#import <GHUnit/GHUnit.h>
#import <OCMock/OCMock.h>

#import "XMPPFramework.h"

@interface XMPPLastActivityDelegateMock : NSObject <XMPPLastActivityDelegate>

@property (nonatomic, copy) void (^xmppLastActivityDidReceiveResponseHandler)(XMPPLastActivity *sender, XMPPIQ *iq);
@property (nonatomic, copy) void (^xmppLastActivityDidNotReceiveResponseDueToTimeoutHandler)(XMPPLastActivity *sender, NSString *queryID, NSTimeInterval timeout);
@property (nonatomic, copy) NSUInteger (^numberOfIdleTimeSecondsForXMPPLastActivityQueryIQCurrentIdleTimeSeconds)(XMPPLastActivity *sender, XMPPIQ *iq, NSUInteger idleSeconds);

@end


@interface XMPPLastActivityTest : GHTestCase

@end


@implementation XMPPLastActivityTest

- (void)testRespondsToQueriesDefaultToYES
{
    XMPPLastActivity *module = [[XMPPLastActivity alloc] init];

    GHAssertTrue(module.respondsToQueries, nil);
}

- (void)testRespondsToQueriesCanBeSetToNO
{
    id stream = [OCMockObject mockForClass:[XMPPStream class]];
    XMPPLastActivity *module = [[XMPPLastActivity alloc] init];
    [module setValue:stream forKey:@"xmppStream"];

#ifdef _XMPP_CAPABILITIES_H
    [[stream expect] resendMyPresence];
#endif

    module.respondsToQueries = NO;

    GHAssertFalse(module.respondsToQueries, nil);

    [stream verify];
}

- (void)testActivate
{
    id stream = [OCMockObject mockForClass:[XMPPStream class]];
    XMPPLastActivity *module = [[XMPPLastActivity alloc] init];
    dispatch_queue_t moduleQueue = module.moduleQueue;

    [[stream expect] addDelegate:module delegateQueue:moduleQueue];
    [[stream expect] registerModule:module];

#ifdef _XMPP_CAPABILITIES_H
    [[stream expect] autoAddDelegate:module delegateQueue:moduleQueue toModulesOfClass:[XMPPCapabilities class]];
#endif

    [module activate:stream];

    GHAssertEquals(module.xmppStream, stream, nil);

    [stream verify];
}

- (void)testDeactivate
{
    id stream = [OCMockObject mockForClass:[XMPPStream class]];
    XMPPLastActivity *module = [[XMPPLastActivity alloc] init];
    dispatch_queue_t moduleQueue = module.moduleQueue;
    [module setValue:stream forKey:@"xmppStream"];

#ifdef _XMPP_CAPABILITIES_H
    [[stream expect] removeAutoDelegate:module delegateQueue:moduleQueue fromModulesOfClass:[XMPPCapabilities class]];
#endif

    [[stream expect] removeDelegate:module delegateQueue:moduleQueue];
    [[stream expect] unregisterModule:module];

    [module deactivate];

    GHAssertNil(module.xmppStream, nil);

    [stream verify];
}

- (void)testSendLastActivityQueryToWithTimeoutReceivingResponse
{
    XMPPJID *romeo = [XMPPJID jidWithString:@"romeo@montague.net/orchard"];
    XMPPLastActivityDelegateMock *delegate = [[XMPPLastActivityDelegateMock alloc] init];
    XMPPLastActivity<XMPPStreamDelegate> *module = (XMPPLastActivity<XMPPStreamDelegate> *) [[XMPPLastActivity alloc] init];
    dispatch_queue_t moduleQueue = module.moduleQueue;
    id stream = [OCMockObject mockForClass:[XMPPStream class]];
    __block XMPPIQ *response = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    dispatch_queue_t queue = dispatch_queue_create("test", 0);
    [module addDelegate:delegate delegateQueue:queue];

    // We need to activate the module to create the id tracker, so we need a
    // mock stream.
    [[stream stub] addDelegate:module delegateQueue:moduleQueue];
    [[stream stub] registerModule:module];

#ifdef _XMPP_CAPABILITIES_H
    [[stream stub] autoAddDelegate:module delegateQueue:moduleQueue toModulesOfClass:[XMPPCapabilities class]];
#endif

    [module activate:stream];

    // sendLastActivityQueryTo:withTimeout uses the stream to send the query, we
    // capture the query, so we can generate the proper response.
    [[stream expect] sendElement:[OCMArg checkWithBlock:^BOOL(XMPPIQ *query) {
        BOOL valid = ([@"get" isEqualToString:query.type] &&
                      [romeo isEqual:query.to] &&
                      [@"query" isEqualToString:query.childElement.name] &&
                      [XMPPLastActivityNamespace isEqualToString:query.childElement.URI]);
        response = [XMPPIQ lastActivityResponseTo:query withSeconds:23];
        return valid;
    }]];

    (void)[module sendLastActivityQueryTo:romeo withTimeout:30];

    // Check the delegate receive the right parameters, signal the semaphore, so
    // the wait below doesn't timeout (and the test fail).
    delegate.xmppLastActivityDidReceiveResponseHandler = ^(XMPPLastActivity *lastActivity, XMPPIQ *iq) {
        GHAssertEquals(lastActivity, module, nil);
        GHAssertEquals(iq, response, nil);
        dispatch_semaphore_signal(semaphore);
    };

    dispatch_sync(moduleQueue, ^{
        (void)[module xmppStream:stream didReceiveIQ:response];
    });

    if (dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC)) != 0)
    {
        GHFail(@"The delegate was not invoked");
    }

    [stream verify];
}

- (void)testSendLastActivityQueryToWithTimeoutNotReceivingResponse
{
    XMPPJID *romeo = [XMPPJID jidWithString:@"romeo@montague.net/orchard"];
    XMPPLastActivityDelegateMock *delegate = [[XMPPLastActivityDelegateMock alloc] init];
    XMPPLastActivity<XMPPStreamDelegate> *module = (XMPPLastActivity<XMPPStreamDelegate> *) [[XMPPLastActivity alloc] init];
    dispatch_queue_t moduleQueue = module.moduleQueue;
    id stream = [OCMockObject mockForClass:[XMPPStream class]];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    dispatch_queue_t queue = dispatch_queue_create("test", 0);
    [module addDelegate:delegate delegateQueue:queue];

    // We need to activate the module to create the id tracker, so we need a
    // mock stream.
    [[stream stub] addDelegate:module delegateQueue:moduleQueue];
    [[stream stub] registerModule:module];

#ifdef _XMPP_CAPABILITIES_H
    [[stream stub] autoAddDelegate:module delegateQueue:moduleQueue toModulesOfClass:[XMPPCapabilities class]];
#endif

    [module activate:stream];

    // sendLastActivityQueryTo:withTimeout uses the stream to send the query
    [[stream stub] sendElement:[OCMArg any]];

    NSTimeInterval expectedTimeout = 1.0;
    NSString *expectedQueryID = [module sendLastActivityQueryTo:romeo withTimeout:expectedTimeout];

    // Check the delegate receive the right parameters, signal the semaphore, so
    // the wait below doesn't timeout (and the test fail).
    delegate.xmppLastActivityDidNotReceiveResponseDueToTimeoutHandler = ^(XMPPLastActivity *lastActivity, NSString *queryID, NSTimeInterval timeout) {
        GHAssertEquals(lastActivity, module, nil);
        GHAssertEqualStrings(queryID, expectedQueryID, nil);
        GHAssertEqualsWithAccuracy(timeout, expectedTimeout, 0.1, nil);
        dispatch_semaphore_signal(semaphore);
    };

    if (dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)) != 0)
    {
        GHFail(@"The delegate was not invoked");
    }
    
    [stream verify];
}

- (void)testSendLastActivityQueryToWithTimeoutReceivingError
{
    XMPPJID *romeo = [XMPPJID jidWithString:@"romeo@montague.net/orchard"];
    XMPPLastActivityDelegateMock *delegate = [[XMPPLastActivityDelegateMock alloc] init];
    XMPPLastActivity<XMPPStreamDelegate> *module = (XMPPLastActivity<XMPPStreamDelegate> *) [[XMPPLastActivity alloc] init];
    dispatch_queue_t moduleQueue = module.moduleQueue;
    id stream = [OCMockObject mockForClass:[XMPPStream class]];
    __block XMPPIQ *response = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    dispatch_queue_t queue = dispatch_queue_create("test", 0);
    [module addDelegate:delegate delegateQueue:queue];

    // We need to activate the module to create the id tracker, so we need a
    // mock stream.
    [[stream stub] addDelegate:module delegateQueue:moduleQueue];
    [[stream stub] registerModule:module];

#ifdef _XMPP_CAPABILITIES_H
    [[stream stub] autoAddDelegate:module delegateQueue:moduleQueue toModulesOfClass:[XMPPCapabilities class]];
#endif

    [module activate:stream];

    // sendLastActivityQueryTo:withTimeout uses the stream to send the query, we
    // capture the query, so we can generate the proper response.
    [[stream expect] sendElement:[OCMArg checkWithBlock:^BOOL(XMPPIQ *query) {
        BOOL valid = ([@"get" isEqualToString:query.type] &&
                      [romeo isEqual:query.to] &&
                      [@"query" isEqualToString:query.childElement.name] &&
                      [XMPPLastActivityNamespace isEqualToString:query.childElement.URI]);
        response = [XMPPIQ lastActivityResponseForbiddenTo:query];
        return valid;
    }]];

    (void)[module sendLastActivityQueryTo:romeo withTimeout:30];

    // Check the delegate receive the right parameters, signal the semaphore, so
    // the wait below doesn't timeout (and the test fail).
    delegate.xmppLastActivityDidReceiveResponseHandler = ^(XMPPLastActivity *lastActivity, XMPPIQ *iq) {
        GHAssertEquals(lastActivity, module, nil);
        GHAssertEquals(iq, response, nil);
        dispatch_semaphore_signal(semaphore);
    };

    dispatch_sync(moduleQueue, ^{
        (void)[module xmppStream:stream didReceiveIQ:response];
    });

    if (dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC)) != 0)
    {
        GHFail(@"The delegate was not invoked");
    }
    
    [stream verify];
}

- (void)testXMPPStreamDidReceiveIQWithNoRespondsToQueriesReturnsNo
{
    XMPPJID *romeo = [XMPPJID jidWithString:@"romeo@montague.net/orchard"];
    XMPPLastActivity<XMPPStreamDelegate> *lastActivity = (XMPPLastActivity<XMPPStreamDelegate> *) [[XMPPLastActivity alloc] init];
    lastActivity.respondsToQueries = NO;
    XMPPIQ *query = [XMPPIQ lastActivityQueryTo:romeo];

    // the stream is not used
    dispatch_sync(lastActivity.moduleQueue, ^{
        GHAssertFalse([lastActivity xmppStream:nil didReceiveIQ:query], nil);
    });
}

- (void)testXMPPStreamDidReceiveIQWithTypeSetReturnsNo
{
    XMPPJID *romeo = [XMPPJID jidWithString:@"romeo@montague.net/orchard"];
    XMPPLastActivity<XMPPStreamDelegate> *lastActivity = (XMPPLastActivity<XMPPStreamDelegate> *) [[XMPPLastActivity alloc] init];

    // Create the query IQ, but switch its type to set
    XMPPIQ *query = [XMPPIQ lastActivityQueryTo:romeo];
    [query removeAttributeForName:@"type"];
    [query addAttributeWithName:@"type" stringValue:@"set"];

    // the stream is not used
    dispatch_sync(lastActivity.moduleQueue, ^{
        GHAssertFalse([lastActivity xmppStream:nil didReceiveIQ:query], nil);
    });
}

- (void)testXMPPStreamDidReceiveIQWithOtherNamespaceReturnsNo
{
    XMPPJID *romeo = [XMPPJID jidWithString:@"romeo@montague.net/orchard"];
    XMPPLastActivity<XMPPStreamDelegate> *lastActivity = (XMPPLastActivity<XMPPStreamDelegate> *) [[XMPPLastActivity alloc] init];
    XMPPIQ *nonQuery = [XMPPIQ iqWithType:@"get" to:romeo];

    // the stream is not used
    dispatch_sync(lastActivity.moduleQueue, ^{
        GHAssertFalse([lastActivity xmppStream:nil didReceiveIQ:nonQuery], nil);
    });
}

- (void)testXMPPStreamDidReceiveIQWithLastActivityQuery
{
    XMPPJID *romeo = [XMPPJID jidWithString:@"romeo@montague.net/orchard"];
    XMPPJID *juliet = [XMPPJID jidWithString:@"juliet@capulet.com/balcony"];
    XMPPLastActivityDelegateMock *delegate = [[XMPPLastActivityDelegateMock alloc] init];
    XMPPLastActivity<XMPPStreamDelegate> *lastActivity = (XMPPLastActivity<XMPPStreamDelegate> *) [[XMPPLastActivity alloc] init];
    id stream = [OCMockObject mockForClass:[XMPPStream class]];
    dispatch_queue_t queue = dispatch_queue_create("test", 0);
    dispatch_group_t group = dispatch_group_create();

    XMPPIQ *query = [XMPPIQ lastActivityQueryTo:romeo];
    [query addAttributeWithName:@"from" stringValue:[juliet full]];

    [lastActivity addDelegate:delegate delegateQueue:queue];

    dispatch_group_enter(group);
    delegate.numberOfIdleTimeSecondsForXMPPLastActivityQueryIQCurrentIdleTimeSeconds = ^NSUInteger (XMPPLastActivity *sender, XMPPIQ *iq, NSUInteger idleSeconds) {
        GHAssertEquals(sender, lastActivity, nil);
        GHAssertEquals(iq, query, nil);
        GHAssertEquals(idleSeconds, NSNotFound, nil);
        dispatch_group_leave(group);
        return 123U;
    };

    dispatch_group_enter(group);
    [[stream expect] sendElement:[OCMArg checkWithBlock:^BOOL(XMPPIQ *response) {
        BOOL valid = ([@"result" isEqualToString:response.type] &&
                      [juliet isEqual:response.to] &&
                      [@"query" isEqualToString:query.childElement.name] &&
                      [XMPPLastActivityNamespace isEqualToString:response.childElement.URI] &&
                      [@"123" isEqualToString:[response.childElement attributeStringValueForName:@"seconds"]]);
        dispatch_group_leave(group);
        return valid;
    }]];

    dispatch_sync(lastActivity.moduleQueue, ^{
        GHAssertTrue([lastActivity xmppStream:stream didReceiveIQ:query], nil);
    });

    if (dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC)) != 0)
    {
        GHFail(@"The delegate or the -[XMPPStream sendElement:] was not invoked");
    }

    [stream verify];
}

- (void)testXMPPStreamDidReceiveIQInvokeAllDelegatesInTurn
{
    XMPPJID *romeo = [XMPPJID jidWithString:@"romeo@montague.net/orchard"];
    XMPPJID *juliet = [XMPPJID jidWithString:@"juliet@capulet.com/balcony"];
    XMPPLastActivityDelegateMock *delegate1 = [[XMPPLastActivityDelegateMock alloc] init];
    XMPPLastActivityDelegateMock *delegate2 = [[XMPPLastActivityDelegateMock alloc] init];
    XMPPLastActivity<XMPPStreamDelegate> *lastActivity = (XMPPLastActivity<XMPPStreamDelegate> *) [[XMPPLastActivity alloc] init];
    id stream = [OCMockObject mockForClass:[XMPPStream class]];
    dispatch_queue_t queue = dispatch_queue_create("test", 0);
    dispatch_group_t group = dispatch_group_create();

    XMPPIQ *query = [XMPPIQ lastActivityQueryTo:romeo];
    [query addAttributeWithName:@"from" stringValue:[juliet full]];

    [lastActivity addDelegate:delegate1 delegateQueue:queue];
    [lastActivity addDelegate:delegate2 delegateQueue:queue];

    dispatch_group_enter(group);
    delegate1.numberOfIdleTimeSecondsForXMPPLastActivityQueryIQCurrentIdleTimeSeconds = ^NSUInteger (XMPPLastActivity *sender, XMPPIQ *iq, NSUInteger idleSeconds) {
        GHAssertEquals(sender, lastActivity, nil);
        GHAssertEquals(iq, query, nil);
        GHAssertTrue(idleSeconds == NSNotFound || idleSeconds == 456U, nil);
        dispatch_group_leave(group);
        return 123U;
    };

    dispatch_group_enter(group);
    delegate2.numberOfIdleTimeSecondsForXMPPLastActivityQueryIQCurrentIdleTimeSeconds = ^NSUInteger (XMPPLastActivity *sender, XMPPIQ *iq, NSUInteger idleSeconds) {
        GHAssertEquals(sender, lastActivity, nil);
        GHAssertEquals(iq, query, nil);
        GHAssertTrue(idleSeconds == NSNotFound || idleSeconds == 123U, nil);
        dispatch_group_leave(group);
        return 456U;
    };

    dispatch_group_enter(group);
    [[stream expect] sendElement:[OCMArg checkWithBlock:^BOOL(XMPPIQ *response) {
        BOOL valid = ([@"result" isEqualToString:response.type] &&
                      [juliet isEqual:response.to] &&
                      [@"query" isEqualToString:query.childElement.name] &&
                      [XMPPLastActivityNamespace isEqualToString:response.childElement.URI] &&
                      ([@"123" isEqualToString:[response.childElement attributeStringValueForName:@"seconds"]] ||
                       [@"456" isEqualToString:[response.childElement attributeStringValueForName:@"seconds"]]));
        dispatch_group_leave(group);
        return valid;
    }]];

    dispatch_sync(lastActivity.moduleQueue, ^{
        GHAssertTrue([lastActivity xmppStream:stream didReceiveIQ:query], nil);
    });

    if (dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC)) != 0)
    {
        GHFail(@"The delegates or the -[XMPPStream sendElement:] was not invoked");
    }
    
    [stream verify];
}

- (void)testXMPPStreamDidReceiveIQWithDummyDelegate
{
    XMPPJID *romeo = [XMPPJID jidWithString:@"romeo@montague.net/orchard"];
    XMPPJID *juliet = [XMPPJID jidWithString:@"juliet@capulet.com/balcony"];
    XMPPLastActivityDelegateMock *delegate = [[XMPPLastActivityDelegateMock alloc] init];
    XMPPLastActivity<XMPPStreamDelegate> *lastActivity = (XMPPLastActivity<XMPPStreamDelegate> *) [[XMPPLastActivity alloc] init];
    id stream = [OCMockObject mockForClass:[XMPPStream class]];
    dispatch_queue_t queue = dispatch_queue_create("test", 0);
    dispatch_group_t group = dispatch_group_create();

    XMPPIQ *query = [XMPPIQ lastActivityQueryTo:romeo];
    [query addAttributeWithName:@"from" stringValue:[juliet full]];

    [lastActivity addDelegate:delegate delegateQueue:queue];

    dispatch_group_enter(group);
    delegate.numberOfIdleTimeSecondsForXMPPLastActivityQueryIQCurrentIdleTimeSeconds = ^NSUInteger (XMPPLastActivity *sender, XMPPIQ *iq, NSUInteger idleSeconds) {
        GHAssertEquals(sender, lastActivity, nil);
        GHAssertEquals(iq, query, nil);
        GHAssertEquals(idleSeconds, NSNotFound, nil);
        dispatch_group_leave(group);
        return idleSeconds;
    };

    dispatch_group_enter(group);
    [[stream expect] sendElement:[OCMArg checkWithBlock:^BOOL(XMPPIQ *response) {
        BOOL valid = ([@"result" isEqualToString:response.type] &&
                      [juliet isEqual:response.to] &&
                      [@"query" isEqualToString:query.childElement.name] &&
                      [XMPPLastActivityNamespace isEqualToString:response.childElement.URI] &&
                      [@"0" isEqualToString:[response.childElement attributeStringValueForName:@"seconds"]]);
        dispatch_group_leave(group);
        return valid;
    }]];

    dispatch_sync(lastActivity.moduleQueue, ^{
        GHAssertTrue([lastActivity xmppStream:stream didReceiveIQ:query], nil);
    });

    if (dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC)) != 0)
    {
        GHFail(@"The delegate or the -[XMPPStream sendElement:] was not invoked");
    }
    
    [stream verify];
}

- (void)testXMPPStreamDidReceiveIQWithNoDelegate
{
    XMPPJID *romeo = [XMPPJID jidWithString:@"romeo@montague.net/orchard"];
    XMPPJID *juliet = [XMPPJID jidWithString:@"juliet@capulet.com/balcony"];
    XMPPLastActivity<XMPPStreamDelegate> *lastActivity = (XMPPLastActivity<XMPPStreamDelegate> *) [[XMPPLastActivity alloc] init];
    id stream = [OCMockObject mockForClass:[XMPPStream class]];
    dispatch_group_t group = dispatch_group_create();

    XMPPIQ *query = [XMPPIQ lastActivityQueryTo:romeo];
    [query addAttributeWithName:@"from" stringValue:[juliet full]];

    dispatch_group_enter(group);
    [[stream expect] sendElement:[OCMArg checkWithBlock:^BOOL(XMPPIQ *response) {
        BOOL valid = ([@"result" isEqualToString:response.type] &&
                      [juliet isEqual:response.to] &&
                      [@"query" isEqualToString:query.childElement.name] &&
                      [XMPPLastActivityNamespace isEqualToString:response.childElement.URI] &&
                      [@"0" isEqualToString:[response.childElement attributeStringValueForName:@"seconds"]]);
        dispatch_group_leave(group);
        return valid;
    }]];

    dispatch_sync(lastActivity.moduleQueue, ^{
        GHAssertTrue([lastActivity xmppStream:stream didReceiveIQ:query], nil);
    });

    if (dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC)) != 0)
    {
        GHFail(@"The delegate or the -[XMPPStream sendElement:] was not invoked");
    }

    [stream verify];
}

- (void)testDeactivateShouldNotCallPendingQueriesTimeouts
{
    XMPPJID *romeo = [XMPPJID jidWithString:@"romeo@montague.net/orchard"];
    XMPPLastActivityDelegateMock *delegate = [[XMPPLastActivityDelegateMock alloc] init];
    XMPPLastActivity *module = [[XMPPLastActivity alloc] init];
    dispatch_queue_t moduleQueue = module.moduleQueue;
    id stream = [OCMockObject mockForClass:[XMPPStream class]];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    dispatch_queue_t queue = dispatch_queue_create("test", 0);
    [module addDelegate:delegate delegateQueue:queue];

    // We need to activate the module to create the id tracker, so we need a
    // mock stream.
    [[stream stub] addDelegate:module delegateQueue:moduleQueue];
    [[stream stub] registerModule:module];

#ifdef _XMPP_CAPABILITIES_H
    [[stream stub] autoAddDelegate:module delegateQueue:moduleQueue toModulesOfClass:[XMPPCapabilities class]];
#endif

    [module activate:stream];

    // We now send a last activity query, that will not be answered because we
    // deactivate the module just after sending, but should not generate the
    // timeout either.
    delegate.xmppLastActivityDidReceiveResponseHandler = ^(XMPPLastActivity *sender, XMPPIQ *response) {
        dispatch_semaphore_signal(semaphore);
        GHFail(@"The response should not be invoked");
    };

    delegate.xmppLastActivityDidNotReceiveResponseDueToTimeoutHandler = ^(XMPPLastActivity *sender, NSString *queryID, NSTimeInterval timeout) {
        dispatch_semaphore_signal(semaphore);
        GHFail(@"The timeout should not be invoked");
    };

    [[stream stub] sendElement:[OCMArg any]];

    [module sendLastActivityQueryTo:romeo withTimeout:1.0];

    // Now we need to deactivate the module. Set up the expectations.
#ifdef _XMPP_CAPABILITIES_H
    [[stream stub] removeAutoDelegate:module delegateQueue:moduleQueue fromModulesOfClass:[XMPPCapabilities class]];
#endif

    [[stream stub] removeDelegate:module delegateQueue:moduleQueue];
    [[stream stub] unregisterModule:module];

    [module deactivate];

    // Wait for 2 seconds, if timeout occurs, the test is good.
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 1100 * NSEC_PER_MSEC));
    [stream verify];
}

- (void)testXMPPDidDisconnectWithErrorShouldNotCallPendingQueriesTimeouts
{
    XMPPJID *romeo = [XMPPJID jidWithString:@"romeo@montague.net/orchard"];
    XMPPLastActivityDelegateMock *delegate = [[XMPPLastActivityDelegateMock alloc] init];
    XMPPLastActivity<XMPPStreamDelegate> *module = (XMPPLastActivity<XMPPStreamDelegate> *)[[XMPPLastActivity alloc] init];
    dispatch_queue_t moduleQueue = module.moduleQueue;
    id stream = [OCMockObject mockForClass:[XMPPStream class]];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    dispatch_queue_t queue = dispatch_queue_create("test", 0);
    [module addDelegate:delegate delegateQueue:queue];

    // We need to activate the module to create the id tracker, so we need a
    // mock stream.
    [[stream stub] addDelegate:module delegateQueue:moduleQueue];
    [[stream stub] registerModule:module];

#ifdef _XMPP_CAPABILITIES_H
    [[stream stub] autoAddDelegate:module delegateQueue:moduleQueue toModulesOfClass:[XMPPCapabilities class]];
#endif

    [module activate:stream];

    // We now send a last activity query, that will not be answered because we
    // deactivate the module just after sending, but should not generate the
    // timeout either.
    delegate.xmppLastActivityDidReceiveResponseHandler = ^(XMPPLastActivity *sender, XMPPIQ *response) {
        dispatch_semaphore_signal(semaphore);
        GHFail(@"The response should not be invoked");
    };

    delegate.xmppLastActivityDidNotReceiveResponseDueToTimeoutHandler = ^(XMPPLastActivity *sender, NSString *queryID, NSTimeInterval timeout) {
        dispatch_semaphore_signal(semaphore);
        GHFail(@"The timeout should not be invoked");
    };

    [[stream stub] sendElement:[OCMArg any]];

    [module sendLastActivityQueryTo:romeo withTimeout:1.0];

    dispatch_sync(moduleQueue, ^{
        [module xmppStreamDidDisconnect:stream withError:nil];
    });

    // Wait for 2 seconds, if timeout occurs, the test is good.
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 1100 * NSEC_PER_MSEC));
    [stream verify];
}

#ifdef _XMPP_CAPABILITIES_H
- (void)testXMPPCapabilitiesColletingMyCapabilitiesShouldAddLastActivityFeature
{
    NSXMLElement *query = [NSXMLElement elementWithName:@"query" URI:@"http://jabber.org/protocol/disco#info"];
    XMPPLastActivity<XMPPCapabilitiesDelegate> *lastActivity = (XMPPLastActivity<XMPPCapabilitiesDelegate> *) [[XMPPLastActivity alloc] init];

    dispatch_sync(lastActivity.moduleQueue, ^{
        [lastActivity xmppCapabilities:nil collectingMyCapabilities:query];
    });

    __block BOOL found = NO;
    [[query elementsForName:@"feature"] enumerateObjectsUsingBlock:^(NSXMLElement *feature, NSUInteger idx, BOOL *stop) {
        found = [[feature attributeStringValueForName:@"var"] isEqualToString:XMPPLastActivityNamespace];
        *stop = found;
    }];

    if (!found) GHFail(@"feature subelement with jabber:iq:last var not found");
}

- (void)testXMPPCapabilitiesColletingMyCapabilitiesShouldNotModifyCapabilitiesWhenNoRespondsToQueries
{
    NSXMLElement *query = [NSXMLElement elementWithName:@"query" URI:@"http://jabber.org/protocol/disco#info"];
    XMPPLastActivity<XMPPCapabilitiesDelegate> *lastActivity = (XMPPLastActivity<XMPPCapabilitiesDelegate> *) [[XMPPLastActivity alloc] init];
    lastActivity.respondsToQueries = NO;

    dispatch_sync(lastActivity.moduleQueue, ^{
        [lastActivity xmppCapabilities:nil collectingMyCapabilities:query];
    });

    __block BOOL found = NO;
    [[query elementsForName:@"feature"] enumerateObjectsUsingBlock:^(NSXMLElement *feature, NSUInteger idx, BOOL *stop) {
        found = [[feature attributeStringValueForName:@"var"] isEqualToString:XMPPLastActivityNamespace];
        *stop = found;
    }];

    if (found) GHFail(@"feature subelement with jabber:iq:last var found");
}

#endif
@end

@implementation XMPPLastActivityDelegateMock

- (void)xmppLastActivity:(XMPPLastActivity *)sender didReceiveResponse:(XMPPIQ *)response
{
    if (self.xmppLastActivityDidReceiveResponseHandler)
    {
        self.xmppLastActivityDidReceiveResponseHandler(sender, response);
    }
}

- (void)xmppLastActivity:(XMPPLastActivity *)sender didNotReceiveResponse:(NSString *)queryID dueToTimeout:(NSTimeInterval)timeout
{
    if (self.xmppLastActivityDidNotReceiveResponseDueToTimeoutHandler)
    {
        self.xmppLastActivityDidNotReceiveResponseDueToTimeoutHandler(sender, queryID, timeout);
    }
}

- (NSUInteger)numberOfIdleTimeSecondsForXMPPLastActivity:(XMPPLastActivity *)sender queryIQ:(XMPPIQ *)iq currentIdleTimeSeconds:(NSUInteger)idleSeconds
{
    if (self.numberOfIdleTimeSecondsForXMPPLastActivityQueryIQCurrentIdleTimeSeconds)
    {
        return self.numberOfIdleTimeSecondsForXMPPLastActivityQueryIQCurrentIdleTimeSeconds(sender, iq, idleSeconds);
    }
    else
    {
        return idleSeconds;
    }
}

@end
