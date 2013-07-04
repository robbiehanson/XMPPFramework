#import "XMPPXFacebookPlatformAuthentication.h"
#import "XMPP.h"
#import "XMPPLogging.h"
#import "XMPPInternal.h"
#import "NSData+XMPP.h"

#import <objc/runtime.h>

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
#if DEBUG
    static const int xmppLogLevel = XMPP_LOG_LEVEL_INFO; // | XMPP_LOG_FLAG_TRACE;
#else
    static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

static NSString *const XMPPFacebookChatHostName = @"chat.facebook.com";

static char facebookAppIdKey;

@interface XMPPXFacebookPlatformAuthentication ()
{
  #if __has_feature(objc_arc_weak)
	__weak XMPPStream *xmppStream;
  #else
	__unsafe_unretained XMPPStream *xmppStream;
  #endif
	
	BOOL awaitingChallenge;
	
	NSString *appId;
	NSString *accessToken;
	NSString *nonce;
	NSString *method;
}

- (NSDictionary *)dictionaryFromChallenge:(NSXMLElement *)challenge;
- (NSString *)base64EncodedFullResponse;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPXFacebookPlatformAuthentication

+ (NSString *)mechanismName
{
	return @"X-FACEBOOK-PLATFORM";
}

- (id)initWithStream:(XMPPStream *)stream password:(NSString *)password
{
	if ((self = [super init]))
	{
		xmppStream = stream;
	}
	return self;
}

- (id)initWithStream:(XMPPStream *)stream appId:(NSString *)inAppId accessToken:(NSString *)inAccessToken
{
    if ((self = [super init]))
    {
		xmppStream = stream;
        appId = inAppId;
        accessToken = inAccessToken;
    }
    return self;
}

- (BOOL)start:(NSError **)errPtr
{
	if (!appId || !accessToken)
	{
		NSString *errMsg = @"Missing facebook appId and/or accessToken.";
		NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
		
		NSError *err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
		
		if (errPtr) *errPtr = err;
		return NO;
	}
	
	// <auth xmlns="urn:ietf:params:xml:ns:xmpp-sasl" mechanism="X-FACEBOOK-PLATFORM" />
	
	NSXMLElement *auth = [NSXMLElement elementWithName:@"auth" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
	[auth addAttributeWithName:@"mechanism" stringValue:@"X-FACEBOOK-PLATFORM"];
	
	[xmppStream sendAuthElement:auth];
	awaitingChallenge = YES;
	
	return YES;
}

- (XMPPHandleAuthResponse)handleAuth1:(NSXMLElement *)authResponse
{
	XMPPLogTrace();
	
	// We're expecting a challenge response.
	// If we get anything else we're going to assume it's some kind of failure response.
	
	if (![[authResponse name] isEqualToString:@"challenge"])
	{
		return XMPP_AUTH_FAIL;
	}
	
	// Extract components from incoming challenge
	
	NSDictionary *auth = [self dictionaryFromChallenge:authResponse];
	
	nonce  = [auth objectForKey:@"nonce"];
	method = [auth objectForKey:@"method"];
	
	// Create and send challenge response element
	
	NSXMLElement *response = [NSXMLElement elementWithName:@"response" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
	[response setStringValue:[self base64EncodedFullResponse]];
	
	[xmppStream sendAuthElement:response];
	awaitingChallenge = NO;
	
	return XMPP_AUTH_CONTINUE;
}

- (XMPPHandleAuthResponse)handleAuth2:(NSXMLElement *)authResponse
{
	XMPPLogTrace();
	
	// We're expecting a success response.
	// If we get anything else we can safely assume it's the equivalent of a failure response.
	
	if ([[authResponse name] isEqualToString:@"success"])
	{
		return XMPP_AUTH_SUCCESS;
	}
	else
	{
		return XMPP_AUTH_FAIL;
	}
}

- (XMPPHandleAuthResponse)handleAuth:(NSXMLElement *)authResponse
{
	if (awaitingChallenge)
	{
		return [self handleAuth1:authResponse];
	}
	else
	{
		return [self handleAuth2:authResponse];
	}
}

- (NSDictionary *)dictionaryFromChallenge:(NSXMLElement *)challenge
{
	// The value of the challenge stanza is base 64 encoded.
	// Once "decoded", it's just a string of key=value pairs separated by ampersands.
	
	NSData *base64Data = [[challenge stringValue] dataUsingEncoding:NSASCIIStringEncoding];
	NSData *decodedData = [base64Data xmpp_base64Decoded];
	
	NSString *authStr = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
	
	XMPPLogVerbose(@"%@: decoded challenge: %@", THIS_FILE, authStr);
	
	NSArray *components = [authStr componentsSeparatedByString:@"&"];
	NSMutableDictionary *auth = [NSMutableDictionary dictionaryWithCapacity:3];
	
	for (NSString *component in components)
	{
		NSRange separator = [component rangeOfString:@"="];
		if (separator.location != NSNotFound)
		{
			NSString *key = [[component substringToIndex:separator.location]
			                    stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			
			NSString *value = [[component substringFromIndex:separator.location+1]
			                      stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			
			if ([value hasPrefix:@"\""] && [value hasSuffix:@"\""] && [value length] > 2)
			{
				// Strip quotes from value
				value = [value substringWithRange:NSMakeRange(1,([value length]-2))];
			}
			
			[auth setObject:value forKey:key];
		}
	}
	
	return auth;
}

- (NSString *)base64EncodedFullResponse
{
    if (!appId || !accessToken || !method || !nonce)
    {
        return nil;
    }
	
	srand([[NSDate date] timeIntervalSince1970]);
	
	NSMutableString *buffer = [NSMutableString stringWithCapacity:250];
	[buffer appendFormat:@"method=%@&", method];
	[buffer appendFormat:@"nonce=%@&", nonce];
	[buffer appendFormat:@"access_token=%@&", accessToken];
	[buffer appendFormat:@"api_key=%@&", appId];
	[buffer appendFormat:@"call_id=%d&", rand()];
	[buffer appendFormat:@"v=%@",@"1.0"];
	
	XMPPLogVerbose(@"XMPPXFacebookPlatformAuthentication: response for facebook: %@", buffer);
	
	NSData *utf8data = [buffer dataUsingEncoding:NSUTF8StringEncoding];
	
	return [utf8data xmpp_base64Encoded];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPStream (XMPPXFacebookPlatformAuthentication)

- (id)initWithFacebookAppId:(NSString *)fbAppId
{
	if ((self = [self init])) // Note: Using [self init], NOT [super init]
	{
		self.facebookAppId = fbAppId;
		self.myJID = [XMPPJID jidWithString:XMPPFacebookChatHostName];
		
		// As of October 8, 2011, Facebook doesn't have their XMPP SRV records set.
		// And, as per the XMPP specification, we MUST check the XMPP SRV records for an IP address,
		// before falling back to a traditional A record lookup.
		// 
		// So we're setting the hostname as a minor optimization to avoid the SRV timeout delay.
		
		self.hostName = XMPPFacebookChatHostName;
	}
	return self;
}

- (NSString *)facebookAppId
{
	__block NSString *result = nil;
	
	dispatch_block_t block = ^{
		result = objc_getAssociatedObject(self, &facebookAppIdKey);
	};

	if (dispatch_get_specific(self.xmppQueueTag))
		block();
	else
		dispatch_sync(self.xmppQueue, block);
	
	return result;
}

- (void)setFacebookAppId:(NSString *)inFacebookAppId
{
	NSString *newFacebookAppId = [inFacebookAppId copy];
	
	dispatch_block_t block = ^{
		objc_setAssociatedObject(self, &facebookAppIdKey, newFacebookAppId, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	};
	
	if (dispatch_get_specific(self.xmppQueueTag))
		block();
	else
		dispatch_async(self.xmppQueue, block);
}

- (BOOL)supportsXFacebookPlatformAuthentication
{
	return [self supportsAuthenticationMechanism:[XMPPXFacebookPlatformAuthentication mechanismName]];
}

/**
 * This method attempts to connect to the Facebook Chat servers 
 * using the Facebook OAuth token returned by the Facebook OAuth 2.0 authentication process.
**/
- (BOOL)authenticateWithFacebookAccessToken:(NSString *)accessToken error:(NSError **)errPtr
{
	XMPPLogTrace();
	
	__block BOOL result = YES;
	__block NSError *err = nil;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if ([self supportsXFacebookPlatformAuthentication])
		{
			XMPPXFacebookPlatformAuthentication *facebookAuth =
			    [[XMPPXFacebookPlatformAuthentication alloc] initWithStream:self
			                                                          appId:self.facebookAppId
			                                                    accessToken:accessToken];
			
			result = [self authenticate:facebookAuth error:&err];
		}
		else
		{
			NSString *errMsg = @"The server does not support X-FACEBOOK-PLATFORM authentication.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamUnsupportedAction userInfo:info];
			
			result = NO;
		}
	}};
	
	if (dispatch_get_specific(self.xmppQueueTag))
		block();
	else
		dispatch_sync(self.xmppQueue, block);
	
	if (errPtr)
		*errPtr = err;
	
	return result;
}

@end
