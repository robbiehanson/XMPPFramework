//
//  XMPPXOAuth2Google.m
//  Off the Record
//
//  Created by David Chiles on 9/13/13.
//  Copyright (c) 2013 Chris Ballinger. All rights reserved.
//

#import "XMPPXOAuth2Google.h"
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

static NSString *const XMPPGoogleTalkHostName = @"talk.google.com";

@interface XMPPXOAuth2Google ()
{
#if __has_feature(objc_arc_weak)
	__weak XMPPStream *xmppStream;
#else
	__unsafe_unretained XMPPStream *xmppStream;
#endif
	
	//BOOL awaitingChallenge;
	
	//NSString *appId;
	NSString *accessToken;
	//NSString *nonce;
	//NSString *method;
}



@end

@implementation XMPPXOAuth2Google

+ (NSString *)mechanismName
{
	return @"X-OAUTH2";
}

- (id)initWithStream:(XMPPStream *)stream password:(NSString *)password
{
	if ((self = [super init]))
	{
		xmppStream = stream;
        xmppStream.hostName = XMPPGoogleTalkHostName;
	}
	return self;
}

-(id)initWithStream:(XMPPStream *)stream accessToken:(NSString *)inAccessToken
{
    if (self = [super init]) {
        xmppStream = stream;
        accessToken = inAccessToken;
    }
    return self;
}

- (BOOL)start:(NSError **)errPtr
{
    if (!accessToken)
	{
		NSString *errMsg = @"Missing facebook accessToken.";
		NSDictionary *info = @{NSLocalizedDescriptionKey : errMsg};
		
		NSError *err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
		
		if (errPtr) *errPtr = err;
		return NO;
	}
	XMPPLogTrace();
	
	// From RFC 4616 - PLAIN SASL Mechanism:
	// [authzid] UTF8NUL authcid UTF8NUL passwd
	//
	// authzid: authorization identity
	// authcid: authentication identity (username)
	// passwd : password for authcid
	
	NSString *username = [xmppStream.myJID user];
	
	NSString *payload = [NSString stringWithFormat:@"\0%@\0%@", username, accessToken];
	NSString *base64 = [[payload dataUsingEncoding:NSUTF8StringEncoding] xmpp_base64Encoded];
	
	// <auth xmlns="urn:ietf:params:xml:ns:xmpp-sasl" mechanism="PLAIN">Base-64-Info</auth>
	
	NSXMLElement *auth = [NSXMLElement elementWithName:@"auth" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
	[auth addAttributeWithName:@"mechanism" stringValue:@"X-OAUTH2"];
    [auth addAttributeWithName:@"auth:service" stringValue:@"oauth2"];
    [auth addAttributeWithName:@"xmlns:auth" stringValue:@"http://www.google.com/talk/protocol/auth"];
	[auth setStringValue:base64];
	
	[xmppStream sendAuthElement:auth];
	
	return YES;
}

- (XMPPHandleAuthResponse)handleAuth:(NSXMLElement *)authResponse
{
	XMPPLogTrace();
	
	// We're expecting a success response.
	// If we get anything else we can safely assume it's the equivalent of a failure response.
	
	if ([[authResponse name] isEqualToString:@"success"])
	{
		return XMPPHandleAuthResponseSuccess;
	}
	else
	{
		return XMPPHandleAuthResponseFailed;
	}
}
@end

@implementation XMPPStream (XMPPXOAuth2Google)



- (BOOL)supportsXOAuth2GoogleAuthentication
{
	return [self supportsAuthenticationMechanism:[XMPPXOAuth2Google mechanismName]];
}

- (BOOL)authenticateWithGoogleAccessToken:(NSString *)accessToken error:(NSError **)errPtr
{
    XMPPLogTrace();
	
	__block BOOL result = YES;
	__block NSError *err = nil;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if ([self supportsXOAuth2GoogleAuthentication])
		{
            XMPPXOAuth2Google * googleAuth = [[XMPPXOAuth2Google alloc] initWithStream:self
                                                                         accessToken:accessToken];
			
			result = [self authenticate:googleAuth error:&err];
		}
		else
		{
			NSString *errMsg = @"The server does not support X-OATH2-GOOGLE authentication.";
			NSDictionary *info = @{NSLocalizedDescriptionKey : errMsg};
			
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
