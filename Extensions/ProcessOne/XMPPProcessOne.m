#import "XMPPProcessOne.h"
#import "XMPP.h"
#import "XMPPInternal.h"
#import "XMPPLogging.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
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

- (NSDate *)savedSessionDate
{
	return [[NSUserDefaults standardUserDefaults] objectForKey:XMPPProcessOneSessionDate];
}

- (void)setSavedSessionDate:(NSDate *)savedSessionDate
{
	if (savedSessionDate)
		[[NSUserDefaults standardUserDefaults] setObject:savedSessionDate forKey:XMPPProcessOneSessionDate];
	else
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:XMPPProcessOneSessionDate];
}

- (NSXMLElement *)pushConfiguration
{
	if (dispatch_get_specific(moduleQueueTag))
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
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)sendPushConfiguration
{
	if (pushConfiguration)
	{
		pushIQID = [XMPPStream generateUUID];
		NSXMLElement *push = [pushConfiguration copy];
		
		XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:nil elementID:pushIQID child:push];
		
		[xmppStream sendElement:iq];
		pushConfigurationSent = YES;
	}
	else
	{
		// <iq type='set'>
		//   <disable xmlns='p1:push'>
		// </iq>
		
		NSXMLElement *disable = [NSXMLElement elementWithName:@"disable" xmlns:@"p1:push"];
		
		XMPPIQ *iq = [XMPPIQ iqWithType:@"set" elementID:[XMPPStream generateUUID] child:disable];
		
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
	if (!pushConfigurationSent)
	{
		[self sendPushConfiguration];
	}
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
	if (pushConfigurationConfirmed)
	{
		self.savedSessionDate = [[NSDate alloc] init];
	}
	else
	{
		// The pushConfiguration was sent to the server, but we never received a confirmation.
		// So either the pushConfiguration never made it to the server,
		// or we got disconnected before we received the confirmation from the server.
		// 
		// To be sure, we need to resent the pushConfiguration next time we authenticate.
		
		pushConfigurationSent = NO;
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Configuration Elements
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSXMLElement *)pushConfigurationContainer
{
	return [NSXMLElement elementWithName:@"push" xmlns:@"p1:push"];
}

+ (NSXMLElement *)keepaliveWithMax:(NSTimeInterval)max
{
	// keepalive is the max interval between keepalive events received by server
	// before going out of reception (in seconds)
	
	NSString *maxStr = [NSString stringWithFormat:@"%.0f", max];
	
	NSXMLElement *keepalive = [NSXMLElement elementWithName:@"keepalive"];
	[keepalive addAttributeWithName:@"max" stringValue:maxStr];
	
	return keepalive;
}

+ (NSXMLElement *)sessionWithDuration:(NSTimeInterval)durationInSeconds
{
	// session is the max time the session is kept before automatically
	// closing the session while in push mode (in minutes).
	// 
	// Max session is 24 hours.
	// Server can decide to force the session close anyway, if the message queue is getting large.
	
	double durationInMinutes = durationInSeconds / 60.0;
	
	NSString *durationStr = [NSString stringWithFormat:@"%.0f", durationInMinutes];
	
	NSXMLElement *session = [NSXMLElement elementWithName:@"session"];
	[session addAttributeWithName:@"duration" stringValue:durationStr];
	
	return session;
}

+ (NSXMLElement *)statusWithType:(NSString *)type message:(NSString *)message
{
	// status (optional) is the XMPP status the user should appear in,
	// and the message when the XMPP session is not linked to a TCP connection.
	// 
	// If omittted, the presence and status is not change when going into disconnected opened session.
	
	NSXMLElement *status = [NSXMLElement elementWithName:@"status"];
	
	if (type)
		[status addAttributeWithName:@"type" stringValue:type];
	
	if (message)
		[status setStringValue:message];
	
	return status;
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
		NSDictionary *info = @{NSLocalizedDescriptionKey : errMsg};
		
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
		return XMPPHandleAuthResponseSuccess;
	}
	else
	{
		return XMPPHandleAuthResponseFailed;
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
		if (self.state >= STATE_XMPP_POST_NEGOTIATION)
		{
			NSXMLElement *features = [self.rootElement elementForName:@"stream:features"];
			NSXMLElement *push = [features elementForName:@"push" xmlns:@"p1:push"];
			
			result = (push != nil);
		}
	}};

	if (dispatch_get_specific(self.xmppQueueTag))
		block();
	else
		dispatch_sync(self.xmppQueue, block);
	
	return result;
}

- (BOOL)supportsRebind
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		// The root element can be properly queried anytime after the
		// stream:features are received, and TLS has been setup (if required)
		if (self.state >= STATE_XMPP_POST_NEGOTIATION)
		{
			NSXMLElement *features = [self.rootElement elementForName:@"stream:features"];
			NSXMLElement *rebind = [features elementForName:@"rebind" xmlns:@"p1:rebind"];
			
			result = (rebind != nil);
		}
	}};
	
	if (dispatch_get_specific(self.xmppQueueTag))
		block();
	else
		dispatch_sync(self.xmppQueue, block);
	
	return result;
}

- (NSString *)rebindSessionID
{
	return [[self rootElement] attributeStringValueForName:@"id"];
}

@end
