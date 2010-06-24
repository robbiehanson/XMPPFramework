//
//  RFSRVResolver.h
//
//  Created by Eric Chamberlain on 6/15/10.
//  Copyright 2010 RF.com. All rights reserved.
//
//	Based on SRVResolver by Apple, Inc.

#import <Foundation/Foundation.h>

#include <dns_sd.h>

#import "XMPPStream.h"

@protocol RFSRVResolverDelegate;


// Keys for the dictionaries in the results array:

extern NSString * kSRVResolverPriority;     // NSNumber, host byte order
extern NSString * kSRVResolverWeight;       // NSNumber, host byte order
extern NSString * kSRVResolverPort;         // NSNumber, host byte order
extern NSString * kSRVResolverTarget;       // NSString

extern NSString * kRFSRVResolverErrorDomain;


@interface RFSRVResolver : NSObject {
	
	XMPPStream *			_xmppStream;
	
	id						_delegate;
	
    BOOL                    _finished;
    NSError *               _error;
    NSMutableArray *        _results;
    DNSServiceRef           _sdRef;
    CFSocketRef             _sdRefSocket;
}

@property (nonatomic, retain, readonly) XMPPStream *				xmppStream;
@property (nonatomic, assign, readwrite) id							delegate;

@property (nonatomic, assign, readonly, getter=isFinished) BOOL     finished;		// observable
@property (nonatomic, retain, readonly) NSError *                   error;			// observable
@property (nonatomic, retain, readonly) NSMutableArray *            results;		// of NSDictionary, observable


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