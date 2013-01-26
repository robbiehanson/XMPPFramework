//
//  XMPPLastActivity.m
//  XEP-0012
//
//  Created by Daniel Rodríguez Troitiño on 1/26/2013.
//
//

#import "XMPPLastActivity.h"
#import "XMPPIDTracker.h"
#import "XMPPIQ+LastActivity.h"
#import "XMPPFramework.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

static const NSTimeInterval XMPPLastActivityDefaultTimeout = 30.0;


@interface XMPPLastActivity ()

@property (atomic, strong) XMPPIDTracker *queryTracker;

@end


@implementation XMPPLastActivity

@synthesize respondsToQueries = _respondsToQueries;
@synthesize queryTracker = _queryTracker;

- (id)init
{
	return [self initWithDispatchQueue:NULL];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	if ((self = [super initWithDispatchQueue:queue]))
	{
		_respondsToQueries = YES;
	}

	return self;
}

- (BOOL)activate:(XMPPStream *)aXmppStream
{
	if ([super activate:aXmppStream])
	{
#ifdef _XMPP_CAPABILITIES_H
		[xmppStream autoAddDelegate:self delegateQueue:moduleQueue toModulesOfClass:[XMPPCapabilities class]];
#endif

		_queryTracker = [[XMPPIDTracker alloc] initWithDispatchQueue:moduleQueue];

		return YES;
	}

	return NO;
}

- (void)deactivate
{
#ifdef _XMPP_CAPABILITIES_H
	[xmppStream removeAutoDelegate:self delegateQueue:moduleQueue fromModulesOfClass:[XMPPCapabilities class]];
#endif

	dispatch_block_t block = ^{ @autoreleasepool {
		[_queryTracker removeAllIDs];
		_queryTracker = nil;
	}};

	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_sync(moduleQueue, block);
}

- (BOOL)respondsToQueries
{
	if (dispatch_get_current_queue() == moduleQueue)
	{
		return _respondsToQueries;
	}
	else
	{
		__block BOOL result;

		dispatch_sync(moduleQueue, ^{
			result = _respondsToQueries;
		});

		return result;
	}
}

- (void)setRespondsToQueries:(BOOL)respondsToQueries
{
	dispatch_block_t block = ^{
		if (_respondsToQueries != respondsToQueries)
		{
			_respondsToQueries = respondsToQueries;

#ifdef _XMPP_CAPABILITIES_H
			@autoreleasepool {
				// Capabilities may have changed, need to notify others
				[xmppStream resendMyPresence];
			}
#endif
		}
	};

	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_sync(moduleQueue, block);
}

- (NSString *)sendLastActivityQueryTo:(XMPPJID *)jid
{
	return [self sendLastActivityQueryTo:jid withTimeout:XMPPLastActivityDefaultTimeout];
}

- (NSString *)sendLastActivityQueryTo:(XMPPJID *)jid withTimeout:(NSTimeInterval)timeout
{
	XMPPIQ *query = [XMPPIQ lastActivityQueryTo:jid];
	NSString *queryID = query.elementID;

	dispatch_async(moduleQueue, ^{
		__weak __typeof__(self) self_weak_ = self;
		[_queryTracker addID:queryID block:^(XMPPIQ *iq, id<XMPPTrackingInfo> info) {
			__strong __typeof__(self) self = self_weak_;
			if (iq)
			{
				[self delegateDidReceiveResponse:iq];
			}
			else
			{
				[self delegateDidNotReceiveResponse:info.elementID dueToTimeout:info.timeout];
			}
		} timeout:timeout];

		[xmppStream sendElement:query];
	});

	return queryID;
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	NSString *type = [iq type];

	if (([type isEqualToString:@"result"] || [type isEqualToString:@"error"]))
	{
		return [_queryTracker invokeForID:iq.elementID withObject:iq];
	}
	else if (_respondsToQueries && [type isEqualToString:@"get"])
	{
		// TODO: the delegate will need to be extended to answer if we want the
		// real response or the forbidden one, and how many seconds to answer.
		XMPPIQ *response = [XMPPIQ lastActivityResponseTo:iq withSeconds:1];
		[sender sendElement:response];

		return YES;
	}

	return NO;
}

- (void)xmppDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
	[_queryTracker removeAllIDs];
}

#ifdef _XMPP_CAPABILITIES_H
// If an XMPPCapabilities instance is used we want to advertise our support for last activity.
- (void)xmppCapabilities:(XMPPCapabilities *)sender collectingMyCapabilities:(NSXMLElement *)query
{
	if (_respondsToQueries)
	{
		NSXMLElement *feature = [NSXMLElement elementWithName:@"feature"];
		[feature addAttributeWithName:@"var" stringValue:XMPPLastActivityNamespace];

		[query addChild:feature];
	}
}
#endif

- (void)delegateDidReceiveResponse:(XMPPIQ *)response
{
	[multicastDelegate xmppLastActivity:self didReceiveResponse:response];
}

- (void)delegateDidNotReceiveResponse:(NSString *)queryID dueToTimeout:(NSTimeInterval)timeout
{
	[multicastDelegate xmppLastActivity:self didNotReceiveResponse:queryID dueToTimeout:timeout];
}

@end
