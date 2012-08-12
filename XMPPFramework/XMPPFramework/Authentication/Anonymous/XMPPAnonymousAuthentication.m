#import "XMPPAnonymousAuthentication.h"
#import "XMPP.h"
#import "XMPPLogging.h"
#import "XMPPInternal.h"
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

/**
 * Seeing a return statements within an inner block
 * can sometimes be mistaken for a return point of the enclosing method.
 * This makes inline blocks a bit easier to read.
**/
#define return_from_block  return


@implementation XMPPAnonymousAuthentication
{
  #if __has_feature(objc_arc_weak)
	__weak XMPPStream *xmppStream;
  #else
	__unsafe_unretained XMPPStream *xmppStream;
  #endif
}

+ (NSString *)mechanismName
{
	return @"ANONYMOUS";
}

- (id)initWithStream:(XMPPStream *)stream
{
	if ((self = [super init]))
	{
		xmppStream = stream;
	}
	return self;
}

- (id)initWithStream:(XMPPStream *)stream password:(NSString *)password
{
	return [self initWithStream:stream];
}

- (BOOL)start:(NSError **)errPtr
{
	// <auth xmlns="urn:ietf:params:xml:ns:xmpp-sasl" mechanism="ANONYMOUS" />
	
	NSXMLElement *auth = [NSXMLElement elementWithName:@"auth" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
	[auth addAttributeWithName:@"mechanism" stringValue:@"ANONYMOUS"];
	
	[xmppStream sendAuthElement:auth];
	
	return YES;
}

- (XMPPHandleAuthResponse)handleAuth:(NSXMLElement *)authResponse
{
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

@implementation XMPPStream (XMPPAnonymousAuthentication)

- (BOOL)supportsAnonymousAuthentication
{
	return [self supportsAuthenticationMechanism:[XMPPAnonymousAuthentication mechanismName]];
}

- (BOOL)authenticateAnonymously:(NSError **)errPtr
{
	XMPPLogTrace();
	
	__block BOOL result = YES;
	__block NSError *err = nil;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if ([self supportsAnonymousAuthentication])
		{
			XMPPAnonymousAuthentication *anonymousAuth = [[XMPPAnonymousAuthentication alloc] initWithStream:self];
			
			result = [self authenticate:anonymousAuth error:&err];
		}
		else
		{
			NSString *errMsg = @"The server does not support anonymous authentication.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamUnsupportedAction userInfo:info];
			
			result = NO;
		}
	}};
	
	if (dispatch_get_current_queue() == self.xmppQueue)
		block();
	else
		dispatch_sync(self.xmppQueue, block);
	
	if (errPtr)
		*errPtr = err;
	
	return result;
}

@end
