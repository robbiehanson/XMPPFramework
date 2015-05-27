#import "XMPPPlainAuthentication.h"
#import "XMPP.h"
#import "XMPPLogging.h"
#import "XMPPInternal.h"
#import "NSData+XMPP.h"
#import "NSXMLElement+XMPP.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_INFO; // | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif


@implementation XMPPPlainAuthentication
{
  #if __has_feature(objc_arc_weak)
	__weak XMPPStream *xmppStream;
  #else
	__unsafe_unretained XMPPStream *xmppStream;
  #endif
	
	NSString *username;
	NSString *password;
}

+ (NSString *)mechanismName
{
	return @"PLAIN";
}

- (id)initWithStream:(XMPPStream *)stream password:(NSString *)inPassword
{
	return [self initWithStream:stream username:nil password:inPassword];
}

- (id)initWithStream:(XMPPStream *)stream username:(NSString *)inUsername password:(NSString *)inPassword
{
	if ((self = [super init]))
	{
		xmppStream = stream;
		username = inUsername;
		password = inPassword;
	}
	return self;
}

- (BOOL)start:(NSError **)errPtr
{
	XMPPLogTrace();
	
	// From RFC 4616 - PLAIN SASL Mechanism:
	// [authzid] UTF8NUL authcid UTF8NUL passwd
	// 
	// authzid: authorization identity
	// authcid: authentication identity (username)
	// passwd : password for authcid
	
	NSString *authUsername = username;
	if (!authUsername)
	{
		authUsername = [xmppStream.myJID user];
	}
	
	NSString *payload = [NSString stringWithFormat:@"\0%@\0%@", authUsername, password];
	NSString *base64 = [[payload dataUsingEncoding:NSUTF8StringEncoding] xmpp_base64Encoded];
	
	// <auth xmlns="urn:ietf:params:xml:ns:xmpp-sasl" mechanism="PLAIN">Base-64-Info</auth>
	
	NSXMLElement *auth = [NSXMLElement elementWithName:@"auth" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
	[auth addAttributeWithName:@"mechanism" stringValue:@"PLAIN"];
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
		return XMPP_AUTH_SUCCESS;
	}
	else
	{
		return XMPP_AUTH_FAIL;
	}
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPStream (XMPPPlainAuthentication)

- (BOOL)supportsPlainAuthentication
{
	return [self supportsAuthenticationMechanism:[XMPPPlainAuthentication mechanismName]];
}

@end
