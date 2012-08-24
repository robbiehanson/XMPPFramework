#import "TURNSocket.h"
#import "XMPP.h"
#import "XMPPLogging.h"
#import "GCDAsyncSocket.h"
#import "NSData+XMPP.h"
#import "NSNumber+XMPP.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

/**
 * Does ARC support support GCD objects?
 * It does if the minimum deployment target is iOS 6+ or Mac OS X 10.8+
**/
#if TARGET_OS_IPHONE

  // Compiling for iOS

  #if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000 // iOS 6.0 or later
    #define NEEDS_DISPATCH_RETAIN_RELEASE 0
  #else                                         // iOS 5.X or earlier
    #define NEEDS_DISPATCH_RETAIN_RELEASE 1
  #endif

#else

  // Compiling for Mac OS X

  #if MAC_OS_X_VERSION_MIN_REQUIRED >= 1080     // Mac OS X 10.8 or later
    #define NEEDS_DISPATCH_RETAIN_RELEASE 0
  #else
    #define NEEDS_DISPATCH_RETAIN_RELEASE 1     // Mac OS X 10.7 or earlier
  #endif

#endif

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

// Define various states
#define STATE_INIT                0

#define STATE_PROXY_DISCO_ITEMS  10
#define STATE_PROXY_DISCO_INFO   11
#define STATE_PROXY_DISCO_ADDR   12
#define STATE_REQUEST_SENT       13
#define STATE_INITIATOR_CONNECT  14
#define STATE_ACTIVATE_SENT      15
#define STATE_TARGET_CONNECT     20
#define STATE_DONE               30
#define STATE_FAILURE            31

// Define various socket tags
#define SOCKS_OPEN             101
#define SOCKS_CONNECT          102
#define SOCKS_CONNECT_REPLY_1  103
#define SOCKS_CONNECT_REPLY_2  104

// Define various timeouts (in seconds)
#define TIMEOUT_DISCO_ITEMS   8.00
#define TIMEOUT_DISCO_INFO    8.00
#define TIMEOUT_DISCO_ADDR    5.00
#define TIMEOUT_CONNECT       8.00
#define TIMEOUT_READ          5.00
#define TIMEOUT_TOTAL        80.00

// Declare private methods
@interface TURNSocket (PrivateAPI)
- (void)processDiscoItemsResponse:(XMPPIQ *)iq;
- (void)processDiscoInfoResponse:(XMPPIQ *)iq;
- (void)processDiscoAddressResponse:(XMPPIQ *)iq;
- (void)processRequestResponse:(XMPPIQ *)iq;
- (void)processActivateResponse:(XMPPIQ *)iq;
- (void)performPostInitSetup;
- (void)queryProxyCandidates;
- (void)queryNextProxyCandidate;
- (void)queryCandidateJIDs;
- (void)queryNextCandidateJID;
- (void)queryProxyAddress;
- (void)targetConnect;
- (void)targetNextConnect;
- (void)initiatorConnect;
- (void)setupDiscoTimerForDiscoItems;
- (void)setupDiscoTimerForDiscoInfo;
- (void)setupDiscoTimerForDiscoAddress;
- (void)doDiscoItemsTimeout:(NSString *)uuid;
- (void)doDiscoInfoTimeout:(NSString *)uuid;
- (void)doDiscoAddressTimeout:(NSString *)uuid;
- (void)doTotalTimeout;
- (void)succeed;
- (void)fail;
- (void)cleanup;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation TURNSocket

static NSMutableDictionary *existingTurnSockets;
static NSMutableArray *proxyCandidates;

/**
 * Called automatically (courtesy of Cocoa) before the first method of this class is called.
 * It may also be called directly, hence the safety mechanism.
**/
+ (void)initialize
{
	static BOOL initialized = NO;
	if (!initialized)
	{
		initialized = YES;
		
		existingTurnSockets = [[NSMutableDictionary alloc] init];
		proxyCandidates = [[NSMutableArray alloc] initWithObjects:@"jabber.org", nil];
	}
}

/**
 * Returns whether or not the given IQ is a new start TURN request.
 * That is, the IQ must have a query with the proper namespace,
 * and it must not correspond to an existing TURNSocket.
**/
+ (BOOL)isNewStartTURNRequest:(XMPPIQ *)iq
{
	XMPPLogTrace();
	
	// An incoming turn request looks like this:
	// 
	// <iq type="set" from="[jid full]" id="uuid">
	//   <query xmlns="http://jabber.org/protocol/bytestreams" sid="uuid" mode="tcp">
	//     <streamhosts>
	//       <streamhost jid="proxy1.domain.tld" host="100.200.30.41" port"6969"/>
	//       <streamhost jid="proxy2.domain.tld" host="100.200.30.42" port"6969"/>
	//     </streamhosts>
	//   </query>
	// </iq>
	// 
	// From XEP 65 (9.1):
	// The 'mode' attribute specifies the mode to use, either "tcp" or "udp".
	// If this attribute is not included, the default value of "tcp" MUST be assumed.
	// This attribute is OPTIONAL.
	
	NSXMLElement *query = [iq elementForName:@"query" xmlns:@"http://jabber.org/protocol/bytestreams"];
	if (query == nil) {
		return NO;
	}
	
	NSString *queryMode = [[query attributeForName:@"mode"] stringValue];
	
	BOOL isTcpBytestreamQuery = YES;
	if (queryMode)
	{
		isTcpBytestreamQuery = [queryMode caseInsensitiveCompare:@"tcp"] == NSOrderedSame;
	}
	
	if (isTcpBytestreamQuery)
	{
		NSString *uuid = [iq elementID];
		
		@synchronized(existingTurnSockets)
		{
			if ([existingTurnSockets objectForKey:uuid])
				return NO;
			else
				return YES;
		}
	}
	return NO;
}

/**
 * Returns a list of proxy candidates.
 * 
 * You may want to configure this to include NSUserDefaults stuff, or implement your own static/dynamic list.
**/
+ (NSArray *)proxyCandidates
{
	NSArray *result = nil;
	
	@synchronized(proxyCandidates)
	{
		XMPPLogTrace();
		
		result = [proxyCandidates copy];
	}
	
	return result;
}

+ (void)setProxyCandidates:(NSArray *)candidates
{
	@synchronized(proxyCandidates)
	{
		XMPPLogTrace();
		
		[proxyCandidates removeAllObjects];
		[proxyCandidates addObjectsFromArray:candidates];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Init, Dealloc
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Initializes a new TURN socket to create a TCP connection by routing through a proxy.
 * This constructor configures the object to be the client connecting to a server.
**/
- (id)initWithStream:(XMPPStream *)stream toJID:(XMPPJID *)aJid
{
	if ((self = [super init]))
	{
		XMPPLogTrace();
		
		// Store references
		xmppStream = stream;
		jid = aJid;
		
		// Create a uuid to be used as the id for all messages in the stun communication.
		// This helps differentiate various turn messages between various turn sockets.
		// Relying only on JID's is troublesome, because client A could be initiating a connection to server B,
		// while at the same time client B could be initiating a connection to server A.
		// So an incoming connection from JID clientB@deusty.com/home would be for which turn socket?
		uuid = [xmppStream generateUUID];
		
		// Setup initial state for a client connection
		state = STATE_INIT;
		isClient = YES;
		
		// Get list of proxy candidates
		// Each host in this list will be queried to see if it can be used as a proxy
		proxyCandidates = [[self class] proxyCandidates];
		
		// Configure everything else
		[self performPostInitSetup];
	}
	return self;
}

/**
 * Initializes a new TURN socket to create a TCP connection by routing through a proxy.
 * This constructor configures the object to be the server accepting a connection from a client.
**/
- (id)initWithStream:(XMPPStream *)stream incomingTURNRequest:(XMPPIQ *)iq
{
	if ((self = [super init]))
	{
		XMPPLogTrace();
		
		// Store references
		xmppStream = stream;
		jid = [iq from];
		
		// Store a copy of the ID (which will be our uuid)
		uuid = [[iq elementID] copy];
		
		// Setup initial state for a server connection
		state = STATE_INIT;
		isClient = NO;
		
		// Extract streamhost information from turn request
		NSXMLElement *query = [iq elementForName:@"query" xmlns:@"http://jabber.org/protocol/bytestreams"];
		streamhosts = [[query elementsForName:@"streamhost"] mutableCopy];
		
		// Configure everything else
		[self performPostInitSetup];
	}
	return self;
}

/**
 * Common initialization tasks shared by all init methods.
**/
- (void)performPostInitSetup
{
	// Create dispatch queue.
	
	turnQueue = dispatch_queue_create("TURNSocket", NULL);
	
	// We want to add this new turn socket to the list of existing sockets.
	// This gives us a central repository of turn socket objects that we can easily query.
	
	@synchronized(existingTurnSockets)
	{
		[existingTurnSockets setObject:self forKey:uuid];
	}
}

/**
 * Standard deconstructor.
 * Release any objects we may have retained.
 * These objects should all be defined in the header.
**/
- (void)dealloc
{
	XMPPLogTrace();
	
	if ((state > STATE_INIT) && (state < STATE_DONE))
	{
		XMPPLogWarn(@"%@: Deallocating prior to completion or cancellation. "
					@"You should explicitly cancel before releasing.", THIS_FILE);
	}
	
	if (turnTimer)
		dispatch_source_cancel(turnTimer);
	
	if (discoTimer)
		dispatch_source_cancel(discoTimer);
	
	#if NEEDS_DISPATCH_RETAIN_RELEASE
	if (turnQueue)
		dispatch_release(turnQueue);
	
	if (delegateQueue)
		dispatch_release(delegateQueue);
	
	if (turnTimer)
		dispatch_release(turnTimer);
	
	if (discoTimer)
		dispatch_release(discoTimer);
	#endif
	
	if ([asyncSocket delegate] == self)
	{
		[asyncSocket setDelegate:nil delegateQueue:NULL];
		[asyncSocket disconnect];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Correspondence Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Starts the TURNSocket with the given delegate.
 * If the TURNSocket has already been started, this method does nothing, and the existing delegate is not changed.
**/
- (void)startWithDelegate:(id)aDelegate delegateQueue:(dispatch_queue_t)aDelegateQueue
{
	NSParameterAssert(aDelegate != nil);
	NSParameterAssert(aDelegateQueue != NULL);
	
	dispatch_async(turnQueue, ^{ @autoreleasepool {
		
		if (state != STATE_INIT)
		{
			XMPPLogWarn(@"%@: Ignoring start request. Turn procedure already started.", THIS_FILE);
			return;
		}
		
		// Set reference to delegate and delegate's queue.
		// Note that we do NOT retain the delegate.
		
		delegate = aDelegate;
		delegateQueue = aDelegateQueue;
		
		#if NEEDS_DISPATCH_RETAIN_RELEASE
		dispatch_retain(delegateQueue);
		#endif
		
		// Add self as xmpp delegate so we'll get message responses
		[xmppStream addDelegate:self delegateQueue:turnQueue];
		
		// Start the timer to calculate how long the procedure takes
		startTime = [[NSDate alloc] init];
		
		// Schedule timer to cancel the turn procedure.
		// This ensures that, in the event of network error or crash,
		// the TURNSocket object won't remain in memory forever, and will eventually fail.
		
		turnTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, turnQueue);
		
		dispatch_source_set_event_handler(turnTimer, ^{ @autoreleasepool {
			
			[self doTotalTimeout];
			
		}});
		
		dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (TIMEOUT_TOTAL * NSEC_PER_SEC));
		
		dispatch_source_set_timer(turnTimer, tt, DISPATCH_TIME_FOREVER, 0.1);
		dispatch_resume(turnTimer);
		
		// Start the TURN procedure
		
		if (isClient)
			[self queryProxyCandidates];
		else
			[self targetConnect];
		
	}});
}

/**
 * Returns the type of connection
 * YES for a client connection to a server, NO for a server connection from a client.
**/
- (BOOL)isClient
{
	// Note: The isClient variable is readonly (set in the init method).
	
	return isClient;
}

/**
 * Aborts the TURN connection attempt.
 * The status will be changed to failure, and no delegate messages will be posted.
**/
- (void)abort
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if ((state > STATE_INIT) && (state < STATE_DONE))
		{
			// The only thing we really have to do here is move the state to failure.
			// This simple act should prevent any further action from being taken in this TUNRSocket object,
			// since every action is dictated based on the current state.
			state = STATE_FAILURE;
			
			// And don't forget to cleanup after ourselves
			[self cleanup];
		}
	}};
	
	if (dispatch_get_current_queue() == turnQueue)
		block();
	else
		dispatch_async(turnQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Communication
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Sends the request, from initiator to target, to start a connection to one of the streamhosts.
 * This method automatically updates the state.
**/
- (void)sendRequest
{
	NSAssert(isClient, @"Only the Initiator sends the request");
	
	XMPPLogTrace();
	
	// <iq type="set" to="target" id="123">
	//   <query xmlns="http://jabber.org/protocol/bytestreams" sid="123" mode="tcp">
	//     <streamhost jid="proxy.domain1.org" host="100.200.300.401" port="7777"/>
	//     <streamhost jid="proxy.domain2.org" host="100.200.300.402" port="7777"/>
	//   </query>
	// </iq>
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"http://jabber.org/protocol/bytestreams"];
	[query addAttributeWithName:@"sid" stringValue:uuid];
	[query addAttributeWithName:@"mode" stringValue:@"tcp"];
	
	NSUInteger i;
	for(i = 0; i < [streamhosts count]; i++)
	{
		[query addChild:[streamhosts objectAtIndex:i]];
	}
	
	XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:jid elementID:uuid child:query];
	
	[xmppStream sendElement:iq];
	
	// Update state
	state = STATE_REQUEST_SENT;
}

/**
 * Sends the reply, from target to initiator, notifying the initiator of the streamhost we connected to.
**/
- (void)sendReply
{
	NSAssert(!isClient, @"Only the Target sends the reply");
	
	XMPPLogTrace();
	
	// <iq type="result" to="initiator" id="123">
	//   <query xmlns="http://jabber.org/protocol/bytestreams" sid="123">
	//     <streamhost-used jid="proxy.domain"/>
	//   </query>
	// </iq>
	
	NSXMLElement *streamhostUsed = [NSXMLElement elementWithName:@"streamhost-used"];
	[streamhostUsed addAttributeWithName:@"jid" stringValue:[proxyJID full]];
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"http://jabber.org/protocol/bytestreams"];
	[query addAttributeWithName:@"sid" stringValue:uuid];
	[query addChild:streamhostUsed];
	
	XMPPIQ *iq = [XMPPIQ iqWithType:@"result" to:jid elementID:uuid child:query];
	
	[xmppStream sendElement:iq];
}

/**
 * Sends the activate message to the proxy after the target and initiator are both connected to the proxy.
 * This method automatically updates the state.
**/
- (void)sendActivate
{
	NSAssert(isClient, @"Only the Initiator activates the proxy");
	
	XMPPLogTrace();
	
	NSXMLElement *activate = [NSXMLElement elementWithName:@"activate" stringValue:[jid full]];
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"http://jabber.org/protocol/bytestreams"];
	[query addAttributeWithName:@"sid" stringValue:uuid];
	[query addChild:activate];
	
	XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:proxyJID elementID:uuid child:query];
	
	[xmppStream sendElement:iq];
	
	// Update state
	state = STATE_ACTIVATE_SENT;
}

/**
 * Sends the error, from target to initiator, notifying the initiator we were unable to connect to any streamhost.
**/
- (void)sendError
{
	NSAssert(!isClient, @"Only the Target sends the error");
	
	XMPPLogTrace();
	
	// <iq type="error" to="initiator" id="123">
	//   <error code="404" type="cancel">
	//     <item-not-found xmlns="urn:ietf:params:xml:ns:xmpp-stanzas">
	//   </error>
	// </iq>
	
	NSXMLElement *inf = [NSXMLElement elementWithName:@"item-not-found" xmlns:@"urn:ietf:params:xml:ns:xmpp-stanzas"];
	
	NSXMLElement *error = [NSXMLElement elementWithName:@"error"];
	[error addAttributeWithName:@"code" stringValue:@"404"];
	[error addAttributeWithName:@"type" stringValue:@"cancel"];
	[error addChild:inf];
	
	XMPPIQ *iq = [XMPPIQ iqWithType:@"error" to:jid elementID:uuid child:error];
	
	[xmppStream sendElement:iq];
}

/**
 * Invoked by XMPPClient when an IQ is received.
 * We can determine if the IQ applies to us by checking its element ID.
**/
- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	// Disco queries (sent to jabber server) use id=discoUUID
	// P2P queries (sent to other Mojo app) use id=uuid
	
	if (state <= STATE_PROXY_DISCO_ADDR)
	{
		if (![discoUUID isEqualToString:[iq elementID]])
		{
			// Doesn't apply to us, or is a delayed response that we've decided to ignore
			return NO;
		}
	}
	else
	{
		if (![uuid isEqualToString:[iq elementID]])
		{
			// Doesn't apply to us
			return NO;
		}
	}
	
	XMPPLogTrace2(@"%@: %@ - state(%i)", THIS_FILE, THIS_METHOD, state);
	
	if (state == STATE_PROXY_DISCO_ITEMS)
	{
		[self processDiscoItemsResponse:iq];
	}
	else if (state == STATE_PROXY_DISCO_INFO)
	{
		[self processDiscoInfoResponse:iq];
	}
	else if (state == STATE_PROXY_DISCO_ADDR)
	{
		[self processDiscoAddressResponse:iq];
	}
	else if (state == STATE_REQUEST_SENT)
	{
		[self processRequestResponse:iq];
	}
	else if (state == STATE_ACTIVATE_SENT)
	{
		[self processActivateResponse:iq];
	}
	
	return YES;
}

- (void)processDiscoItemsResponse:(XMPPIQ *)iq
{
	XMPPLogTrace();
	
	// We queried the current proxy candidate for all known JIDs in it's disco list.
	// 
	// <iq from="domain.org" to="initiator" id="123" type="result">
	//   <query xmlns="http://jabber.org/protocol/disco#items">
	//     <item jid="conference.domain.org"/>
	//     <item jid="proxy.domain.org"/>
	//   </query>
	// </iq>
	
	NSXMLElement *query = [iq elementForName:@"query" xmlns:@"http://jabber.org/protocol/disco#items"];
	NSArray *items = [query elementsForName:@"item"];
	
	candidateJIDs = [[NSMutableArray alloc] initWithCapacity:[items count]];
	
	NSUInteger i;
	for(i = 0; i < [items count]; i++)
	{
		NSString *itemJidStr = [[[items objectAtIndex:i] attributeForName:@"jid"] stringValue];
		XMPPJID *itemJid = [XMPPJID jidWithString:itemJidStr];
		
		if(itemJid)
		{
			[candidateJIDs addObject:itemJid];
		}
	}
	
	[self queryCandidateJIDs];
}

- (void)processDiscoInfoResponse:(XMPPIQ *)iq
{
	XMPPLogTrace();
	
	// We queried a potential proxy server to see if it was indeed a proxy.
	// 
	// <iq from="domain.org" to="initiator" id="123" type="result">
	//   <query xmlns="http://jabber.org/protocol/disco#info">
	//     <identity category="proxy" type="bytestreams" name="SOCKS5 Bytestreams Service"/>
	//     <feature var="http://jabber.org/protocol/bytestreams"/>
	//   </query>
	// </iq>
	
	NSXMLElement *query = [iq elementForName:@"query" xmlns:@"http://jabber.org/protocol/disco#info"];
	NSArray *identities = [query elementsForName:@"identity"];
	
	BOOL found = NO;
	
	NSUInteger i;
	for(i = 0; i < [identities count] && !found; i++)
	{
		NSXMLElement *identity = [identities objectAtIndex:i];
		
		NSString *category = [[identity attributeForName:@"category"] stringValue];
		NSString *type = [[identity attributeForName:@"type"] stringValue];
		
		if([category isEqualToString:@"proxy"] && [type isEqualToString:@"bytestreams"])
		{
			found = YES;
		}
	}
	
	if(found)
	{
		// We found a proxy service!
		// Now we query the proxy for its public IP and port.
		[self queryProxyAddress];
	}
	else
	{
		// There are many jabber servers out there that advertise a proxy service via JID proxy.domain.tld.
		// However, not all of these servers have an entry for proxy.domain.tld in the DNS servers.
		// Thus, when we try to query the proxy JID, we end up getting a 404 error because our
		// jabber server was unable to connect to the given JID.
		// 
		// We could ignore the 404 error, and try to connect anyways,
		// but this would be useless because we'd be unable to activate the stream later.
		
		XMPPJID *candidateJID = [candidateJIDs objectAtIndex:candidateJIDIndex];
		
		// So the service was not a useable proxy service, or will not allow us to use its proxy.
		// 
		// Now most servers have serveral services such as proxy, conference, pubsub, etc.
		// If we queried a JID that started with "proxy", and it said no,
		// chances are that none of the other services are proxies either,
		// so we might as well not waste our time querying them.
		
		if([[candidateJID domain] hasPrefix:@"proxy"])
		{
			// Move on to the next server
			[self queryNextProxyCandidate];
		}
		else
		{
			// Try the next JID in the list from the server
			[self queryNextCandidateJID];
		}
	}
}

- (void)processDiscoAddressResponse:(XMPPIQ *)iq
{
	XMPPLogTrace();
	
	// We queried a proxy for its public IP and port.
	// 
	// <iq from="domain.org" to="initiator" id="123" type="result">
	//   <query xmlns="http://jabber.org/protocol/bytestreams">
	//     <streamhost jid="proxy.domain.org" host="100.200.300.400" port="7777"/>
	//   </query>
	// </iq>
	
	NSXMLElement *query = [iq elementForName:@"query" xmlns:@"http://jabber.org/protocol/bytestreams"];
	NSXMLElement *streamhost = [query elementForName:@"streamhost"];
	
	NSString *jidStr = [[streamhost attributeForName:@"jid"] stringValue];
	XMPPJID *streamhostJID = [XMPPJID jidWithString:jidStr];
	
	NSString *host = [[streamhost attributeForName:@"host"] stringValue];
	UInt16 port = [[[streamhost attributeForName:@"port"] stringValue] intValue];
	
	if(streamhostJID != nil || host != nil || port > 0)
	{
		[streamhost detach];
		[streamhosts addObject:streamhost];
	}
	
	// Finished with the current proxy candidate - move on to the next
	[self queryNextProxyCandidate];
}

- (void)processRequestResponse:(XMPPIQ *)iq
{
	XMPPLogTrace();
	
	// Target has replied - hopefully they've been able to connect to one of the streamhosts
	
	NSXMLElement *query = [iq elementForName:@"query" xmlns:@"http://jabber.org/protocol/bytestreams"];
	NSXMLElement *streamhostUsed = [query elementForName:@"streamhost-used"];
	
	NSString *streamhostUsedJID = [[streamhostUsed attributeForName:@"jid"] stringValue];
	
	BOOL found = NO;
	NSUInteger i;
	for(i = 0; i < [streamhosts count] && !found; i++)
	{
		NSXMLElement *streamhost = [streamhosts objectAtIndex:i];
		
		NSString *streamhostJID = [[streamhost attributeForName:@"jid"] stringValue];
		
		if([streamhostJID isEqualToString:streamhostUsedJID])
		{
			NSAssert(proxyJID == nil && proxyHost == nil, @"proxy and proxyHost are expected to be nil");
			
			proxyJID = [XMPPJID jidWithString:streamhostJID];
			
			proxyHost = [[streamhost attributeForName:@"host"] stringValue];
			if([proxyHost isEqualToString:@"0.0.0.0"])
			{
				proxyHost = [proxyJID full];
			}
			
			proxyPort = [[[streamhost attributeForName:@"port"] stringValue] intValue];
			
			found = YES;
		}
	}
	
	if(found)
	{
		// The target is connected to the proxy
		// Now it's our turn to connect
		[self initiatorConnect];
	}
	else
	{
		// Target was unable to connect to any of the streamhosts we sent it
		[self fail];
	}
}

- (void)processActivateResponse:(XMPPIQ *)iq
{
	XMPPLogTrace();
	
	NSString *type = [[iq attributeForName:@"type"] stringValue];
	
	BOOL activated = NO;
	if (type)
	{
		activated = [type caseInsensitiveCompare:@"result"] == NSOrderedSame;
	}
	
	if (activated) {
		[self succeed];
	}
	else {
		[self fail];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Proxy Discovery
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Each query we send during the proxy discovery process has a different element id.
 * This allows us to easily use timeouts, so we can recover from offline servers, and overly slow servers.
 * In other words, changing the discoUUID allows us to easily ignore delayed responses from a server.
**/
- (void)updateDiscoUUID
{
	discoUUID = [xmppStream generateUUID];
}

/**
 * Initiates the process of querying each item in the proxyCandidates array to determine if it supports XEP-65.
 * In order to do this we have to:
 * - ask the server for a list of services, which returns a list of JIDs
 * - query each service JID to determine if it's a proxy
 * - if it is a proxy, we ask the proxy for it's public IP and port
**/
- (void)queryProxyCandidates
{
	XMPPLogTrace();
	
	// Prepare the streamhosts array, which will hold all of our results
	streamhosts = [[NSMutableArray alloc] initWithCapacity:[proxyCandidates count]];
	
	// Start querying each candidate in order
	proxyCandidateIndex = -1;
	[self queryNextProxyCandidate];
}

/**
 * Queries the next proxy candidate in the list.
 * If we've queried every candidate, then sends the request to the target, or fails if no proxies were found.
**/
- (void)queryNextProxyCandidate
{
	XMPPLogTrace();
	
	// Update state
	state = STATE_PROXY_DISCO_ITEMS;
	
	// We start off with multiple proxy candidates (servers that have been known to be proxy servers in the past).
	// We can stop when we've found at least 2 proxies.
	
	XMPPJID *proxyCandidateJID = nil;
	
	if ([streamhosts count] < 2)
	{
		while ((proxyCandidateJID == nil) && (++proxyCandidateIndex < [proxyCandidates count]))
		{
			NSString *proxyCandidate = [proxyCandidates objectAtIndex:proxyCandidateIndex];
			proxyCandidateJID = [XMPPJID jidWithString:proxyCandidate];
			
			if (proxyCandidateJID == nil)
			{
				XMPPLogWarn(@"%@: Invalid proxy candidate '%@', not a valid JID", THIS_FILE, proxyCandidate);
			}
		}
	}
	
	if (proxyCandidateJID)
	{
		[self updateDiscoUUID];
		
		NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"http://jabber.org/protocol/disco#items"];
		
		XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:proxyCandidateJID elementID:discoUUID child:query];
		
		[xmppStream sendElement:iq];
		
		[self setupDiscoTimerForDiscoItems];
	}
	else
	{
		if ([streamhosts count] > 0)
		{
			// We've got a list of potential proxy servers to send to the initiator
			
			XMPPLogVerbose(@"%@: Streamhosts: \n%@", THIS_FILE, streamhosts);
			
			[self sendRequest];
		}
		else
		{
			// We were unable to find a single proxy server from our list
			
			XMPPLogVerbose(@"%@: No proxies found", THIS_FILE);
			
			[self fail];
		}
	}
}

/**
 * Initiates the process of querying each candidate JID to determine if it represents a proxy service.
 * This process will be stopped when a proxy service is found, or after each candidate JID has been queried.
**/
- (void)queryCandidateJIDs
{
	XMPPLogTrace();
	
	// Most of the time, the proxy will have a domain name that includes the word "proxy".
	// We can speed up the process of discovering the proxy by searching for these domains, and querying them first.
	
	NSUInteger i;
	for (i = 0; i < [candidateJIDs count]; i++)
	{
		XMPPJID *candidateJID = [candidateJIDs objectAtIndex:i];
		
		NSRange proxyRange = [[candidateJID domain] rangeOfString:@"proxy" options:NSCaseInsensitiveSearch];
		
		if (proxyRange.length > 0)
		{
			[candidateJIDs removeObjectAtIndex:i];
			[candidateJIDs insertObject:candidateJID atIndex:0];
		}
	}
	
	XMPPLogVerbose(@"%@: CandidateJIDs: \n%@", THIS_FILE, candidateJIDs);
	
	// Start querying each candidate in order (we can stop when we find one)
	candidateJIDIndex = -1;
	[self queryNextCandidateJID];
}

/**
 * Queries the next candidate JID in the list.
 * If we've queried every item, we move on to the next proxy candidate.
**/
- (void)queryNextCandidateJID
{
	XMPPLogTrace();
	
	// Update state
	state = STATE_PROXY_DISCO_INFO;
	
	candidateJIDIndex++;
	if (candidateJIDIndex < [candidateJIDs count])
	{
		[self updateDiscoUUID];
		
		XMPPJID *candidateJID = [candidateJIDs objectAtIndex:candidateJIDIndex];
		
		NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"http://jabber.org/protocol/disco#info"];
		
		XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:candidateJID elementID:discoUUID child:query];
		
		[xmppStream sendElement:iq];
		
		[self setupDiscoTimerForDiscoInfo];
	}
	else
	{
		// Ran out of candidate JIDs for the current proxy candidate.
		// Time to move on to the next proxy candidate.
		[self queryNextProxyCandidate];
	}
}

/**
 * Once we've discovered a proxy service, we need to query it to obtain its public IP and port.
**/
- (void)queryProxyAddress
{
	XMPPLogTrace();
	
	// Update state
	state = STATE_PROXY_DISCO_ADDR;
	
	[self updateDiscoUUID];
	
	XMPPJID *candidateJID = [candidateJIDs objectAtIndex:candidateJIDIndex];
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"http://jabber.org/protocol/bytestreams"];
	
	XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:candidateJID elementID:discoUUID child:query];
	
	[xmppStream sendElement:iq];
	
	[self setupDiscoTimerForDiscoAddress];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Proxy Connection
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)targetConnect
{
	XMPPLogTrace();
	
	// Update state
	state = STATE_TARGET_CONNECT;
	
	// Start trying to connect to each streamhost in order
	streamhostIndex = -1;
	[self targetNextConnect];
}

- (void)targetNextConnect
{
	XMPPLogTrace();
	
	streamhostIndex++;
	if(streamhostIndex < [streamhosts count])
	{
		NSXMLElement *streamhost = [streamhosts objectAtIndex:streamhostIndex];
		
		
		proxyJID = [XMPPJID jidWithString:[[streamhost attributeForName:@"jid"] stringValue]];
		
		proxyHost = [[streamhost attributeForName:@"host"] stringValue];
		if([proxyHost isEqualToString:@"0.0.0.0"])
		{
			proxyHost = [proxyJID full];
		}
		
		proxyPort = [[[streamhost attributeForName:@"port"] stringValue] intValue];
		
		if (asyncSocket == nil)
		{
			asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:turnQueue];
		}
		else
		{
			NSAssert([asyncSocket isDisconnected], @"Expecting the socket to be disconnected at this point...");
		}
		
		XMPPLogVerbose(@"TURNSocket: targetNextConnect: %@(%@:%hu)", [proxyJID full], proxyHost, proxyPort);
		
		NSError *err = nil;
		if (![asyncSocket connectToHost:proxyHost onPort:proxyPort withTimeout:TIMEOUT_CONNECT error:&err])
		{
			XMPPLogError(@"TURNSocket: targetNextConnect: err: %@", err);
			[self targetNextConnect];
		}
	}
	else
	{
		[self sendError];
		[self fail];
	}
}

- (void)initiatorConnect
{
	NSAssert(asyncSocket == nil, @"Expecting asyncSocket to be nil");
	
	asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:turnQueue];
	
	XMPPLogVerbose(@"TURNSocket: initiatorConnect: %@(%@:%hu)", [proxyJID full], proxyHost, proxyPort);
	
	NSError *err = nil;
	if (![asyncSocket connectToHost:proxyHost onPort:proxyPort withTimeout:TIMEOUT_CONNECT error:&err])
	{
		XMPPLogError(@"TURNSocket: initiatorConnect: err: %@", err);
		[self fail];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark SOCKS
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Sends the SOCKS5 open/handshake/authentication data, and starts reading the response.
 * We attempt to gain anonymous access (no authentication).
**/
- (void)socksOpen
{
	XMPPLogTrace();
	
	//      +-----+-----------+---------+
	// NAME | VER | NMETHODS  | METHODS |
	//      +-----+-----------+---------+
	// SIZE |  1  |    1      | 1 - 255 |
	//      +-----+-----------+---------+
	//
	// Note: Size is in bytes
	// 
	// Version    = 5 (for SOCKS5)
	// NumMethods = 1
	// Method     = 0 (No authentication, anonymous access)
	
	void *byteBuffer = malloc(3);
	
	UInt8 ver = 5;
	memcpy(byteBuffer+0, &ver, sizeof(ver));
	
	UInt8 nMethods = 1;
	memcpy(byteBuffer+1, &nMethods, sizeof(nMethods));
	
	UInt8 method = 0;
	memcpy(byteBuffer+2, &method, sizeof(method));
	
	NSData *data = [NSData dataWithBytesNoCopy:byteBuffer length:3 freeWhenDone:YES];
	XMPPLogVerbose(@"TURNSocket: SOCKS_OPEN: %@", data);
	
	[asyncSocket writeData:data withTimeout:-1 tag:SOCKS_OPEN];
	
	//      +-----+--------+
	// NAME | VER | METHOD |
	//      +-----+--------+
	// SIZE |  1  |   1    |
	//      +-----+--------+
	//
	// Note: Size is in bytes
	// 
	// Version = 5 (for SOCKS5)
	// Method  = 0 (No authentication, anonymous access)
	
	[asyncSocket readDataToLength:2 withTimeout:TIMEOUT_READ tag:SOCKS_OPEN];
}

/**
 * Sends the SOCKS5 connect data (according to XEP-65), and starts reading the response.
**/
- (void)socksConnect
{
	XMPPLogTrace();
	
	XMPPJID *myJID = [xmppStream myJID];
	
	// From XEP-0065:
	// 
	// The [address] MUST be SHA1(SID + Initiator JID + Target JID) and
	// the output is hexadecimal encoded (not binary).
	
	XMPPJID *initiatorJID = isClient ? myJID : jid;
	XMPPJID *targetJID    = isClient ? jid   : myJID;
	
	NSString *hashMe = [NSString stringWithFormat:@"%@%@%@", uuid, [initiatorJID full], [targetJID full]];
	NSData *hashRaw = [[hashMe dataUsingEncoding:NSUTF8StringEncoding] sha1Digest];
	NSData *hash = [[hashRaw hexStringValue] dataUsingEncoding:NSUTF8StringEncoding];
	
	XMPPLogVerbose(@"TURNSocket: hashMe : %@", hashMe);
	XMPPLogVerbose(@"TURNSocket: hashRaw: %@", hashRaw);
	XMPPLogVerbose(@"TURNSocket: hash   : %@", hash);
	
	//      +-----+-----+-----+------+------+------+
	// NAME | VER | CMD | RSV | ATYP | ADDR | PORT |
	//      +-----+-----+-----+------+------+------+
	// SIZE |  1  |  1  |  1  |  1   | var  |  2   |
	//      +-----+-----+-----+------+------+------+
	//
	// Note: Size is in bytes
	// 
	// Version      = 5 (for SOCKS5)
	// Command      = 1 (for Connect)
	// Reserved     = 0
	// Address Type = 3 (1=IPv4, 3=DomainName 4=IPv6)
	// Address      = P:D (P=LengthOfDomain D=DomainWithoutNullTermination)
	// Port         = 0
	
	uint byteBufferLength = (uint)(4 + 1 + [hash length] + 2);
	void *byteBuffer = malloc(byteBufferLength);
	
	UInt8 ver = 5;
	memcpy(byteBuffer+0, &ver, sizeof(ver));
	
	UInt8 cmd = 1;
	memcpy(byteBuffer+1, &cmd, sizeof(cmd));
	
	UInt8 rsv = 0;
	memcpy(byteBuffer+2, &rsv, sizeof(rsv));
	
	UInt8 atyp = 3;
	memcpy(byteBuffer+3, &atyp, sizeof(atyp));
	
	UInt8 hashLength = [hash length];
	memcpy(byteBuffer+4, &hashLength, sizeof(hashLength));
	
	memcpy(byteBuffer+5, [hash bytes], [hash length]);
	
	UInt16 port = 0;
	memcpy(byteBuffer+5+[hash length], &port, sizeof(port));
	
	NSData *data = [NSData dataWithBytesNoCopy:byteBuffer length:byteBufferLength freeWhenDone:YES];
	XMPPLogVerbose(@"TURNSocket: SOCKS_CONNECT: %@", data);
	
	[asyncSocket writeData:data withTimeout:-1 tag:SOCKS_CONNECT];
	
	//      +-----+-----+-----+------+------+------+
	// NAME | VER | REP | RSV | ATYP | ADDR | PORT |
	//      +-----+-----+-----+------+------+------+
	// SIZE |  1  |  1  |  1  |  1   | var  |  2   |
	//      +-----+-----+-----+------+------+------+
	//
	// Note: Size is in bytes
	// 
	// Version      = 5 (for SOCKS5)
	// Reply        = 0 (0=Succeeded, X=ErrorCode)
	// Reserved     = 0
	// Address Type = 3 (1=IPv4, 3=DomainName 4=IPv6)
	// Address      = P:D (P=LengthOfDomain D=DomainWithoutNullTermination)
	// Port         = 0
	// 
	// It is expected that the SOCKS server will return the same address given in the connect request.
	// But according to XEP-65 this is only marked as a SHOULD and not a MUST.
	// So just in case, we'll read up to the address length now, and then read in the address+port next.
	
	[asyncSocket readDataToLength:5 withTimeout:TIMEOUT_READ tag:SOCKS_CONNECT_REPLY_1];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark AsyncSocket Delegate Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
	XMPPLogTrace();
	
	// Start the SOCKS protocol stuff
	[self socksOpen];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
	XMPPLogTrace();
	
	if (tag == SOCKS_OPEN)
	{
		// See socksOpen method for socks reply format
		
		UInt8 ver = [NSNumber extractUInt8FromData:data atOffset:0];
		UInt8 mtd = [NSNumber extractUInt8FromData:data atOffset:1];
		
		XMPPLogVerbose(@"TURNSocket: SOCKS_OPEN: ver(%o) mtd(%o)", ver, mtd);
		
		if(ver == 5 && mtd == 0)
		{
			[self socksConnect];
		}
		else
		{
			// Some kind of error occurred.
			// The proxy probably requires some kind of authentication.
			[asyncSocket disconnect];
		}
	}
	else if (tag == SOCKS_CONNECT_REPLY_1)
	{
		// See socksConnect method for socks reply format
		
		XMPPLogVerbose(@"TURNSocket: SOCKS_CONNECT_REPLY_1: %@", data);
		
		UInt8 ver = [NSNumber extractUInt8FromData:data atOffset:0];
		UInt8 rep = [NSNumber extractUInt8FromData:data atOffset:1];
		
		XMPPLogVerbose(@"TURNSocket: SOCKS_CONNECT_REPLY_1: ver(%o) rep(%o)", ver, rep);
		
		if(ver == 5 && rep == 0)
		{
			// We read in 5 bytes which we expect to be:
			// 0: ver  = 5
			// 1: rep  = 0
			// 2: rsv  = 0
			// 3: atyp = 3
			// 4: size = size of addr field
			// 
			// However, some servers don't follow the protocol, and send a atyp value of 0.
			
			UInt8 atyp = [NSNumber extractUInt8FromData:data atOffset:3];
			
			if (atyp == 3)
			{
				UInt8 addrLength = [NSNumber extractUInt8FromData:data atOffset:4];
				UInt8 portLength = 2;
				
				XMPPLogVerbose(@"TURNSocket: addrLength: %o", addrLength);
				XMPPLogVerbose(@"TURNSocket: portLength: %o", portLength);
				
				[asyncSocket readDataToLength:(addrLength+portLength)
								  withTimeout:TIMEOUT_READ
										  tag:SOCKS_CONNECT_REPLY_2];
			}
			else if (atyp == 0)
			{
				// The size field was actually the first byte of the port field
				// We just have to read in that last byte
				[asyncSocket readDataToLength:1 withTimeout:TIMEOUT_READ tag:SOCKS_CONNECT_REPLY_2];
			}
			else
			{
				XMPPLogError(@"TURNSocket: Unknown atyp field in connect reply");
				[asyncSocket disconnect];
			}
		}
		else
		{
			// Some kind of error occurred.
			[asyncSocket disconnect];
		}
	}
	else if (tag == SOCKS_CONNECT_REPLY_2)
	{
		// See socksConnect method for socks reply format
		
		XMPPLogVerbose(@"TURNSocket: SOCKS_CONNECT_REPLY_2: %@", data);
		
		if (isClient)
		{
			[self sendActivate];
		}
		else
		{
			[self sendReply];
			[self succeed];
		}
	}
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
	XMPPLogTrace2(@"%@: %@ %@", THIS_FILE, THIS_METHOD, err);
	
	if (state == STATE_TARGET_CONNECT)
	{
		[self targetNextConnect];
	}
	else if (state == STATE_INITIATOR_CONNECT)
	{
		[self fail];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Timeouts
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setupDiscoTimer:(NSTimeInterval)timeout
{
	NSAssert(dispatch_get_current_queue() == turnQueue, @"Invoked on incorrect queue");
	
	if (discoTimer == NULL)
	{
		discoTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, turnQueue);
		
		dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (timeout * NSEC_PER_SEC));
		
		dispatch_source_set_timer(discoTimer, tt, DISPATCH_TIME_FOREVER, 0.1);
		dispatch_resume(discoTimer);
	}
	else
	{
		dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (timeout * NSEC_PER_SEC));
		
		dispatch_source_set_timer(discoTimer, tt, DISPATCH_TIME_FOREVER, 0.1);
	}
}

- (void)setupDiscoTimerForDiscoItems
{
	XMPPLogTrace();
	
	[self setupDiscoTimer:TIMEOUT_DISCO_ITEMS];
	
	NSString *theUUID = discoUUID;
	
	dispatch_source_set_event_handler(discoTimer, ^{ @autoreleasepool {
		
		[self doDiscoItemsTimeout:theUUID];
	}});
}

- (void)setupDiscoTimerForDiscoInfo
{
	XMPPLogTrace();
	
	[self setupDiscoTimer:TIMEOUT_DISCO_INFO];
	
	NSString *theUUID = discoUUID;
	
	dispatch_source_set_event_handler(discoTimer, ^{ @autoreleasepool {
		
		[self doDiscoInfoTimeout:theUUID];
	}});
}

- (void)setupDiscoTimerForDiscoAddress
{
	XMPPLogTrace();
	
	[self setupDiscoTimer:TIMEOUT_DISCO_ADDR];
	
	NSString *theUUID = discoUUID;
	
	dispatch_source_set_event_handler(discoTimer, ^{ @autoreleasepool {
		
		[self doDiscoAddressTimeout:theUUID];
	}});
}

- (void)doDiscoItemsTimeout:(NSString *)theUUID
{
	NSAssert(dispatch_get_current_queue() == turnQueue, @"Invoked on incorrect queue");
	
	if (state == STATE_PROXY_DISCO_ITEMS)
	{
		if ([theUUID isEqualToString:discoUUID])
		{
			XMPPLogTrace();
			
			// Server isn't responding - server may be offline
			[self queryNextProxyCandidate];
		}
	}
}

- (void)doDiscoInfoTimeout:(NSString *)theUUID
{
	NSAssert(dispatch_get_current_queue() == turnQueue, @"Invoked on incorrect queue");
	
	if (state == STATE_PROXY_DISCO_INFO)
	{
		if ([theUUID isEqualToString:discoUUID])
		{
			XMPPLogTrace();
			
			// Move on to the next proxy candidate
			[self queryNextProxyCandidate];
		}
	}
}

- (void)doDiscoAddressTimeout:(NSString *)theUUID
{
	NSAssert(dispatch_get_current_queue() == turnQueue, @"Invoked on incorrect queue");
	
	if (state == STATE_PROXY_DISCO_ADDR)
	{
		if ([theUUID isEqualToString:discoUUID])
		{
			XMPPLogTrace();
			
			// Server is taking a long time to respond to a simple query.
			// We could jump to the next candidate JID, but we'll take this as a sign of an overloaded server.
			[self queryNextProxyCandidate];
		}
	}
}

- (void)doTotalTimeout
{
	NSAssert(dispatch_get_current_queue() == turnQueue, @"Invoked on incorrect queue");
	
	if ((state != STATE_DONE) && (state != STATE_FAILURE))
	{
		XMPPLogTrace();
		
		// A timeout occured to cancel the entire TURN procedure.
		// This probably means the other endpoint crashed, or a network error occurred.
		// In either case, we can consider this a failure, and recycle the memory associated with this object.
		
		[self fail];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Finish and Cleanup
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)succeed
{
	NSAssert(dispatch_get_current_queue() == turnQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	// Record finish time
	finishTime = [[NSDate alloc] init];
	
	// Update state
	state = STATE_DONE;
	
	dispatch_async(delegateQueue, ^{ @autoreleasepool {
		
		if ([delegate respondsToSelector:@selector(turnSocket:didSucceed:)])
		{
			[delegate turnSocket:self didSucceed:asyncSocket];
		}
	}});
	
	[self cleanup];
}

- (void)fail
{
	NSAssert(dispatch_get_current_queue() == turnQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	// Record finish time
	finishTime = [[NSDate alloc] init];
	
	// Update state
	state = STATE_FAILURE;
	
	dispatch_async(delegateQueue, ^{ @autoreleasepool {
		
		if ([delegate respondsToSelector:@selector(turnSocketDidFail:)])
		{
			[delegate turnSocketDidFail:self];
		}
		
	}});
	
	[self cleanup];
}

- (void)cleanup
{
	// This method must be run on the turnQueue
	NSAssert(dispatch_get_current_queue() == turnQueue, @"Invoked on incorrect queue.");
	
	XMPPLogTrace();
	
	if (turnTimer)
	{
		dispatch_source_cancel(turnTimer);
		#if NEEDS_DISPATCH_RETAIN_RELEASE
		dispatch_release(turnTimer);
		#endif
		turnTimer = NULL;
	}
	
	if (discoTimer)
	{
		dispatch_source_cancel(discoTimer);
		#if NEEDS_DISPATCH_RETAIN_RELEASE
		dispatch_release(discoTimer);
		#endif
		discoTimer = NULL;
	}
	
	// Remove self as xmpp delegate
	[xmppStream removeDelegate:self delegateQueue:turnQueue];
	
	// Remove self from existingStuntSockets dictionary so we can be deallocated
	@synchronized(existingTurnSockets)
	{
		[existingTurnSockets removeObjectForKey:uuid];
	}
}

@end
