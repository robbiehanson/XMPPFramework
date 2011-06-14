//
//  XMPPJabberRPCModule.m
//  XEP-0009
//
//  Originally created by Eric Chamberlain on 5/16/10.
//

#import "XMPPJabberRPCModule.h"
#import "XMPP.h"
#import "XMPPIQ+JabberRPC.h"
#import "XMPPIQ+JabberRPCResonse.h"
#import "XMPPLogging.h"

// Log levels: off, error, warn, info, verbose
// Log flags: trace
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

// can turn off if not acting as a Jabber-RPC server 
#define INTEGRATE_WITH_CAPABILITIES 1

#if INTEGRATE_WITH_CAPABILITIES
#import "XMPPCapabilities.h"
#endif

NSString *const XMPPJabberRPCErrorDomain = @"XMPPJabberRPCErrorDomain";

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RPCID : NSObject
{
	NSString *rpcID;
	dispatch_source_t timer;
}

@property (nonatomic, readonly) NSString *rpcID;
@property (nonatomic, readonly) dispatch_source_t timer;

- (id)initWithRpcID:(NSString *)rpcID timer:(dispatch_source_t)timer;

- (void)cancelTimer;

@end

@implementation RPCID

@synthesize rpcID;
@synthesize timer;

- (id)initWithRpcID:(NSString *)aRpcID timer:(dispatch_source_t)aTimer
{
	if ((self = [super init]))
	{
		rpcID = [aRpcID copy];
		
		timer = aTimer;
		dispatch_retain(timer);
	}
	return self;
}

- (BOOL)isEqual:(id)anObject
{
	return [rpcID isEqual:anObject];
}

- (NSUInteger)hash
{
	return [rpcID hash];
}

- (void)cancelTimer
{
	if (timer)
	{
		dispatch_source_cancel(timer);
		dispatch_release(timer);
		timer = NULL;
	}
}

- (void)dealloc
{
	[self cancelTimer];
	[rpcID release];
	
	[super dealloc];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPJabberRPCModule

@dynamic defaultTimeout;

- (NSTimeInterval)defaultTimeout
{
	__block NSTimeInterval result;
	
	dispatch_block_t block = ^{
		result = defaultTimeout;
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

- (void)setDefaultTimeout:(NSTimeInterval)newDefaultTimeout
{
	dispatch_block_t block = ^{
		XMPPLogTrace();
		defaultTimeout = newDefaultTimeout;
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Module Management
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)init
{
	return [self initWithDispatchQueue:NULL];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	if ((self = [super initWithDispatchQueue:queue]))
	{
		XMPPLogTrace();
		
		rpcIDs = [[NSMutableDictionary alloc] initWithCapacity:5];
		defaultTimeout = 5.0;
	}
	return self;
}

- (BOOL)activate:(XMPPStream *)aXmppStream
{
	XMPPLogTrace();
	
	if ([super activate:aXmppStream])
	{
	#if INTEGRATE_WITH_CAPABILITIES
		[xmppStream autoAddDelegate:self delegateQueue:moduleQueue toModulesOfClass:[XMPPCapabilities class]];
	#endif
		
		return YES;
	}
	
	return NO;
}

- (void)deactivate
{
	XMPPLogTrace();
	
#if INTEGRATE_WITH_CAPABILITIES
	[xmppStream removeAutoDelegate:self delegateQueue:moduleQueue fromModulesOfClass:[XMPPCapabilities class]];
#endif
	
	[super deactivate];
}

- (void)dealloc
{
	XMPPLogTrace();
	
	[rpcIDs release];
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Send RPC
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)sendRpcIQ:(XMPPIQ *)iq
{
	return [self sendRpcIQ:iq withTimeout:[self defaultTimeout]];
}

- (NSString *)sendRpcIQ:(XMPPIQ *)iq withTimeout:(NSTimeInterval)timeout
{
	XMPPLogTrace();
	
	NSString *elementID = [iq elementID];
	
	dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, moduleQueue);
	
	dispatch_source_set_event_handler(timer, ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		[self timeoutRemoveRpcID:elementID];
		
		[pool drain];
	});
	
	dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (timeout * NSEC_PER_SEC));
	
	dispatch_source_set_timer(timer, tt, DISPATCH_TIME_FOREVER, 0);
	dispatch_resume(timer);
	
	RPCID *rpcID = [[RPCID alloc] initWithRpcID:elementID timer:timer];
	
	[rpcIDs setObject:rpcID forKey:elementID];
	[rpcID release];
	
	[xmppStream sendElement:iq];
	
	return elementID;
}

- (void)timeoutRemoveRpcID:(NSString *)elementID
{
	XMPPLogTrace();
	
	RPCID *rpcID = [rpcIDs objectForKey:elementID];
	if (rpcID)
	{
		[rpcID cancelTimer];
		[rpcIDs removeObjectForKey:elementID];
		
		NSError *error = [NSError errorWithDomain:XMPPJabberRPCErrorDomain
		                                     code:1400
		                                 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
		                                          @"Request timed out", @"error",nil]];
		
		[multicastDelegate jabberRPC:self elementID:elementID didReceiveError:error];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	XMPPLogTrace();
	
	if ([iq isJabberRPC])
	{
		if ([iq isResultIQ] || [iq isErrorIQ])
		{
			// Example:
			// 
			// <iq from="deusty.com" to="robbiehanson@deusty.com/work" id="abc123" type="result"/>
			
			NSString *elementID = [iq elementID];
			
			// check if this is a JabberRPC query
			// we could check the query element, but we should be able to do a lookup based on the unique elementID
			// because we send an ID, we should get one back
			
			RPCID *rpcID =  [rpcIDs objectForKey:elementID];
			if (rpcID == nil)
			{
				return NO;
			}
			
			XMPPLogVerbose(@"%@: Received RPC response!", THIS_FILE);
			
			if ([iq isResultIQ])
			{
				id response;
				NSError *error = nil;
				
				//TODO: parse iq and generate response.
				response = [iq methodResponse:&error];
				
				if (error == nil) {
					[multicastDelegate jabberRPC:self elementID:elementID didReceiveMethodResponse:response];
				} else {
					[multicastDelegate jabberRPC:self elementID:elementID didReceiveError:error];
				}
				
			}
			else
			{
				// TODO: implement error parsing
				// not much specified in XEP, only 403 forbidden error
				NSXMLElement *errorElement = [iq childErrorElement];
				NSError *error = [NSError errorWithDomain:XMPPJabberRPCErrorDomain 
													 code:[errorElement attributeIntValueForName:@"code"] 
												 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:	
														   [errorElement attributesAsDictionary],@"error",
														   [[errorElement childAtIndex:0] name], @"condition",
														   iq,@"iq",
														   nil]];
				
				[multicastDelegate jabberRPC:self elementID:elementID didReceiveError:error];
			}
			
			[rpcID cancelTimer];
			[rpcIDs removeObjectForKey:elementID];
			
#if INTEGRATE_WITH_CAPABILITIES
		} else if ([iq isSetIQ]) {
			// we would receive set when implementing Jabber-RPC server
			
			[multicastDelegate jabberRPC:self didReceiveSetIQ:iq];
#endif		
		}
		
		// Jabber-RPC doesn't use get iq type
	}
	return NO;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPCapabilities delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#if INTEGRATE_WITH_CAPABILITIES
/**
 * If an XMPPCapabilites instance is used we want to advertise our support for JabberRPC.
**/
- (void)xmppCapabilities:(XMPPCapabilities *)sender collectingMyCapabilities:(NSXMLElement *)query
{
	XMPPLogTrace();
	
	// <query xmlns="http://jabber.org/protocol/disco#info">
	//   ...
	//   <identity category='automation' type='rpc'/>
    //	 <feature var='jabber:iq:rpc'/>
	//   ...
	// </query>
	[query addChild:[XMPPIQ elementRpcIdentity]];
	[query addChild:[XMPPIQ elementRpcFeature]];
}
#endif

@end
