//
//  XMPPDisco.m
//  iPhoneXMPP
//
//  Created by Rick Mellor on 1/9/13.
//
//

#import "XMPPDisco.h"
#import "XMPPLogging.h"

/**
 * Defines the timeout for a capabilities request.
 *
 * There are two reasons to have a timeout:
 * - To prevent the discoRequest variables from growing indefinitely if responses are not received.
 * - If a request is sent to a jid broadcasting a capabilities hash, and it does not respond within the timeout,
 *   we can then send a request to a different jid broadcasting the same capabilities hash.
 *
 * Remember, if multiple jids all broadcast the same capabilities hash,
 * we only (initially) send a disco request to the first jid.
 * This is an obvious optimization to remove unnecessary traffic and cpu load.
 *
 * However, if that jid doesn't respond within a sensible time period,
 * we should move on to the next jid in the list.
 **/
#define DISCO_REQUEST_TIMEOUT 30.0 // seconds


/**
 * Define various xmlns values.
 **/
#define XMLNS_DISCO_INFO  @"http://jabber.org/protocol/disco#info"

/**
 * Application identifier.
 * According to the XEP it is RECOMMENDED for the value of the 'node' attribute to be an HTTP URL.
 **/
#ifndef DISCO_NODE
#define DISCO_NODE @"http://code.google.com/p/xmppframework"
#endif

// Log levels: off, error, warn, info, verbose
// Log flags: trace
#if DEBUG
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#else
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

@implementation XMPPDisco

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Logic
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)activate:(XMPPStream *)aXmppStream
{
	if ([super activate:aXmppStream])
	{
		// Custom code goes here (if needed)
		
		return YES;
	}
	
	return NO;
}

- (void)deactivate
{
	// Custom code goes here (if needed)
	
	[super deactivate];
}

- (void)collectMyDiscoInfo
{
	// This method must be invoked on the moduleQueue
	NSAssert(dispatch_get_current_queue() == moduleQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	if (collectingMyDiscoInfo)
	{
		XMPPLogInfo(@"%@: %@ - Existing collection already in progress", [self class], THIS_METHOD);
		return;
	}
	
    myDiscoInfoQuery = nil;
	
	collectingMyDiscoInfo = YES;
	
	// Create new query and add standard features
	//
	// <query xmlns="http://jabber.org/protocol/disco#info">
	//   <feature var='http://jabber.org/protocol/disco#info'/>
	// </query>
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:XMLNS_DISCO_INFO];
	
	NSXMLElement *feature1 = [NSXMLElement elementWithName:@"feature"];
	[feature1 addAttributeWithName:@"var" stringValue:XMLNS_DISCO_INFO];
	
	[query addChild:feature1];
	
	// Now prompt the delegates to add any additional features.
	
	SEL selector = @selector(xmppDisco:collectingMyDiscoInfo:);
	
	if (![multicastDelegate hasDelegateThatRespondsToSelector:selector])
	{
		// None of the delegates implement the method.
		// Use a shortcut.
        collectingMyDiscoInfo = NO;
        myDiscoInfoQuery = query;
	}
	else
	{
		// Query all interested delegates.
		// This must be done serially to allow them to alter the element in a thread-safe manner.
		
		GCDMulticastDelegateEnumerator *delegateEnumerator = [multicastDelegate delegateEnumerator];
		
		dispatch_queue_t concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
		dispatch_async(concurrentQueue, ^{ @autoreleasepool {
			
			// Allow delegates to modify outgoing element
			
			id del;
			dispatch_queue_t dq;
			
			while ([delegateEnumerator getNextDelegate:&del delegateQueue:&dq forSelector:selector])
			{
				dispatch_sync(dq, ^{ @autoreleasepool {
					
                    [del xmppDisco:self collectingMyDiscoInfo:query];
				}});
			}
            
            collectingMyDiscoInfo = NO;
            myDiscoInfoQuery = query;
		}});
	}
}


- (void)sendDiscoInfoQueryTo:(XMPPJID *)jid withNode:(NSString *)node ver:(NSString *)ver
{
	// <iq to="romeo@montague.lit/orchard" id="uuid" type="get">
	//   <query xmlns="http://jabber.org/protocol/disco#info" node="[node]#[ver]"/>
	// </iq>
	//
	// Note:
	// Some xmpp clients will return an error if we don't specify the proper query node.
	// Some xmpp clients will return an error if we don't include an id attribute in the iq.
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:XMLNS_DISCO_INFO];
	
	if (node && ver)
	{
		NSString *nodeValue = [NSString stringWithFormat:@"%@#%@", node, ver];
		
		[query addAttributeWithName:@"node" stringValue:nodeValue];
	}
	
	XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:jid elementID:[xmppStream generateUUID] child:query];
	
	[xmppStream sendElement:iq];
}


/**
 * Invoked when we receive a disco request (request for our capabilities).
 * We should response with the proper disco response.
 **/
- (void)handleDiscoRequest:(XMPPIQ *)iqRequest
{
	// This method must be invoked on the moduleQueue
	NSAssert(dispatch_get_current_queue() == moduleQueue, @"Invoked on incorrect queue");
	
	//XMPPLogTrace();
	
	if (myDiscoInfoQuery == nil)
	{
		// It appears we haven't collected our list of capabilites yet.
		// This will need to be done before we can add the hash to the outgoing presence element.
		
		[self collectMyDiscoInfo];
	}

    NSXMLElement *queryRequest = [iqRequest childElement];
    NSString *node = [queryRequest attributeStringValueForName:@"node"];
    
    // <iq to="jid" id="id" type="result">
    //   <query xmlns="http://jabber.org/protocol/disco#info">
    //     <feature var="feature1"/>
    //     <feature var="feature2"/>
    //   </query>
    // </iq>
    
    NSXMLElement *query = [myDiscoInfoQuery copy];
    if (node)
    {
        [query addAttributeWithName:@"node" stringValue:node];
    }
    
    XMPPIQ *iqResponse = [XMPPIQ iqWithType:@"result"
                                         to:[iqRequest from]
                                  elementID:[iqRequest elementID]
                                      child:query];
    
    [xmppStream sendElement:iqResponse];
}

/**
 * Invoked when we receive a response to one of our previously sent disco requests.
 **/
- (void)handleDiscoResponse:(NSXMLElement *)querySubElement fromJID:(XMPPJID *)jid
{
	// This method must be invoked on the moduleQueue
	NSAssert(dispatch_get_current_queue() == moduleQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	// Remember XML hiearchy memory management rules.
	// The passed parameter is a subnode of the IQ, and we need to pass it asynchronously to storge / delegate(s).
	NSXMLElement *query = [querySubElement copy];
	
    // Cancel the request timeout
    //[self cancelTimeoutForDiscoRequestFromJID:jid];
    
    // Notify the delegate(s)
    [multicastDelegate xmppDisco:self didReceiveDiscoveryInfo:query forJID:jid];
}

- (void)handleDiscoErrorResponse:(NSXMLElement *)querySubElement fromJID:(XMPPJID *)jid
{
//	// This method must be invoked on the moduleQueue
//	NSAssert(dispatch_get_current_queue() == moduleQueue, @"Invoked on incorrect queue");
//	
//	XMPPLogTrace();
//	
//	NSString *hash = nil;
//	NSString *hashAlg = nil;
//	
//	BOOL hashResponse = [xmppCapabilitiesStorage getCapabilitiesHash:&hash
//	                                                       algorithm:&hashAlg
//	                                                          forJID:jid
//	                                                      xmppStream:xmppStream];
//	if (hashResponse)
//	{
//		NSString *key = [self keyFromHash:hash algorithm:hashAlg];
//		
//		// We'd still like to know what the capabilities are for this hash.
//		// Move onto the next one in the list (if there are more, otherwise stop).
//		[self maybeQueryNextJidWithHashKey:key dueToHashMismatch:NO];
//	}
//	else
//	{
//		// Make a note of the failure
//		[xmppCapabilitiesStorage setCapabilitiesFetchFailedForJID:jid xmppStream:xmppStream];
//		
//		// Remove the jid from the discoRequest variable
//		[discoRequestJidSet removeObject:jid];
//		
//		// Cancel the request timeout
//		[self cancelTimeoutForDiscoRequestFromJID:jid];
//	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Timers
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setupTimeoutForDiscoRequestFromJID:(XMPPJID *)jid
{
//	// This method must be invoked on the moduleQueue
//	NSAssert(dispatch_get_current_queue() == moduleQueue, @"Invoked on incorrect queue");
//	
//	XMPPLogTrace();
//	
//	// If the timeout occurs, we will remove the jid from the discoRequestJidSet.
//	// If we eventually get a response (after the timeout) we will still be able to process it.
//	// The timeout simply prevents the set from growing infinitely.
//	
//	dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, moduleQueue);
//	
//	dispatch_source_set_event_handler(timer, ^{ @autoreleasepool {
//		
//		[self processTimeoutWithJID:jid];
//		
//		dispatch_source_cancel(timer);
//#if NEEDS_DISPATCH_RETAIN_RELEASE
//		dispatch_release(timer);
//#endif
//	}});
//	
//	dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (DISCO_REQUEST_TIMEOUT * NSEC_PER_SEC));
//	
//	dispatch_source_set_timer(timer, tt, DISPATCH_TIME_FOREVER, 0);
//	dispatch_resume(timer);
//	
//	// We also keep a reference to the timer in the discoTimerJidDict.
//	// This allows us to cancel the timer when we get a response to the disco request.
//	
//	GCDTimerWrapper *timerWrapper = [[GCDTimerWrapper alloc] initWithDispatchTimer:timer];
//	
//	[discoTimerJidDict setObject:timerWrapper forKey:jid];
}

- (void)setupTimeoutForDiscoRequestFromJID:(XMPPJID *)jid withHashKey:(NSString *)key
{
//	// This method must be invoked on the moduleQueue
//	NSAssert(dispatch_get_current_queue() == moduleQueue, @"Invoked on incorrect queue");
//	
//	XMPPLogTrace();
//	
//	// If the timeout occurs, we want to send a request to the next jid with the same capabilities hash.
//	// This list of jids is stored in the discoRequestHashDict.
//	// The key will allow us to fetch the jid list.
//    
//	dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, moduleQueue);
//	
//	dispatch_source_set_event_handler(timer, ^{ @autoreleasepool {
//		
//		[self processTimeoutWithHashKey:key];
//		
//		dispatch_source_cancel(timer);
//#if NEEDS_DISPATCH_RETAIN_RELEASE
//		dispatch_release(timer);
//#endif
//	}});
//	
//	dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (DISCO_REQUEST_TIMEOUT * NSEC_PER_SEC));
//	
//	dispatch_source_set_timer(timer, tt, DISPATCH_TIME_FOREVER, 0);
//	dispatch_resume(timer);
//	
//	// We also keep a reference to the timer in the discoTimerJidDict.
//	// This allows us to cancel the timer when we get a response to the disco request.
//	
//	GCDTimerWrapper *timerWrapper = [[GCDTimerWrapper alloc] initWithDispatchTimer:timer];
//	
//	[discoTimerJidDict setObject:timerWrapper forKey:jid];
}

- (void)cancelTimeoutForDiscoRequestFromJID:(XMPPJID *)jid
{
//	// This method must be invoked on the moduleQueue
//	NSAssert(dispatch_get_current_queue() == moduleQueue, @"Invoked on incorrect queue");
//	
//	XMPPLogTrace();
//	
//	GCDTimerWrapper *timerWrapper = [discoTimerJidDict objectForKey:jid];
//	if (timerWrapper)
//	{
//		[timerWrapper cancel];
//		[discoTimerJidDict removeObjectForKey:jid];
//	}
}

- (void)processTimeoutWithHashKey:(NSString *)key
{
//	// This method must be invoked on the moduleQueue
//	NSAssert(dispatch_get_current_queue() == moduleQueue, @"Invoked on incorrect queue");
//	
//	XMPPLogTrace();
//	
//	[self maybeQueryNextJidWithHashKey:key dueToHashMismatch:NO];
}

- (void)processTimeoutWithJID:(XMPPJID *)jid
{
//	// This method must be invoked on the moduleQueue
//	NSAssert(dispatch_get_current_queue() == moduleQueue, @"Invoked on incorrect queue");
//	
//	XMPPLogTrace();
//	
//	// We queried the jid for its capabilities, but it didn't answer us.
//	// Nothing left to do now but wait.
//	//
//	// If it happens to eventually respond,
//	// then we'll still be able to process the capabilities properly.
//	//
//	// But at this point we're going to consider the query to be done.
//	// This prevents our discoRequestJidSet from growing infinitely,
//	// and also opens up the possibility of sending it another query in the future.
//	
//	[discoRequestJidSet removeObject:jid];
//	[xmppCapabilitiesStorage setCapabilitiesFetchFailedForJID:jid xmppStream:xmppStream];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
	// If this is the first time we've connected, start collecting our list of disco info.
	// We do this now so that the process is likely ready by the time we need to send a presence element.
	
	if (myDiscoInfoQuery == nil)
	{
		[self collectMyDiscoInfo];
	}
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	// This method is invoked on the moduleQueue.
	
	// Disco Request:
	//
	// <iq from="juliet@capulet.lit/chamber" type="get">
	//   <query xmlns="http://jabber.org/protocol/disco#info"/>
	// </iq>
	//
	// Disco Response:
	//
	// <iq from="romeo@montague.lit/orchard" type="result">
	//   <query xmlns="http://jabber.org/protocol/disco#info">
	//     <feature var="feature1"/>
	//     <feature var="feature2"/>
	//   </query>
	// </iq>
	
	NSXMLElement *query = [iq elementForName:@"query" xmlns:XMLNS_DISCO_INFO];
	if (query == nil)
	{
		return NO;
	}
	
	NSString *type = [[iq attributeStringValueForName:@"type"] lowercaseString];
	if ([type isEqualToString:@"get"])
	{
		NSString *node = [query attributeStringValueForName:@"node"];
		
		if (node == nil || [node hasPrefix:DISCO_NODE])
		{
			[self handleDiscoRequest:iq];
		}
		else
		{
			return NO;
		}
	}
	else if ([type isEqualToString:@"result"])
	{
		[self handleDiscoResponse:query fromJID:[iq from]];
	}
	else if ([type isEqualToString:@"error"])
	{
		[self handleDiscoErrorResponse:query fromJID:[iq from]];
	}
	else
	{
		return NO;
	}
	
	return YES;
}

@end
