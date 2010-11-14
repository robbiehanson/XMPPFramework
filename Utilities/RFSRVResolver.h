//
//  RFSRVResolver.h
//
//  Created by Eric Chamberlain on 6/15/10.
//  Copyright 2010 RF.com. All rights reserved.
//
//	Based on SRVResolver by Apple, Inc.

#import <Foundation/Foundation.h>
#import <dns_sd.h>

#import "XMPPStream.h"
#import "DDLog.h"


@protocol RFSRVResolverDelegate;

extern NSString * kRFSRVResolverErrorDomain;

@interface RFSRVRecord : NSObject {
	UInt16 priority;
	UInt16 weight;
	UInt16 port;
	NSString *target;
	
	NSUInteger sum;
	NSUInteger srvResultsIndex;
}

+ (RFSRVRecord *)recordWithPriority:(UInt16)priority weight:(UInt16)weight port:(UInt16)port target:(NSString *)target;

- (id)initWithPriority:(UInt16)priority weight:(UInt16)weight port:(UInt16)port target:(NSString *)target;

@property (nonatomic, readonly) UInt16 priority;
@property (nonatomic, readonly) UInt16 weight;
@property (nonatomic, readonly) UInt16 port;
@property (nonatomic, readonly) NSString *target;

@end

@interface RFSRVResolver : NSObject {
	
	XMPPStream *			_xmppStream;
	
	id						_delegate;
	
    BOOL                    _finished;
    NSError *               _error;
    NSMutableArray *        _results;
    DNSServiceRef           _sdRef;
    CFSocketRef             _sdRefSocket;
    NSTimer *               _timeoutTimer;
}

@property (nonatomic, retain, readonly) XMPPStream *				xmppStream;
@property (nonatomic, assign, readwrite) id							delegate;

@property (nonatomic, assign, readonly, getter=isFinished) BOOL     finished;		// observable
@property (nonatomic, retain, readonly) NSError *                   error;			// observable
@property (nonatomic, retain, readonly) NSArray *                   results;		// of RFSRVRecord, observable


+ (RFSRVResolver *)resolveWithStream:(XMPPStream *)xmppStream delegate:(id)delegate;

- (id)initWithStream:(XMPPStream *)xmppStream;

- (void)start;
- (void)stop;

@end

@protocol RFSRVResolverDelegate

/**
 * This method is called after myJID domain SRV resolution.
**/
- (void)srvResolverDidResoveSRV:(RFSRVResolver *)sender;
- (void)srvResolver:(RFSRVResolver *)sender didNotResolveSRVWithError:(NSError *)error;

@end