#import "XMPPStreamManagement.h"
#import "XMPPStreamManagementStanzas.h"
#import "XMPPInternal.h"
#import "XMPPTimer.h"
#import "XMPPLogging.h"
#import "NSNumber+XMPP.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
// Log flags: trace
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

/**
 * Define various xmlns values.
**/
#define XMLNS_STREAM_MANAGEMENT  @"urn:xmpp:sm:3"

/**
 * Seeing a return statements within an inner block
 * can sometimes be mistaken for a return point of the enclosing method.
 * This makes inline blocks a bit easier to read.
**/
#define return_from_block return


@implementation XMPPStreamManagement
{
	// Storage module (may be nil)
	
	id <XMPPStreamManagementStorage> storage;
	
	// State machine
	
	BOOL isStarted;    // either <enabled/> or <resumed/> received from server
	BOOL enableQueued; // the <enable/> element is queued in xmppStream
	BOOL enableSent;   // the <enable/> element has been sent through xmppStream
	
	BOOL wasCleanDisconnect; // xmppStream sent </stream:stream>
	
	BOOL didAttemptResume;
	BOOL didResume;
	
	NSXMLElement *resume_response;
	NSArray *resume_stanzaIds;
	
	NSDate *disconnectDate;
	
	// Configuration
	
	BOOL autoResume;
	
	NSUInteger autoRequest_stanzaCount;
	NSTimeInterval autoRequest_timeout;
	
	NSUInteger autoAck_stanzaCount;
	NSTimeInterval autoAck_timeout;
	
	NSTimeInterval ackResponseDelay;
	
	// Enable
	
	uint32_t requestedMax;
	
	// Tracking outgoing stanzas
	
	uint32_t lastHandledByServer; // last h value received from server
	
	NSMutableArray *unackedByServer;              // array of XMPPStreamManagementOutgoingStanza objects
	NSUInteger unackedByServer_lastRequestOffset; // represents point at which we last sent a request
	
	NSArray *prev_unackedByServer;                // from previous connection, used when resuming session
	
	NSMutableArray *unprocessedReceivedAcks; // acks received from server that we haven't processed yet
	
	XMPPTimer *autoRequestTimer;                  // timer to fire a request
	
	// Tracking incoming stanzas
	
	uint32_t lastHandledByClient; // latest h value we can send to the server
	
	NSMutableArray *unackedByClient;          // array of XMPPStreamManagementIncomingStanza objects
	NSUInteger unackedByClient_lastAckOffset; // number of items removed from array, but ack not sent to server
	
	NSMutableArray *pendingHandledStanzaIds;// edge case handling
	NSUInteger outstandingStanzaIds;        // edge case handling + defensive programming
	
	XMPPTimer *autoAckTimer; // timer to fire ack at server
	XMPPTimer *ackResponseTimer; // timer for ackResponseDelay
}

@synthesize storage = storage;

- (id)init
{
	// This will cause a crash - it's designed to.
	// Only the init methods listed in XMPPStreamManagement.h are supported.
	
	return [self initWithStorage:nil dispatchQueue:NULL];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	// This will cause a crash - it's designed to.
	// Only the init methods listed in XMPPStreamManagement.h are supported.
	
	return [self initWithStorage:nil dispatchQueue:queue];
}

- (id)initWithStorage:(id <XMPPStreamManagementStorage>)inStorage
{
	return [self initWithStorage:inStorage dispatchQueue:NULL];
}

- (id)initWithStorage:(id <XMPPStreamManagementStorage>)inStorage dispatchQueue:(dispatch_queue_t)queue
{
	if ((self = [super initWithDispatchQueue:queue]))
	{
		if ([inStorage configureWithParent:self queue:moduleQueue]) {
			storage = inStorage;
		}
		else {
			XMPPLogError(@"%@: %@ - Unable to configure storage!", THIS_FILE, THIS_METHOD);
		}
		
		unackedByServer = [[NSMutableArray alloc] init];
		unackedByClient = [[NSMutableArray alloc] init];
	}
	return self;
}

- (NSSet *)xep0198Elements
{
	return [NSSet setWithObjects:@"r", @"a", @"enable", @"enabled", @"resume", @"resumed", @"failed", nil];
}

- (void)didActivate
{
	[xmppStream registerCustomElementNames:[self xep0198Elements]];
}

- (void)didDeactivate
{
	[xmppStream unregisterCustomElementNames:[self xep0198Elements]];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Configuration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)autoResume
{
	XMPPLogTrace();
	
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		result = autoResume;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

- (void)setAutoResume:(BOOL)newAutoResume
{
	XMPPLogTrace();
	
	dispatch_block_t block = ^{
		autoResume = newAutoResume;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)automaticallyRequestAcksAfterStanzaCount:(NSUInteger)stanzaCount orTimeout:(NSTimeInterval)timeout
{
	XMPPLogTrace();
	
	dispatch_block_t block = ^{ @autoreleasepool{
		
		autoRequest_stanzaCount = stanzaCount;
		autoRequest_timeout = MAX(0.0, timeout);
		
		if (autoRequestTimer) {
			[autoRequestTimer updateTimeout:autoRequest_timeout fromOriginalStartTime:YES];
		}
		if (isStarted) {
			[self maybeRequestAck];
		}
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)getAutomaticallyRequestAcksAfterStanzaCount:(NSUInteger *)stanzaCountPtr orTimeout:(NSTimeInterval *)timeoutPtr
{
	XMPPLogTrace();
	
	__block NSUInteger stanzaCount = 0;
	__block NSTimeInterval timeout = 0.0;
	
	dispatch_block_t block = ^{
		
		stanzaCount = autoRequest_stanzaCount;
		timeout = autoRequest_timeout;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	if (stanzaCountPtr) *stanzaCountPtr = stanzaCount;
	if (timeoutPtr) *timeoutPtr = timeout;
}

- (void)automaticallySendAcksAfterStanzaCount:(NSUInteger)stanzaCount orTimeout:(NSTimeInterval)timeout
{
	XMPPLogTrace();
	
	dispatch_block_t block = ^{ @autoreleasepool{
		
		autoAck_stanzaCount = stanzaCount;
		autoAck_timeout = MAX(0.0, timeout);
		
		if (autoAckTimer) {
			[autoAckTimer updateTimeout:autoAck_timeout fromOriginalStartTime:YES];
		}
		if (isStarted) {
			[self maybeSendAck];
		}
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)getAutomaticallySendAcksAfterStanzaCount:(NSUInteger *)stanzaCountPtr orTimeout:(NSTimeInterval *)timeoutPtr
{
	XMPPLogTrace();
	
	__block NSUInteger stanzaCount = 0;
	__block NSTimeInterval timeout = 0.0;
	
	dispatch_block_t block = ^{
		
		stanzaCount = autoAck_stanzaCount;
		timeout = autoAck_timeout;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	if (stanzaCountPtr) *stanzaCountPtr = stanzaCount;
	if (timeoutPtr) *timeoutPtr = timeout;
}

- (NSTimeInterval)ackResponseDelay
{
	XMPPLogTrace();
	
	__block NSUInteger delay = 0.0;
	
	dispatch_block_t block = ^{
		
		delay = ackResponseDelay;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return delay;
}

- (void)setAckResponseDelay:(NSTimeInterval)delay
{
	XMPPLogTrace();
	
	dispatch_block_t block = ^{
		
		ackResponseDelay = delay;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Enable
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method sends the <enable> stanza to the server to request enabling stream management.
 *
 * XEP-0198 specifies that the <enable> stanza should only be sent by clients after authentication,
 * and after binding has occurred.
 * 
 * The servers response is reported via the delegate methods:
 * @see xmppStreamManagement:wasEnabled:
 * @see xmppStreamManagement:wasNotEnabled:
 *
 * @param supportsResumption
 *   Whether the client should request resumptions support.
 *   If YES, the resume attribute will be included. E.g. <enable resume='true'/>
 * 
 * @param maxTimeout
 *   Allows you to specify the client's preferred maximum resumption time.
 *   This is optional, and will only be sent if you provide a positive value (maxTimeout > 0.0).
 *   Note that XEP-0198 only supports sending this value in seconds.
 *   So it the provided maxTimeout includes millisecond precision, this will be ignored via truncation
 *   (rounding down to nearest whole seconds value).
 * 
 * @see supportsStreamManagement
**/
- (void)enableStreamManagementWithResumption:(BOOL)supportsResumption maxTimeout:(NSTimeInterval)maxTimeout
{
	dispatch_block_t block = ^{ @autoreleasepool{
		
		if (isStarted)
		{
			XMPPLogWarn(@"Stream management is already enabled/resumed.");
			return;
		}
		if (enableQueued || enableSent)
		{
			XMPPLogWarn(@"Stream management is already started (pending response from server).");
			return;
		}
		
		// State transition cleanup
		
		[unackedByServer removeAllObjects];
		unackedByServer_lastRequestOffset = 0;
		
		[unackedByClient removeAllObjects];
		unackedByClient_lastAckOffset = 0;
		
		unprocessedReceivedAcks = nil;
		
		pendingHandledStanzaIds = nil;
		outstandingStanzaIds = 0;
		
		// Send enable stanza:
		//
		// <enable xmlns='urn:xmpp:sm:3' ... />
		
		NSXMLElement *enable = [NSXMLElement elementWithName:@"enable" xmlns:XMLNS_STREAM_MANAGEMENT];
		
		if (supportsResumption) {
			[enable addAttributeWithName:@"resume" stringValue:@"true"];
		}
		if (maxTimeout > 0.0) {
			[enable addAttributeWithName:@"max" stringValue:[NSString stringWithFormat:@"%.0f", maxTimeout]];
		}
		
		[xmppStream sendElement:enable];
		
		enableQueued = YES;
		requestedMax = (maxTimeout > 0.0) ? (uint32_t)maxTimeout : (uint32_t)0;
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Resume
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Utility method for handling canResume logic.
**/
- (BOOL)canResumeStreamWithResumptionId:(NSString *)resumptionId
                                timeout:(uint32_t)timeout
                         lastDisconnect:(NSDate *)lastDisconnect
{
	if (resumptionId == nil) {
		XMPPLogVerbose(@"%@: Cannot resume stream: resumptionId is nil", THIS_FILE);
		return NO;
	}
	if (lastDisconnect == nil) {
		XMPPLogVerbose(@"%@: Cannot resume stream: lastDisconnect is nil", THIS_FILE);
		return NO;
	}
	
	NSTimeInterval elapsed = [lastDisconnect timeIntervalSinceNow] * -1.0;
	
	if (elapsed < 0.0) // lastDisconnect is in the future ?
	{
		XMPPLogVerbose(@"%@: Cannot resume stream: invalid lastDisconnect - appears to be in future", THIS_FILE);
		return NO;
	}
	if ((uint32_t)elapsed > timeout) // too much time has elapsed
	{
		XMPPLogVerbose(@"%@: Cannot resume stream: elapsed(%u) > timeout(%u)", THIS_FILE, (uint32_t)elapsed, timeout);
		return NO;
	}
	
	return YES;
}

/**
 * Returns YES if the stream can be resumed.
 *
 * This would be the case if there's an available resumptionId for the authenticated xmppStream,
 * and the timeout from the last stream has not been exceeded.
**/
- (BOOL)canResumeStream
{
	XMPPLogTrace();
	
	// This is a PUBLIC method
	
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{ @autoreleasepool{
		
		if (isStarted || enableQueued || enableSent) {
			return_from_block;
		}
		
		NSString *resumptionId = nil;
		uint32_t timeout = 0;
		NSDate *lastDisconnect = nil;
		
		[storage getResumptionId:&resumptionId
		                 timeout:&timeout
		          lastDisconnect:&lastDisconnect
		               forStream:xmppStream];
		
		result = [self canResumeStreamWithResumptionId:resumptionId timeout:timeout lastDisconnect:lastDisconnect];
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

/**
 * Internal method that handles sending the <resume/> element, and the corresponding state transition.
**/
- (void)sendResumeRequestWithResumptionId:(NSString *)resumptionId
{
	XMPPLogTrace();
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		// State transition cleanup
		
		[unackedByServer removeAllObjects];
		unackedByServer_lastRequestOffset = 0;
		
		[unackedByClient removeAllObjects];
		unackedByClient_lastAckOffset = 0;
		
		unprocessedReceivedAcks = nil;
		
		pendingHandledStanzaIds = nil;
		outstandingStanzaIds = 0;
		
		// Restore our state from the last stream
		
		uint32_t newLastHandledByClient = 0;
		uint32_t newLastHandledByServer = 0;
		NSArray *pendingOutgoingStanzas = nil;
		
		[storage getLastHandledByClient:&newLastHandledByClient
		            lastHandledByServer:&newLastHandledByServer
		         pendingOutgoingStanzas:&pendingOutgoingStanzas
		                      forStream:xmppStream];
		
		lastHandledByClient = newLastHandledByClient;
		lastHandledByServer = newLastHandledByServer;
		
		if ([pendingOutgoingStanzas count] > 0) {
			prev_unackedByServer = [[NSMutableArray alloc] initWithArray:pendingOutgoingStanzas copyItems:YES];
		}
		
		XMPPLogVerbose(@"%@: Attempting to resume: lastHandledByClient(%u) lastHandledByServer(%u)",
		               THIS_FILE, lastHandledByClient, lastHandledByServer);
		
		// Send the resume stanza:
		//
		// <resume h='lastHandledByClient' previd='resumptionId'/>
		
		NSXMLElement *resume = [NSXMLElement elementWithName:@"resume" xmlns:XMLNS_STREAM_MANAGEMENT];
		[resume addAttributeWithName:@"previd" stringValue:resumptionId];
		[resume addAttributeWithName:@"h" stringValue:[NSString stringWithFormat:@"%u", lastHandledByClient]];
		
		[xmppStream sendBindElement:resume];
		
		didAttemptResume = YES;
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

/**
 * Internal method to handle processing a resumed response from the server.
**/
- (void)processResumed:(NSXMLElement *)resumed
{
	XMPPLogTrace();
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		uint32_t h = [resumed attributeUInt32ValueForName:@"h" withDefaultValue:lastHandledByServer];
		
		uint32_t diff;
		if (h >= lastHandledByServer)
			diff = h - lastHandledByServer;
		else
			diff = (UINT32_MAX - lastHandledByServer) + h;
		
		// IMPORTATNT:
		// This code path uses prev_unackedByServer (NOT unackedByServer).
		// This is because the ack has to do with stanzas sent from the previous connection.
		
		if (diff > [prev_unackedByServer count])
		{
			XMPPLogWarn(@"Unexpected h value from resume: lastH=%lu, newH=%lu, numPendingStanzas=%lu",
			            (unsigned long)lastHandledByServer,
			            (unsigned long)h,
			            (unsigned long)[prev_unackedByServer count]);
			
			diff = (uint32_t)[prev_unackedByServer count];
		}
		
		NSMutableArray *stanzaIds = [NSMutableArray arrayWithCapacity:(NSUInteger)diff];
		
		for (uint32_t i = 0; i < diff; i++)
		{
			XMPPStreamManagementOutgoingStanza *outgoingStanza = [prev_unackedByServer objectAtIndex:(NSUInteger)i];
			
			if (outgoingStanza.stanzaId) {
				[stanzaIds addObject:outgoingStanza.stanzaId];
			}
		}
		
		lastHandledByServer = h;
		
		XMPPLogVerbose(@"%@: processResumed: lastHandledByServer(%u)", THIS_FILE, lastHandledByServer);
		
		isStarted = YES;
		didResume = YES;
		
		prev_unackedByServer = nil;
		
		resume_response = resumed;
		resume_stanzaIds = [stanzaIds copy];
		
		// Update storage
		
		[storage setLastDisconnect:[NSDate date]
		       lastHandledByServer:lastHandledByServer
		    pendingOutgoingStanzas:nil
		                 forStream:xmppStream];
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

/**
 * This method is meant to be called by other extensions when they receive an xmppStreamDidAuthenticate callback.
 *
 * Returns YES if the stream was resumed during the authentication process.
 * Returns NO otherwise (if resume wasn't available, or it failed).
 *
 * Other extensions may wish to skip certain setup processes that aren't
 * needed if the stream was resumed (since the previous session state has been restored server-side).
**/
- (BOOL)didResume
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		result = didResume;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

/**
 * This method is meant to be called when you receive an xmppStreamDidAuthenticate callback.
 *
 * It is used instead of a standard delegate method in order to provide a cleaner API.
 * By using this method, one can put all the logic for handling authentication in a single place.
 * But more importantly, it solves several subtle timing and threading issues.
 *
 * > A delegate method could have hit either before or after xmppStreamDidAuthenticate, depending on thread scheduling.
 * > We could have queued it up, and forced it to hit after.
 * > But your code would likely still have needed to add a check within xmppStreamDidAuthenticate...
 *
 * @param stanzaIdsPtr (optional)
 *   Just like the stanzaIdsPtr provided in xmppStreamManagement:didReceiveAckForStanzaIds:.
 *   This comes from the h value provided within the <resumed h='X'/> stanza sent by the server.
 * 
 * @param responsePtr (optional)
 *   Returns the response we got from the server. Either <resumed/> or <failed/>.
 *   This will be nil if resume wasn't tried.
 * 
 * @return
 *   YES if the stream was resumed.
 *   NO otherwise.
**/
- (BOOL)didResumeWithAckedStanzaIds:(NSArray **)stanzaIdsPtr
					 serverResponse:(NSXMLElement **)responsePtr
{
	__block BOOL result = NO;
	__block NSArray *stanzaIds = nil;
	__block NSXMLElement *response = nil;
	
	dispatch_block_t block = ^{
		
		result = didResume;
		stanzaIds = resume_stanzaIds;
		response = resume_response;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	if (stanzaIdsPtr) *stanzaIdsPtr = stanzaIds;
	if (responsePtr) *responsePtr = response;
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPCustomBinding Protocol
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Attempts to start the custom binding process.
 *
 * If it isn't possible to start the process (perhaps due to missing information),
 * this method should return XMPP_BIND_FAIL and set an appropriate error message.
 * 
 * If binding isn't needed (for example, because custom SASL authentication already handled it),
 * this method should return XMPP_BIND_SUCCESS.
 * In this case, xmppStream will immediately move to its post-binding operations.
 *
 * Otherwise this method should send whatever stanzas are needed to begin the binding process.
 * And then return XMPP_BIND_CONTINUE.
 *
 * This method is called by automatically XMPPStream.
 * You MUST NOT invoke this method manually.
**/
- (XMPPBindResult)start:(NSError **)errPtr
{
	XMPPLogTrace();
		
	// Fetch the resumptionId,
	// and check to see if we can resume the stream.
	
	NSString *resumptionId = nil;
	uint32_t timeout = 0;
	NSDate *lastDisconnect = nil;
	
	[storage getResumptionId:&resumptionId
	                 timeout:&timeout
	          lastDisconnect:&lastDisconnect
	               forStream:xmppStream];
	
	if (![self canResumeStreamWithResumptionId:resumptionId timeout:timeout lastDisconnect:lastDisconnect])
	{
		return XMPP_BIND_FAIL_FALLBACK;
	}
	
	// Start the resume proces
	[self sendResumeRequestWithResumptionId:resumptionId];
	
	return XMPP_BIND_CONTINUE;
}

/**
 * After the custom binding process has started, all incoming xmpp stanzas are routed to this method.
 * The method should process the stanza as appropriate, and return the coresponding result.
 * If the process is not yet complete, it should return XMPP_BIND_CONTINUE,
 * meaning the xmpp stream will continue to forward all incoming xmpp stanzas to this method.
 *
 * This method is called automatically by XMPPStream.
 * You MUST NOT invoke this method manually.
**/
- (XMPPBindResult)handleBind:(NSXMLElement *)element withError:(NSError **)errPtr
{
	XMPPLogTrace();
	
	NSString *elementName = [element name];
	
	if ([elementName isEqualToString:@"resumed"])
	{
		[self processResumed:element];
		
		return XMPP_BIND_SUCCESS;
	}
	else
	{
		if (![elementName isEqualToString:@"failed"]) {
			XMPPLogError(@"%@: Received unrecognized response from server: %@", THIS_METHOD, element);
		}
		
		dispatch_async(moduleQueue, ^{ @autoreleasepool {
			
			didResume = NO;
			resume_response = element;
			
			prev_unackedByServer = nil;
		}});
		
		return XMPP_BIND_FAIL_FALLBACK;
	}
}

/**
 * Optionally implement this method to override the default behavior.
 * By default behavior, we mean the behavior normally taken by xmppStream, which is:
 *
 * - IF the server includes <session xmlns='urn:ietf:params:xml:ns:xmpp-session'/> in its stream:features
 * - AND xmppStream.skipStartSession property is NOT set
 * - THEN xmppStream will send the session start request, and await the response before transitioning to authenticated
 *
 * Thus if you implement this method and return YES, then xmppStream will skip starting a session,
 * regardless of the stream:features and the current xmppStream.skipStartSession property value.
 *
 * If you implement this method and return NO, then xmppStream will follow the default behavior detailed above.
 * This means that, even if this method returns NO, the xmppStream may still skip starting a session if
 * the server doesn't require it via its stream:features,
 * or if the user has explicitly forbidden it via the xmppStream.skipStartSession property.
 *
 * The default value is NO.
**/
- (BOOL)shouldSkipStartSessionAfterSuccessfulBinding
{
	return YES;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Requesting Acks
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Sends a request <r/> element, requesting the server reply with an ack <a h='lastHandled'/>.
 *
 * You can also configure the extension to automatically sends requests.
 * @see automaticallyRequestAcksAfterStanzaCount:orTimeout:
 *
 * When the server replies with an ack, the delegate method will be invoked.
 * @see xmppStreamManagement:didReceiveAckForStanzaIds:
**/
- (void)requestAck
{
	XMPPLogTrace();
	
	// This is a PUBLIC method
	
	dispatch_block_t block = ^{ @autoreleasepool{
		
		if (isStarted || enableQueued || enableSent)
		{
			[self _requestAck];
		}
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)_requestAck
{
	XMPPLogTrace();
	
	if (isStarted || enableQueued || enableSent)
	{
		// Send the XML element
		
		NSXMLElement *r = [NSXMLElement elementWithName:@"r" xmlns:XMLNS_STREAM_MANAGEMENT];
		[xmppStream sendElement:r];
		
		// Reset offset
		
		unackedByServer_lastRequestOffset = [unackedByServer count];
	}
	
	[autoRequestTimer cancel];
	autoRequestTimer = nil;
}

- (BOOL)maybeRequestAck
{
	XMPPLogTrace();
	
	if (!isStarted && !(enableQueued || enableSent))
	{
		// cannot request ack if not started (or at least sent <enable/>)
		return NO;
	}
	if ((autoRequest_stanzaCount == 0) && (autoRequest_timeout == 0.0))
	{
		// auto request disabled
		return NO;
	}
	
	NSUInteger pending = [unackedByServer count] - unackedByServer_lastRequestOffset;
	if (pending == 0)
	{
		// nothing new to request
		return NO;
	}
	
	if ((autoRequest_stanzaCount > 0) && (pending >= autoRequest_stanzaCount))
	{
		[self _requestAck];
		return YES;
	}
	else if ((autoRequest_timeout > 0.0) && (autoRequestTimer == nil))
	{
		__weak id weakSelf = self;
		autoRequestTimer = [[XMPPTimer alloc] initWithQueue:moduleQueue eventHandler:^{ @autoreleasepool{
			
			[weakSelf _requestAck];
		}}];
		
		[autoRequestTimer startWithTimeout:autoRequest_timeout interval:0];
	}
	
	return NO;
}

/**
 * This method is invoked from one of the xmppStream:didSendX: methods.
**/
- (void)processSentElement:(XMPPElement *)element
{
	XMPPLogTrace();
	
	SEL selector = @selector(xmppStreamManagement:stanzaIdForSentElement:);
	
	if (![multicastDelegate hasDelegateThatRespondsToSelector:selector])
	{
		// There are not any delegates that respond to the selector.
		// So the stanzaId is the elementId (if there is one).
		
		NSString *elementId = [element elementID];
		
		XMPPStreamManagementOutgoingStanza *stanza =
		  [[XMPPStreamManagementOutgoingStanza alloc] initWithStanzaId:elementId];
		[unackedByServer addObject:stanza];
		
		[self updateStoredPendingOutgoingStanzas];
		
		// At bottom of this method:
		// [self maybeRequestAck];
	}
	else
	{
		// We need to query the delegate(s) to see if there's a specific stanzaId for this element.
		// This is an asynchronous process, so we put a placeholder in the array for now.
		
		XMPPStreamManagementOutgoingStanza *stanza =
		  [[XMPPStreamManagementOutgoingStanza alloc] initAwaitingStanzaId];
		[unackedByServer addObject:stanza];
		
		// Start the asynchronous process to find the proper stanzaId
		
		GCDMulticastDelegateEnumerator *enumerator = [multicastDelegate delegateEnumerator];
		
		dispatch_queue_t concurrentQ = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
		dispatch_async(concurrentQ, ^{ @autoreleasepool {
			
			id stanzaId = nil;
			
			id delegate = nil;
			dispatch_queue_t dq = NULL;
			
			while ([enumerator getNextDelegate:&delegate delegateQueue:&dq forSelector:selector])
			{
				stanzaId = [delegate xmppStreamManagement:self stanzaIdForSentElement:element];
				if (stanzaId)
				{
					break;
				}
			}
			
			if (stanzaId == nil)
			{
				stanzaId = [element elementID];
			}
			
			dispatch_async(moduleQueue, ^{ @autoreleasepool{
				
				// Set the stanzaId.
				stanza.stanzaId = stanzaId;
				stanza.awaitingStanzaId = NO;
				
				// It's possible that we received an ack from the sever (acking our stanza)
				// before we were able to determine its stanzaId.
				// This edge case is handled by storing the ack in the pendingAcks array for later processing.
				// We may be able to process it now.
				
				BOOL dequeuedPendingAck = NO;
				
				while ([unprocessedReceivedAcks count] > 0)
				{
					NSXMLElement *ack = [unprocessedReceivedAcks objectAtIndex:0];
					
					if ([self processReceivedAck:ack])
					{
						[unprocessedReceivedAcks removeObjectAtIndex:0];
						dequeuedPendingAck = YES;
					}
					else
					{
						break;
					}
				}
				
				if (!dequeuedPendingAck)
				{
					[self updateStoredPendingOutgoingStanzas];
				}
			}});
		}});
	}
	
	XMPPLogVerbose(@"%@: processSentElement (%@): lastHandledByServer(%u) pending(%lu)",
	               THIS_FILE, [element name], lastHandledByServer, (unsigned long)[unackedByServer count]);
	
	[self maybeRequestAck];
}

/**
 * This method is invoked when an ack <a h='lastHandled'/> arrives.
 * 
 * It attempts to process the ack.
 * That is, there should be adequate outgoing stanzas (in the unackedByServer array) which have a set stanzaId.
 * 
 * Because stanzaId's are set by the delegate(s), its possible (although unlikely) that we receive an ack before
 * the delegate tells us the proper stanzaId for a sent element. When this occurs, we won't be able to completely
 * process the ack. However, this method will process as many as possible (while maintaining serial order).
 *
 * @return 
 *   YES if the ack can be marked as 100% processed.
 *   NO otherwise (if we're still awaiting a stanzaId from a delegate),
 *   in which case the caller MUST store the ack in the unprocessedReceivedAcks array.
**/
- (BOOL)processReceivedAck:(NSXMLElement *)ack
{
	XMPPLogTrace();
	
	uint32_t h = 0;
	if (![NSNumber xmpp_parseString:[ack attributeStringValueForName:@"h"] intoUInt32:&h])
	{
		XMPPLogError(@"Error parsing h value from ack: %@", [ack compactXMLString]);
		return YES;
	}
	
	uint32_t diff;
	if (h >= lastHandledByServer)
		diff = h - lastHandledByServer;
	else
		diff = (UINT32_MAX - lastHandledByServer) + h;
	
	if (diff == 0)
	{
		// shortcut: server is reporting no new stanzas have been processed
		return YES;
	}
	
	if (diff > [unackedByServer count])
	{
		XMPPLogWarn(@"Unexpected h value from ack: lastH=%lu, newH=%lu, numPendingStanzas=%lu",
		            (unsigned long)lastHandledByServer,
		            (unsigned long)h,
		            (unsigned long)[unackedByServer count]);
		
		diff = (uint32_t)[unackedByServer count];
	}
	
	BOOL canProcessEntireAck = YES;
	NSUInteger processed = 0;
	
	NSMutableArray *stanzaIds = [NSMutableArray arrayWithCapacity:(NSUInteger)diff];
	
	for (uint32_t i = 0; i < diff; i++)
	{
		XMPPStreamManagementOutgoingStanza *outgoingStanza = [unackedByServer objectAtIndex:(NSUInteger)i];
		
		if ([outgoingStanza awaitingStanzaId])
		{
			canProcessEntireAck = NO;
			break;
		}
		else
		{
			if (outgoingStanza.stanzaId) {
				[stanzaIds addObject:outgoingStanza.stanzaId];
			}
			processed++;
		}
	}
	
	if (canProcessEntireAck || processed > 0)
	{
		if (canProcessEntireAck)
		{
			[unackedByServer removeObjectsInRange:NSMakeRange(0, (NSUInteger)diff)];
			if (unackedByServer_lastRequestOffset > diff)
				unackedByServer_lastRequestOffset -= diff;
			else
				unackedByServer_lastRequestOffset = 0;
			
			lastHandledByServer = h;
			
			XMPPLogVerbose(@"%@: processReceivedAck (fully processed): lastHandledByServer(%u) pending(%lu)",
			               THIS_FILE, lastHandledByServer, (unsigned long)[unackedByServer count]);
		}
		else // if (processed > 0)
		{
			[unackedByServer removeObjectsInRange:NSMakeRange(0, processed)];
			if (unackedByServer_lastRequestOffset > processed)
				unackedByServer_lastRequestOffset -= processed;
			else
				unackedByServer_lastRequestOffset = 0;
			
			lastHandledByServer += processed;
			
			XMPPLogVerbose(@"%@: processReceivedAck (partially processed): lastHandledByServer(%u) pending(%lu)",
			               THIS_FILE, lastHandledByServer, (unsigned long)[unackedByServer count]);
		}
		
		// Update storage
		
		NSArray *pending = [[NSArray alloc] initWithArray:unackedByServer copyItems:YES];
		
		if (isStarted)
		{
			[storage setLastDisconnect:[NSDate date]
			       lastHandledByServer:lastHandledByServer
			    pendingOutgoingStanzas:pending
			                 forStream:xmppStream];
		}
		else // edge case
		{
			[storage setLastDisconnect:disconnectDate
			       lastHandledByClient:lastHandledByClient
			       lastHandledByServer:lastHandledByServer
			    pendingOutgoingStanzas:pending
			                 forStream:xmppStream];
		}
		
		// Notify delegate
		
		[multicastDelegate xmppStreamManagement:self didReceiveAckForStanzaIds:stanzaIds];
	}
	else
	{
		XMPPLogVerbose(@"%@: processReceivedAck (unprocessed): lastHandledByServer(%u) pending(%lu)",
		               THIS_FILE, lastHandledByServer, (unsigned long)[unackedByServer count]);
	}
	
	return canProcessEntireAck;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Sending Acks
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Sends an unrequested ack <a h='lastHandled'/> element, acking the server's recently received (and handled) elements.
 *
 * You can also configure the extension to automatically sends acks.
 * @see automaticallySendAcksAfterStanzaCount:orTimeout:
 *
 * Keep in mind that the extension will automatically send an ack if it receives an explicit request.
**/
- (void)sendAck
{
	XMPPLogTrace();
	
	// This is a PUBLIC method
	
	dispatch_block_t block = ^{ @autoreleasepool{
		
		if (isStarted)
		{
			[self _sendAck];
		}
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

/**
 * Sends the ack <a h='x'/> element, and discards newly acked stanzas from the queue.
**/
- (void)_sendAck
{
	NSUInteger pending = 0;
	for (XMPPStreamManagementIncomingStanza *stanza in unackedByClient)
	{
		if (stanza.isHandled)
			pending++;
		else
			break;
	}
	
	if (pending > 0)
	{
		[unackedByClient removeObjectsInRange:NSMakeRange(0, pending)];
		unackedByClient_lastAckOffset += pending;
		lastHandledByClient += pending;
		
		XMPPLogVerbose(@"%@: sendAck: lastHandledByClient(%u) inc(%lu) totalPending(%lu)", THIS_FILE,
		               lastHandledByClient,
		               (unsigned long)pending,
		               (unsigned long)unackedByClient_lastAckOffset);
		
		// Update info in storage.
		
		if (isStarted)
		{
			[storage setLastDisconnect:[NSDate date]
			       lastHandledByClient:lastHandledByClient
			                 forStream:xmppStream];
		}
		else // edge case
		{
			// An incoming stanza got markedAsHandled post-disconnect
			
			NSArray *pending = [[NSArray alloc] initWithArray:unackedByServer copyItems:YES];
			
			[storage setLastDisconnect:disconnectDate
				   lastHandledByClient:lastHandledByClient
				   lastHandledByServer:lastHandledByServer
				pendingOutgoingStanzas:pending
							 forStream:xmppStream];
		}
	}
	
	if (isStarted)
	{
		// Send the XML element
		
		NSXMLElement *a = [NSXMLElement elementWithName:@"a" xmlns:XMLNS_STREAM_MANAGEMENT];
		
		NSString *h = [NSString stringWithFormat:@"%u", (unsigned int)lastHandledByClient];
		[a addAttributeWithName:@"h" stringValue:h];
		
		[xmppStream sendElement:a];
		
		// Reset offset
		
		unackedByClient_lastAckOffset = 0;
	}
	
	// Stop the timer(s)
	
	[autoAckTimer cancel];
	autoAckTimer = nil;
	
	[ackResponseTimer cancel];
	ackResponseTimer = nil;

}

/**
 * Returns the number of incoming stanzas that have been handled on our side,
 * but which we haven't yet sent an ack to the server.
**/
- (NSUInteger)numIncomingStanzasThatCanBeAcked
{
	// What is unackedByClient_lastAckOffset ?
	//
	// In the method maybeUpdateStoredLastHandledByClient,
	// we remove items from the unackedByClient array, and increase the lastHandledByClient value.
	// But we do NOT actually send an ack to the server at this point.
	//
	// Thus unackedByClient_lastAckOffset represents the number of items we're removed from the unackedByClient array,
	// and for which we still need to send an ack to the server.
	
	NSUInteger count = unackedByClient_lastAckOffset;
	
	for (XMPPStreamManagementIncomingStanza *stanza in unackedByClient)
	{
		if (stanza.isHandled)
			count++;
		else
			break;
	}
	
	return count;
}

/**
 * Returns the number of incoming stanzas that cannot yet be acked because
 * - the stanza hasn't been marked as handled yet
 * - or a preceeding stanza has hasn't been marked as handled yet
**/
- (NSUInteger)numIncomingStanzasThatCannnotBeAcked
{
	BOOL foundUnhandledStanza = NO;
	NSUInteger count = 0;
	
	for (XMPPStreamManagementIncomingStanza *stanza in unackedByClient)
	{
		if (foundUnhandledStanza)
		{
			count++;
		}
		else if (!stanza.isHandled)
		{
			foundUnhandledStanza = YES;
			count++;
		}
	}
	
	return count;
}

/**
 * Sends an ack if needed (if pending meets/exceeds autoAck_stanzaCount).
**/
- (BOOL)maybeSendAck
{
	XMPPLogTrace();
	
	if (!isStarted)
	{
		// cannot send acks if we're not started
		return NO;
	}
	if ((autoAck_stanzaCount == 0) && (autoAck_timeout == 0.0))
	{
		// auto ack disabled
		return NO;
	}
	
	NSUInteger pending = [self numIncomingStanzasThatCanBeAcked];
	if (pending == 0)
	{
		// nothing new to ack
		return NO;
	}
	
	// Send ack according to autoAck configuration
	
	if ((autoAck_stanzaCount > 0) && (pending >= autoAck_stanzaCount))
	{
		[self _sendAck];
		return YES;
	}
	else if ((autoAck_timeout > 0.0) && (autoAckTimer == nil))
	{
		__weak id weakSelf = self;
		autoAckTimer = [[XMPPTimer alloc] initWithQueue:moduleQueue eventHandler:^{ @autoreleasepool{
			
			[weakSelf sendAck];
		}}];
		
		[autoAckTimer startWithTimeout:autoAck_timeout interval:0];
	}
	
	return NO;
}

- (void)markHandledStanzaId:(id)stanzaId
{
	XMPPLogTrace();
	
	if (stanzaId == nil) return;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		// It's theoretically possible that the delegate(s) returned the same stanzaId for multiple elements.
		// Although this is strongly discouraged, we should try to do our best to handle such a situation logically.
		//
		// In light of this edge case, here are the rules:
		//
		// Find the first stanza in the queue that is
		// - not already marked as handled
		// - has a matching stanzaId
		//
		// Mark this as handled, and then break.
		//
		// We also check to see if marking this stanza as handled has increased the pending count.
		// For example (using the following queue):
		//
		// 0) <stanzaId=ABC, handled=YES>
		// 1) <stanzaId=DEF, handled=NO > // <-- marking as handled increases pendingCount from 1 to 2
		// 2) <stanzaId=GHI, handled=NO > // <-- marking as handled doesn't change pendingCount (still 1)
		
		BOOL found = NO;
		
		for (XMPPStreamManagementIncomingStanza *stanza in unackedByClient)
		{
			if (stanza.isHandled)
			{
				// continue
			}
			else if ([stanza.stanzaId isEqual:stanzaId])
			{
				stanza.isHandled = YES;
				found = YES;
				break;
			}
		}
		
		if (found)
		{
			if (![self maybeSendAck])
			{
				[self maybeUpdateStoredLastHandledByClient];
			}
		}
		else
		{
			// Edge case:
			//
			// The stanzaId was marked as handled before we finished figuring out what the stanzaId is.
			//
			// In order to get the stanzaId for a received element, we go through an asynchronous process.
			// It's possible (but unlikely) that this process ends up taking longer than it does for the app
			// to actually "handle" the element. So we have this odd edge case,
			// which we handle by queuing up the stanzaId for later processing.
			
			if (outstandingStanzaIds > 0)
			{
				if (pendingHandledStanzaIds == nil)
					pendingHandledStanzaIds = [[NSMutableArray alloc] init];
				
				[pendingHandledStanzaIds addObject:stanzaId];
			}
		}
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)processReceivedElement:(XMPPElement *)element
{
	XMPPLogTrace();
	
	NSAssert(isStarted, @"State machine exception");
	
	SEL selector = @selector(xmppStreamManagement:getIsHandled:stanzaId:forReceivedElement:);
	
	if (![multicastDelegate hasDelegateThatRespondsToSelector:selector])
	{
		// None of the delegates implement the method.
		// Use a shortcut.
		
		XMPPStreamManagementIncomingStanza *stanza =
		  [[XMPPStreamManagementIncomingStanza alloc] initWithStanzaId:nil isHandled:YES];
		[unackedByClient addObject:stanza];
		
		// Since we know the element is 'handled' we can immediately check to see if we need to send an ack
		
		if (![self maybeSendAck])
		{
			[self maybeUpdateStoredLastHandledByClient];
		}
	}
	else
	{
		// We need to query the delegate(s) to see if the stanza can be marked as handled.
		// This is an asynchronous process, so we put a placeholder in the array for now.
		//
		// Note: stanza.isHandled == NO
		
		XMPPStreamManagementIncomingStanza *stanza =
		  [[XMPPStreamManagementIncomingStanza alloc] initWithStanzaId:nil isHandled:NO];
		[unackedByClient addObject:stanza];
		
		// Query the delegate(s). The Rules:
		//
		// If ANY of the delegates says the element is "not handled", then we can immediately set it as so.
		// Otherwise the element will be marked as handled.
		
		GCDMulticastDelegateEnumerator *enumerator = [multicastDelegate delegateEnumerator];
		outstandingStanzaIds++;
		
		dispatch_queue_t concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
		dispatch_async(concurrentQueue, ^{ @autoreleasepool
		{
			__block BOOL isHandled = YES;
			__block id stanzaId = nil;
			
			id delegate;
			dispatch_queue_t dq;
		
			while (isHandled && [enumerator getNextDelegate:&delegate delegateQueue:&dq forSelector:selector])
			{
				dispatch_sync(dq, ^{ @autoreleasepool {
				
					[delegate xmppStreamManagement:self
					                  getIsHandled:&isHandled
					                      stanzaId:&stanzaId
					            forReceivedElement:element];
					
					NSAssert(isHandled || stanzaId != nil,
					         @"You MUST return a stanzaId for any elements you mark as not-yet-handled");
				}});
			}
			
			dispatch_async(moduleQueue, ^{ @autoreleasepool
			{
				if (isHandled)
				{
					stanza.isHandled = YES;
				}
				else
				{
					stanza.stanzaId = stanzaId;
					
					// Check for edge case:
					// - stanzaId was marked as handled before we figured out what the stanzaId was
					if ([pendingHandledStanzaIds count] > 0)
					{
						NSUInteger i = 0;
						for (id pendingStanzaId in pendingHandledStanzaIds)
						{
							if ([pendingStanzaId isEqual:stanzaId])
							{
								[pendingHandledStanzaIds removeObjectAtIndex:i];
								
								stanza.isHandled = YES;
								break;
							}
							
							i++;
						}
					}
				}
				
				// Defensive programming.
				// Don't let this array grow infinitely big (if markHandledStanzaId is being invoked incorrectly).
				if (--outstandingStanzaIds == 0) {
					[pendingHandledStanzaIds removeAllObjects];
				}
				
				if (stanza.isHandled)
				{
					if (![self maybeSendAck])
					{
						[self maybeUpdateStoredLastHandledByClient];
					}
				}
			}});
		}});
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Storage Helpers
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method is used when the pendingStanzaIds have changed (ivar unackedByServer changed),
 * but we weren't able to process an ack, or update the lastHandledByServer.
**/
- (void)updateStoredPendingOutgoingStanzas
{
	XMPPLogTrace();
	
	NSArray *pending = [[NSArray alloc] initWithArray:unackedByServer copyItems:YES];
	
	if (isStarted)
	{
		[storage setLastDisconnect:[NSDate date]
		       lastHandledByServer:lastHandledByServer
		    pendingOutgoingStanzas:pending
		                 forStream:xmppStream];
	}
	else
	{
		[storage setLastDisconnect:disconnectDate
		       lastHandledByClient:lastHandledByClient
		       lastHandledByServer:lastHandledByServer
		    pendingOutgoingStanzas:pending
		                 forStream:xmppStream];
	}
}

/**
 * This method is used when we can maybe increment the lastHandledByClient value,
 * but the change isn't significant enough to trigger an autoAck (or autoAck_stanzaCount is disabled).
 *
 * It updates the lastHandledByClient value (if needed), and notified storage.
**/
- (void)maybeUpdateStoredLastHandledByClient
{
	XMPPLogTrace();
	
	// Edge case note:
	//
	// This method may be invoked shortly after being disconnected.
	// How is this handled?
	//
	// The unackedByClient array is cleared when we send <enable> or <resume>.
	// And it cannot be appended to unless isStarted is YES.
	// Thus this method works properly shortly after a disconnect, and can increment lastHandledByClient.
	// And properly handles the edge case of being called in the middle of resuming a session.
	
	NSUInteger pending = 0;
	for (XMPPStreamManagementIncomingStanza *stanza in unackedByClient)
	{
		if (stanza.isHandled)
			pending++;
		else
			break;
	}
	
	if (pending > 0)
	{
		[unackedByClient removeObjectsInRange:NSMakeRange(0, pending)];
		unackedByClient_lastAckOffset += pending;
		lastHandledByClient += pending;
		
		XMPPLogVerbose(@"%@: sendAck: lastHandledByClient(%u) inc(%lu) totalPending(%lu)", THIS_FILE,
					   lastHandledByClient,
					   (unsigned long)pending,
					   (unsigned long)unackedByClient_lastAckOffset);
		
		if (isStarted)
		{
			[storage setLastDisconnect:[NSDate date]
			       lastHandledByClient:lastHandledByClient
			                 forStream:xmppStream];
		}
		else // edge case
		{
			// An incoming stanza got markedAsHandled post-disconnect
			
			NSArray *pending = [[NSArray alloc] initWithArray:unackedByServer copyItems:YES];
		
			[storage setLastDisconnect:disconnectDate
			       lastHandledByClient:lastHandledByClient
			       lastHandledByServer:lastHandledByServer
			    pendingOutgoingStanzas:pending
			                 forStream:xmppStream];
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Binding a JID resource is a standard part of the authentication process,
 * and occurs after SASL authentication completes (which generally authenticates the JID username).
 * 
 * This delegate method allows for a custom binding procedure to be used.
 * For example:
 * - a custom SASL authentication scheme might combine auth with binding
 * - stream management (xep-0198) replaces binding if it can resume a previous session
 * 
 * Return nil (or don't implement this method) if you wish to use the standard binding procedure.
**/
- (id <XMPPCustomBinding>)xmppStreamWillBind:(XMPPStream *)sender
{
	if (autoResume)
	{
		// We will check canResume in start: method (part of XMPPCustomBinding protocol)
		return self;
	}
	else
	{
		return nil;
	}
}

- (void)xmppStream:(XMPPStream *)sender didSendIQ:(XMPPIQ *)iq
{
	XMPPLogTrace();
	
	if (isStarted || enableSent)
	{
		[self processSentElement:iq];
	}
}

- (void)xmppStream:(XMPPStream *)sender didSendMessage:(XMPPMessage *)message
{
	XMPPLogTrace();
	
	if (isStarted || enableSent)
	{
		[self processSentElement:message];
	}
}

- (void)xmppStream:(XMPPStream *)sender didSendPresence:(XMPPPresence *)presence
{
	XMPPLogTrace();
	
	if (isStarted || enableSent)
	{
		[self processSentElement:presence];
	}
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	XMPPLogTrace();
	
	if (isStarted)
	{
		[self processReceivedElement:iq];
	}
	
	return NO;
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	XMPPLogTrace();
	
	if (isStarted)
	{
		[self processReceivedElement:message];
	}
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
	XMPPLogTrace();
	
	if (isStarted)
	{
		[self processReceivedElement:presence];
	}
}

/**
 * This method is called if any of the xmppStream:willReceiveX: methods filter the incoming stanza.
 *
 * It may be useful for some extensions to know that something was received,
 * even if it was filtered for some reason.
**/
- (void)xmppStreamDidFilterStanza:(XMPPStream *)sender
{
	XMPPLogTrace();
	
	if (isStarted)
	{
		// The element was filtered/consumed by something in the stack.
		// So it is implicitly 'handled'.
		
		XMPPStreamManagementIncomingStanza *stanza =
		  [[XMPPStreamManagementIncomingStanza alloc] initWithStanzaId:nil isHandled:YES];
		[unackedByClient addObject:stanza];
		
		XMPPLogVerbose(@"%@: xmppStreamDidFilterStanza: lastHandledByClient(%u) pendingToAck(%lu), pendingHandled(%lu)",
		               THIS_FILE, lastHandledByClient,
		               (unsigned long)[self numIncomingStanzasThatCanBeAcked],
		               (unsigned long)[self numIncomingStanzasThatCannnotBeAcked]);
		
		if (![self maybeSendAck])
		{
			[self maybeUpdateStoredLastHandledByClient];
		}
	}
}

- (void)xmppStream:(XMPPStream *)sender didSendCustomElement:(NSXMLElement *)element
{
	XMPPLogTrace();
	
	if (enableQueued)
	{
		if ([[element name] isEqualToString:@"enable"])
		{
			enableQueued = NO;
			enableSent = YES;
		}
	}
	else if (isStarted)
	{
		if ([[element name] isEqualToString:@"r"])
		{
			[multicastDelegate xmppStreamManagementDidRequestAck:self];
		}
	}
}

- (void)xmppStream:(XMPPStream *)sender didReceiveCustomElement:(NSXMLElement *)element
{
	XMPPLogTrace();
	
	NSString *elementName = [element name];
	
	if ([elementName isEqualToString:@"r"])
	{
		// We received a request <r/> from the server.
		
		if (ackResponseDelay <= 0.0)
		{
			// Immediately respond to the request,
			// as recommended in the XEP.
			
			[self _sendAck];
		}
		else if (ackResponseTimer == nil)
		{
			// Use client-configured delay before responding to the request.
			
			__weak id weakSelf = self;
			ackResponseTimer = [[XMPPTimer alloc] initWithQueue:moduleQueue eventHandler:^{ @autoreleasepool{
				
				[weakSelf _sendAck];
			}}];
			
			[ackResponseTimer startWithTimeout:ackResponseDelay interval:0];
		}
	}
	else if ([elementName isEqualToString:@"a"])
	{
		// Try to process the ack.
		// If we can't yet, then we'll put it into the pendingAcks array.
		
		if (![self processReceivedAck:element])
		{
			if (unprocessedReceivedAcks == nil)
				unprocessedReceivedAcks = [[NSMutableArray alloc] initWithCapacity:1];
			
			[unprocessedReceivedAcks addObject:element];
		}
	}
	else if ([elementName isEqualToString:@"enabled"])
	{
		if (enableSent)
		{
			// <enabled xmlns='urn:xmpp:sm:3' id='some-long-sm-id' resume='true'/>
			
			NSString *resumptionId = nil;
			uint32_t max = 0;
			
			BOOL canResume = [element attributeBoolValueForName:@"resume" withDefaultValue:NO];
			if (canResume)
			{
				resumptionId = [element attributeStringValueForName:@"id"];
				max = [element attributeUInt32ValueForName:@"max" withDefaultValue:requestedMax];
			}
			
			[storage setResumptionId:resumptionId
			                 timeout:max
			          lastDisconnect:[NSDate date]
			               forStream:xmppStream];
			
			[multicastDelegate xmppStreamManagement:self wasEnabled:element];
			
			isStarted = YES;
			enableSent = NO;
			
			lastHandledByClient = 0;
			lastHandledByServer = 0;
			
			unprocessedReceivedAcks = nil;
		}
		else
		{
			XMPPLogWarn(@"Received unrequested <enabled/> stanza");
		}
	}
	else if ([elementName isEqualToString:@"failed"])
	{
		if (enableSent)
		{
			[storage removeAllForStream:xmppStream];
			
			[multicastDelegate xmppStreamManagement:self wasNotEnabled:element];
			
			isStarted = NO;
			enableSent = NO;
			
			[autoRequestTimer cancel];
			autoRequestTimer = nil;
		}
	}
}

- (void)xmppStreamDidSendClosingStreamStanza:(XMPPStream *)sender
{
	XMPPLogTrace();
	
	wasCleanDisconnect = YES;
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
	XMPPLogTrace();
	
	if (wasCleanDisconnect)
	{
		disconnectDate = nil;
		[storage removeAllForStream:xmppStream];
	}
	else
	{
		disconnectDate = [NSDate date];
		NSArray *pending = [[NSArray alloc] initWithArray:unackedByServer copyItems:YES];
		
		[storage setLastDisconnect:disconnectDate
		       lastHandledByClient:lastHandledByClient
		       lastHandledByServer:lastHandledByServer
		    pendingOutgoingStanzas:pending
		                 forStream:xmppStream];
	}
	
	// Reset temporary state variables
	
	isStarted = NO;
	enableQueued = NO;
	enableSent = NO;
	
	wasCleanDisconnect = NO;
	
	didAttemptResume = NO;
	didResume = NO;
	
	prev_unackedByServer = nil;
	
	resume_response = nil;
	resume_stanzaIds = nil;
	
	// Cancel timers
	
	[autoRequestTimer cancel];
	autoRequestTimer = nil;
	
	[autoAckTimer cancel];
	autoAckTimer = nil;
	
	[ackResponseTimer cancel];
	ackResponseTimer = nil;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPStream (XMPPStreamManagement)

- (BOOL)supportsStreamManagement
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		// The root element can be properly queried anytime after the
		// stream:features are received, and TLS has been setup (if required).
		
		if (self.state >= STATE_XMPP_POST_NEGOTIATION)
		{
			NSXMLElement *features = [self.rootElement elementForName:@"stream:features"];
			NSXMLElement *sm = [features elementForName:@"sm" xmlns:XMLNS_STREAM_MANAGEMENT];
			
			result = (sm != nil);
		}
	}};
	
	if (dispatch_get_specific(self.xmppQueueTag))
		block();
	else
		dispatch_sync(self.xmppQueue, block);
	
	return result;
}

@end
