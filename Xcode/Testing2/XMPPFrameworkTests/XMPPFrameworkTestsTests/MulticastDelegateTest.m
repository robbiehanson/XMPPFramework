//
//  MulticastDelegateTest.m
//  XMPPFrameworkTests
//
//  Created by Paul Melnikow on 4/18/15.
//  Copyright (c) 2015 Paul Melnikow. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "GCDMulticastDelegate.h"
#import "OCMock/OCMock.h"

@protocol MyProtocol
@optional
- (void)didSomething;
- (void)didSomethingElse:(BOOL)flag;
- (void)foundString:(NSString *)str;
- (void)foundString:(NSString *)str andNumber:(NSNumber *)num;
@end


@interface MulticastDelegateTestBase : XCTestCase

@property (strong) GCDMulticastDelegate<MyProtocol> * multicastDelegate;

@property (strong) id del1;
@property (strong) id del2;
@property (strong) id del3;

#if !OS_OBJECT_USE_OBJC
@property (assign) dispatch_queue_t queue1;
@property (assign) dispatch_queue_t queue2;
@property (assign) dispatch_queue_t queue3;
#else
@property (strong) dispatch_queue_t queue1;
@property (strong) dispatch_queue_t queue2;
@property (strong) dispatch_queue_t queue3;
#endif

@end
@implementation MulticastDelegateTestBase

- (void)setUp {
    self.multicastDelegate = (GCDMulticastDelegate <MyProtocol> *)[[GCDMulticastDelegate alloc] init];
}

@end

@interface MulticastDelegateTest : MulticastDelegateTestBase
@end

@implementation MulticastDelegateTest

- (void)setUp {
    [super setUp];
    
    self.del1 = OCMStrictProtocolMock(@protocol(MyProtocol));
    self.del2 = OCMStrictProtocolMock(@protocol(MyProtocol));
    self.del3 = OCMStrictProtocolMock(@protocol(MyProtocol));
    
    self.queue1 = dispatch_queue_create("(1  )", NULL);
    self.queue2 = dispatch_queue_create("( 2 )", NULL);
    self.queue3 = dispatch_queue_create("(  3)", NULL);
    
    [self.multicastDelegate addDelegate:self.del1 delegateQueue:self.queue1];
    [self.multicastDelegate addDelegate:self.del2 delegateQueue:self.queue2];
    [self.multicastDelegate addDelegate:self.del3 delegateQueue:self.queue3];
}

-(void)tearDown
{
#if !OS_OBJECT_USE_OBJC
    dispatch_release(self.queue1);
    dispatch_release(self.queue2);
    dispatch_release(self.queue3);
#endif
}

- (void)testDidSomething
{
    OCMExpect([self.del1 didSomething]);
    OCMExpect([self.del2 didSomething]);
    OCMExpect([self.del3 didSomething]);
    
    [self.multicastDelegate didSomething];

    OCMVerifyAllWithDelay(self.del1, 0.05);
    OCMVerifyAll(self.del2);
    OCMVerifyAll(self.del3);
}

- (void) testDidSomethingElse
{
    OCMExpect([self.del1 didSomethingElse:YES]);
    OCMExpect([self.del2 didSomethingElse:YES]);
    OCMExpect([self.del3 didSomethingElse:YES]);
    
    [self.multicastDelegate didSomethingElse:YES];
    
    OCMVerifyAllWithDelay(self.del1, 0.05);
    OCMVerifyAll(self.del2);
    OCMVerifyAll(self.del3);
}

- (void) testFoundString
{
    OCMExpect([self.del1 foundString:@"I like cheese"]);
    OCMExpect([self.del2 foundString:@"I like cheese"]);
    OCMExpect([self.del3 foundString:@"I like cheese"]);
    
    [self.multicastDelegate foundString:@"I like cheese"];
    
    OCMVerifyAllWithDelay(self.del1, 0.05);
    OCMVerifyAll(self.del2);
    OCMVerifyAll(self.del3);
}

- (void) testFoundStringAndNumber
{
    OCMExpect([self.del1 foundString:@"The lucky number is" andNumber:@15]);
    OCMExpect([self.del2 foundString:@"The lucky number is" andNumber:@15]);
    OCMExpect([self.del3 foundString:@"The lucky number is" andNumber:@15]);
    
    [self.multicastDelegate foundString:@"The lucky number is" andNumber:@15];

    OCMVerifyAllWithDelay(self.del1, 0.05);
    OCMVerifyAll(self.del2);
    OCMVerifyAll(self.del3);
}

- (void)testDelegateEnumerator
{
    GCDMulticastDelegateEnumerator *delegateEnum = [self.multicastDelegate delegateEnumerator];
    
    id del;
    dispatch_queue_t dq;
    
    BOOL del1Seen = false;
    BOOL del2Seen = false;
    BOOL del3Seen = false;
    
    while ([delegateEnum getNextDelegate:&del delegateQueue:&dq forSelector:@selector(didSomething)])
    {
        if (del == self.del1) {
            XCTAssertEqual(dq, self.queue1);
            del1Seen = true;
        } else if (del == self.del2) {
            XCTAssertEqual(dq, self.queue2);
            del2Seen = true;
        } else if (del == self.del3) {
            XCTAssertEqual(dq, self.queue3);
            del3Seen = true;
        } else {
            XCTFail(@"Unexpected delegate");
        }
    }
    
    XCTAssertTrue(del1Seen);
    XCTAssertTrue(del2Seen);
    XCTAssertTrue(del3Seen);
}

@end

// NSProxy doesn't work correctly with weak references, so this test needs a different approach.

@interface MyMock : NSObject <MyProtocol>
@end
@implementation MyMock

- (void)didSomething { }
- (void)didSomethingElse:(BOOL)flag { }
- (void)foundString:(NSString *)str { }
- (void)foundString:(NSString *)str andNumber:(NSNumber *)num { }

@end

@interface MulticastDelegateWeakReferenceTest : MulticastDelegateTestBase
@end

@implementation MulticastDelegateWeakReferenceTest

- (void)setUp {
    [super setUp];
    
    self.del1 = [[MyMock alloc] init];
    self.del2 = [[MyMock alloc] init];
    self.del3 = [[MyMock alloc] init];
    
    self.queue1 = dispatch_queue_create("(1  )", NULL);
    self.queue2 = dispatch_queue_create("( 2 )", NULL);
    self.queue3 = dispatch_queue_create("(  3)", NULL);
    
    [self.multicastDelegate addDelegate:self.del1 delegateQueue:self.queue1];
    [self.multicastDelegate addDelegate:self.del2 delegateQueue:self.queue2];
    [self.multicastDelegate addDelegate:self.del3 delegateQueue:self.queue3];
}

- (void)testThatDelegateReferencesAreWeak
{
    XCTAssertEqual([self.multicastDelegate countForSelector:@selector(description)], 3);
    
    self.del1 = nil;
    
    XCTAssertEqual([self.multicastDelegate countForSelector:@selector(description)], 2);
}

@end
