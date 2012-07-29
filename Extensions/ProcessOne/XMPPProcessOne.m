#import "XMPPProcessOne.h"
#import "XMPP.h"
#import "XMPPInternal.h"
#import "XMPPLogging.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
// Log flags: trace
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

NSString *const XMPPProcessOneSessionID = @"XMPPProcessOneSessionID";
NSString *const XMPPProcessOneSessionJID = @"XMPPProcessOneSessionJID";
NSString *const XMPPProcessOneSessionDate = @"XMPPProcessOneSessionDate";

@interface XMPPProcessOne ()
{
	NSXMLElement *pushConfiguration;
	BOOL pushConfigurationSent;
	BOOL pushConfigurationConfirmed;
	NSString *pushIQID;
}

@property (readwrite) NSString *savedSessionID;
@property (readwrite) XMPPJID *savedSessionJID;

- (void)sendPushConfiguration;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPProcessOne

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	if ((self = [super initWithDispatchQueue:NULL]))
	{
		pushConfiguration = nil;
		pushConfigurationSent = YES;
		pushConfigurationConfirmed = YES;
	}
	return self;
}

- (NSString *)savedSessionID
{
	return [[NSUserDefaults standardUserDefaults] stringForKey:XMPPProcessOneSessionID];
}

- (void)setSavedSessionID:(NSString *)savedSessionID
{
	if (savedSessionID)
		[[NSUserDefaults standardUserDefaults] setObject:savedSessionID forKey:XMPPProcessOneSessionID];
	else
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:XMPPProcessOneSessionID];
}

- (XMPPJID *)savedSessionJID
{
	NSString *sessionJidStr = [[NSUserDefaults standardUserDefaults] stringForKey:XMPPProcessOneSessionJID];
	
	return [XMPPJID jidWithString:sessionJidStr];
}

- (void)setSavedSessionJID:(XMPPJID *)savedSessionJID
{
	NSString *sessionJidStr = [savedSessionJID full];
	
	if (sessionJidStr)
		[[NSUserDefaults standardUserDefaults] setObject:sessionJidStr forKey:XMPPProcessOneSessionJID];
	else
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:XMPPProcessOneSessionJID];
}

- (NSXMLElement *)pushConfiguration
{
	if (dispatch_get_current_queue() == moduleQueue)
	{
		return pushConfiguration;
	}
	else
	{
		__block NSXMLElement *result = nil;
		
		dispatch_sync(moduleQueue, ^{
			result = [pushConfiguration copy];
		});
		
		return result;
	}
}

- (void)setPushConfiguration:(NSXMLElement *)pushConfig
{
	NSXMLElement *newPushConfiguration = [pushConfig copy];
	
	dispatch_block_t block = ^{
		
		if (pushConfiguration == nil && newPushConfiguration == nil)
		{
			return;
		}
		
		pushConfiguration = newPushConfiguration;
		pushConfigurationSent = NO;
		pushConfigurationConfirmed = NO;
		
		if ([xmppStream isAuthenticated])
		{
			[self sendPushConfiguration];
		}
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)sendPushConfiguration
{
	if (pushConfiguration)
	{
		pushIQID = [XMPPStream generateUUID];
		
		XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:nil elementID:pushIQID child:pushConfiguration];
		
		[xmppStream sendElement:iq];
		pushConfigurationSent = YES;
	}
	else
	{
		// <iq type='set'>
		//   <disable xmlns='p1:push'>
		// </iq>
		
		NSXMLElement *disable = [NSXMLElement elementWithName:@"disable" xmlns:@"p1:push"];
		
		XMPPIQ *iq = [XMPPIQ iqWithType:@"set" child:disable];
		
		[xmppStream sendElement:iq];
		pushConfigurationSent = YES;
	}
}

- (XMPPElementReceipt *)goOnStandby
{
	// <standby>true</standby>
	
	NSXMLElement *standby = [NSXMLElement elementWithName:@"standby" stringValue:@"true"];
	
	XMPPElementReceipt *receipt = nil;
	[xmppStream sendElement:standby andGetReceipt:&receipt];
		
	return receipt;
}

- (XMPPElementReceipt *)goOffStandby
{
	// <standby>false</standby>
	
	NSXMLElement *standby = [NSXMLElement elementWithName:@"standby" stringValue:@"false"];
	
	XMPPElementReceipt *receipt = nil;
	[xmppStream sendElement:standby andGetReceipt:&receipt];
	
	return receipt;
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	// Successful authentication via non-rebind.
	// Save session information.
	
	self.savedSessionID = [xmppStream rebindSessionID];
	self.savedSessionJID = [xmppStream myJID];
	
	if (!pushConfigurationSent)
	{
		[self sendPushConfiguration];
	}
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
	if (!pushConfigurationConfirmed)
	{
		// The pushConfiguration was sent to the server, but we never received a confirmation.
		// So either the pushConfiguration never made it to the server,
		// or we got disconnected before we received the confirmation from the server.
		// 
		// To be sure, we need to resent the pushConfiguration next time we authenticate.
		
		pushConfigurationSent = NO;
	}
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPRebindAuthentication
{
  #if __has_feature(objc_arc_weak)
	__weak XMPPStream *xmppStream;
  #else
	__unsafe_unretained XMPPStream *xmppStream;
  #endif
	
	NSString *sessionID;
	XMPPJID *sessionJID;
}

+ (NSString *)mechanismName
{
	return nil;
}

- (id)initWithStream:(XMPPStream *)stream password:(NSString *)password
{
	if ((self = [super init]))
	{
		xmppStream = stream;
	}
	return self;
}

- (id)initWithStream:(XMPPStream *)stream sessionID:(NSString *)aSessionID sessionJID:(XMPPJID *)aSessionJID
{
	if ((self = [super init]))
	{
		xmppStream = stream;
		sessionID = aSessionID;
		sessionJID = aSessionJID;
	}
	return self;
}

- (BOOL)start:(NSError **)errPtr
{
	if (!sessionID || !sessionJID)
	{
		NSString *errMsg = @"Missing sessionID and/or sessionJID.";
		NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
		
		NSError *err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
		
		if (errPtr) *errPtr = err;
		return NO;
	}
	
	// <rebind xmlns="p1:rebind">
	//   <jid>user@domain/resource</jid>
	//   <sid>123456789</sid>
	// </rebind>
	
	NSXMLElement *jid = [NSXMLElement elementWithName:@"jid" stringValue:[sessionJID full]];
	NSXMLElement *sid = [NSXMLElement elementWithName:@"sid" stringValue:sessionID];
	
	NSXMLElement *rebind = [NSXMLElement elementWithName:@"rebind" xmlns:@"p1:rebind"];
	[rebind addChild:jid];
	[rebind addChild:sid];
	
	[xmppStream sendAuthElement:rebind];
	return YES;
}

- (XMPPHandleAuthResponse)handleAuth:(NSXMLElement *)response
{
	if ([[response name] isEqualToString:@"rebind"])
	{
		return XMPP_AUTH_SUCCESS;
	}
	else
	{
		return XMPP_AUTH_FAIL;
	}
}

- (BOOL)shouldResendOpeningNegotiationAfterSuccessfulAuthentication
{
	return NO;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPStream (XMPPProcessOne)

- (BOOL)supportsPush
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		// The root element can be properly queried anytime after the
		// stream:features are received, and TLS has been setup (if required)
		if (state >= STATE_XMPP_POST_NEGOTIATION)
		{
			NSXMLElement *features = [rootElement elementForName:@"stream:features"];
			NSXMLElement *push = [features elementForName:@"push" xmlns:@"p1:push"];
			
			result = (push != nil);
		}
	}};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
}

- (BOOL)supportsRebind
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		// The root element can be properly queried anytime after the
		// stream:features are received, and TLS has been setup (if required)
		if (state >= STATE_XMPP_POST_NEGOTIATION)
		{
			NSXMLElement *features = [rootElement elementForName:@"stream:features"];
			NSXMLElement *rebind = [features elementForName:@"rebind" xmlns:@"p1:rebind"];
			
			result = (rebind != nil);
		}
	}};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
}

- (NSString *)rebindSessionID
{
	return [[self rootElement] attributeStringValueForName:@"id"];
}

@end
