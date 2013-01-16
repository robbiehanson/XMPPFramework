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
	// The passed parameter is a subnode of the IQ, and we need to pass it asynchronously to delegate(s).
	NSXMLElement *query = [querySubElement copy];
    
    // Notify the delegate(s)
    [multicastDelegate xmppDisco:self didReceiveDiscoveryInfo:query forJID:jid];
}

- (void)handleDiscoErrorResponse:(NSXMLElement *)errorSubElement fromJID:(XMPPJID *)jid
{
	// This method must be invoked on the moduleQueue
	NSAssert(dispatch_get_current_queue() == moduleQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	// Remember XML hiearchy memory management rules.
	// The passed parameter is a subnode of the IQ, and we need to pass it asynchronously to delegate(s).
	NSXMLElement *error = [errorSubElement copy];
    
    // Notify the delegates(s)
    [multicastDelegate xmppDisco:self didReceiveDiscoveryError:error forJID:jid];
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
    
    NSXMLElement *error = [iq elementForName:@"error"];
	
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
		[self handleDiscoErrorResponse:error fromJID:[iq from]];
	}
	else
	{
		return NO;
	}
	
	return YES;
}

@end
