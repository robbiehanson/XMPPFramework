#import "XMPPExternalAuthentication.h"
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


@implementation XMPPExternalAuthentication
{
#if __has_feature(objc_arc_weak)
	__weak XMPPStream *xmppStream;
#else
	__unsafe_unretained XMPPStream *xmppStream;
#endif
	
	NSString *password;
}

+ (NSString *)mechanismName
{
	return @"EXTERNAL";
}

- (id)initWithStream:(XMPPStream *)stream password:(NSString *)password;
{
	if ((self = [super init]))
	{
		xmppStream = stream;
	}
	return self;
}

- (BOOL)start:(NSError **)errPtr
{
	XMPPLogTrace();
	
	// <auth xmlns="urn:ietf:params:xml:ns:xmpp-sasl" mechanism="EXTENAL">=</auth>
	
    NSXMLElement *auth = [NSXMLElement elementWithName:@"auth" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
    [auth addAttributeWithName:@"mechanism" stringValue:@"EXTERNAL"];
    [auth setStringValue:@"="];
    
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

@implementation XMPPStream (XMPPExternalAuthentication)

- (BOOL)supportsExternalAuthentication
{
	return [self supportsAuthenticationMechanism:[XMPPExternalAuthentication mechanismName]];
}

@end
