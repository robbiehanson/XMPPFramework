//
//  XMPPTBRAuthentication.m
//  XMPPFramework
//
//  Created by Andres Canal on 7/6/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

#import "XMPPTBRAuthentication.h"
#import "XMPPInternal.h"
#import "NSXMLElement+XMPP.h"

@implementation XMPPTBRAuthentication {
	#if __has_feature(objc_arc_weak)
		__weak XMPPStream *xmppStream;
	#else
		__unsafe_unretained XMPPStream *xmppStream;
	#endif
	NSString *authToken;
}

+ (NSString *)mechanismName {
	return @"X-OAUTH";
}

- (id)initWithStream:(nonnull XMPPStream *)stream password:(nonnull NSString *)password {
	return [super init];
}

- (id)initWithStream:(nonnull XMPPStream *)stream token:(nonnull NSString *)aToken {
	if( self = [super init]) {
		xmppStream = stream;
		authToken = aToken;
	}

	return self;
}

- (BOOL)start:(NSError **)errPtr {

	if(!authToken) {
		NSString *errMsg = @"Missing auth token.";
		NSDictionary *info = @{NSLocalizedDescriptionKey : errMsg};

		NSError *err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidParameter userInfo:info];

		if (errPtr) *errPtr = err;
		return NO;
	}

	// <auth xmlns="urn:ietf:params:xml:ns:xmpp-sasl" mechanism="X-OAUTH">auth_token</auth>

	NSXMLElement *auth = [NSXMLElement elementWithName:@"auth" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
	[auth addAttributeWithName:@"mechanism" stringValue:@"X-OAUTH"];
	auth.stringValue = authToken;

	[xmppStream sendAuthElement:auth];

	return true;
}

- (XMPPHandleAuthResponse)handleAuth:(NSXMLElement *)auth {

	if ([[auth name] isEqualToString:@"success"]) {
		return XMPP_AUTH_SUCCESS;
	}
	
	return XMPP_AUTH_FAIL;
}

@end
