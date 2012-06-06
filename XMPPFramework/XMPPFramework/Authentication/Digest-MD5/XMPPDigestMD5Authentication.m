#import "XMPPDigestMD5Authentication.h"
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

@interface XMPPDigestMD5Authentication ()
{
  #if __has_feature(objc_arc_weak)
	__weak XMPPStream *xmppStream;
  #else
	__unsafe_unretained XMPPStream *xmppStream;
  #endif
	
	BOOL awaitingChallenge;
	
	NSString *realm;
	NSString *nonce;
	NSString *qop;
	NSString *cnonce;
	NSString *digestURI;
	NSString *username;
	NSString *password;
}

// The properties are hooks (primarily for testing)

@property (nonatomic, strong) NSString *realm;
@property (nonatomic, strong) NSString *nonce;
@property (nonatomic, strong) NSString *qop;
@property (nonatomic, strong) NSString *cnonce;
@property (nonatomic, strong) NSString *digestURI;
@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSString *password;

- (NSDictionary *)dictionaryFromChallenge:(NSXMLElement *)challenge;
- (NSString *)base64EncodedFullResponse;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPDigestMD5Authentication

+ (NSString *)mechanismName
{
	return @"DIGEST-MD5";
}

@synthesize realm;
@synthesize nonce;
@synthesize qop;
@synthesize cnonce;
@synthesize digestURI;
@synthesize username;
@synthesize password;

- (id)initWithStream:(XMPPStream *)stream password:(NSString *)inPassword
{
	if ((self = [super init]))
	{
		xmppStream = stream;
		password = inPassword;
	}
	return self;
}

- (BOOL)start:(NSError **)errPtr
{
	XMPPLogTrace();
	
	// <auth xmlns="urn:ietf:params:xml:ns:xmpp-sasl" mechanism="DIGEST-MD5" />
	
	NSXMLElement *auth = [NSXMLElement elementWithName:@"auth" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
	[auth addAttributeWithName:@"mechanism" stringValue:@"DIGEST-MD5"];
	
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
	
	realm   = [auth objectForKey:@"realm"];
	nonce   = [auth objectForKey:@"nonce"];
	qop     = [auth objectForKey:@"qop"];
	
	// Fill out all the other variables
	// 
	// Sometimes the realm isn't specified.
	// In this case I believe the realm is implied as the virtual host name.
	
	XMPPJID *myJID = xmppStream.myJID;
	
	NSString *virtualHostName = [myJID domain];
	NSString *serverHostName = xmppStream.hostName;
	
	if (realm == nil)
	{
		if ([virtualHostName length] > 0)
			realm = virtualHostName;
		else
			realm = serverHostName;
	}
	
	if ([virtualHostName length] > 0)
		digestURI = [NSString stringWithFormat:@"xmpp/%@", virtualHostName];
	else
		digestURI = [NSString stringWithFormat:@"xmpp/%@", serverHostName];
	
	if (cnonce == nil)
		cnonce = [XMPPStream generateUUID];
	
	username = [myJID user];
	
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
	
	if ([[authResponse name] isEqualToString:@"challenge"])
	{
		NSDictionary *auth = [self dictionaryFromChallenge:authResponse];
		NSString *rspauth = [auth objectForKey:@"rspauth"];
		
		if (rspauth == nil)
		{
			// We're getting another challenge?
			// Not sure what this could possibly be, so for now we'll assume it's a failure.
			
			return XMPP_AUTH_FAIL;
		}
		else
		{
			// We received another challenge, but it's really just an rspauth
			// This is supposed to be included in the success element (according to the updated RFC)
			// but many implementations incorrectly send it inside a second challenge request.
			// 
			// Create and send empty challenge response element.
			
			NSXMLElement *response =
			    [NSXMLElement elementWithName:@"response" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
			
			[xmppStream sendAuthElement:response];
			
			return XMPP_AUTH_CONTINUE;
		}
	}
	else if ([[authResponse name] isEqualToString:@"success"])
	{
		return XMPP_AUTH_SUCCESS;
	}
	else
	{
		return XMPP_AUTH_FAIL;
	}	
}

- (XMPPHandleAuthResponse)handleAuth:(NSXMLElement *)auth
{
	XMPPLogTrace();
	
	if (awaitingChallenge)
	{
		return [self handleAuth1:auth];
	}
	else
	{
		return [self handleAuth2:auth];
	}
}

- (NSDictionary *)dictionaryFromChallenge:(NSXMLElement *)challenge
{
	// The value of the challenge stanza is base 64 encoded.
	// Once "decoded", it's just a string of key=value pairs separated by commas.
	
	NSData *base64Data = [[challenge stringValue] dataUsingEncoding:NSASCIIStringEncoding];
	NSData *decodedData = [base64Data base64Decoded];
	
	NSString *authStr = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
	
	XMPPLogVerbose(@"%@: Decoded challenge: %@", THIS_FILE, authStr);
	
	NSArray *components = [authStr componentsSeparatedByString:@","];
	NSMutableDictionary *auth = [NSMutableDictionary dictionaryWithCapacity:5];
	
	for (NSString *component in components)
	{
		NSRange separator = [component rangeOfString:@"="];
		if (separator.location != NSNotFound)
		{
			NSMutableString *key = [[component substringToIndex:separator.location] mutableCopy];
			NSMutableString *value = [[component substringFromIndex:separator.location+1] mutableCopy];
			
			if(key) CFStringTrimWhitespace((__bridge CFMutableStringRef)key);
			if(value) CFStringTrimWhitespace((__bridge CFMutableStringRef)value);
			
			if ([value hasPrefix:@"\""] && [value hasSuffix:@"\""] && [value length] > 2)
			{
				// Strip quotes from value
				[value deleteCharactersInRange:NSMakeRange(0, 1)];
				[value deleteCharactersInRange:NSMakeRange([value length]-1, 1)];
			}
			
			[auth setObject:value forKey:key];
		}
	}
	
	return auth;
}

- (NSString *)response
{
	NSString *HA1str = [NSString stringWithFormat:@"%@:%@:%@", username, realm, password];
	NSString *HA2str = [NSString stringWithFormat:@"AUTHENTICATE:%@", digestURI];
	
	XMPPLogVerbose(@"HA1str: %@", HA1str);
	XMPPLogVerbose(@"HA2str: %@", HA2str);
	
	NSData *HA1dataA = [[HA1str dataUsingEncoding:NSUTF8StringEncoding] md5Digest];
	NSData *HA1dataB = [[NSString stringWithFormat:@":%@:%@", nonce, cnonce] dataUsingEncoding:NSUTF8StringEncoding];
	
	XMPPLogVerbose(@"HA1dataA: %@", HA1dataA);
	XMPPLogVerbose(@"HA1dataB: %@", HA1dataB);
	
	NSMutableData *HA1data = [NSMutableData dataWithCapacity:([HA1dataA length] + [HA1dataB length])];
	[HA1data appendData:HA1dataA];
	[HA1data appendData:HA1dataB];
	
	XMPPLogVerbose(@"HA1data: %@", HA1data);
	
	NSString *HA1 = [[HA1data md5Digest] hexStringValue];
	
	NSString *HA2 = [[[HA2str dataUsingEncoding:NSUTF8StringEncoding] md5Digest] hexStringValue];
	
	XMPPLogVerbose(@"HA1: %@", HA1);
	XMPPLogVerbose(@"HA2: %@", HA2);
	
	NSString *responseStr = [NSString stringWithFormat:@"%@:%@:00000001:%@:auth:%@",
                           HA1, nonce, cnonce, HA2];
	
	XMPPLogVerbose(@"responseStr: %@", responseStr);
	
	NSString *response = [[[responseStr dataUsingEncoding:NSUTF8StringEncoding] md5Digest] hexStringValue];
	
	XMPPLogVerbose(@"response: %@", response);
	
	return response;
}

- (NSString *)base64EncodedFullResponse
{
	NSMutableString *buffer = [NSMutableString stringWithCapacity:100];
	[buffer appendFormat:@"username=\"%@\",", username];
	[buffer appendFormat:@"realm=\"%@\",", realm];
	[buffer appendFormat:@"nonce=\"%@\",", nonce];
	[buffer appendFormat:@"cnonce=\"%@\",", cnonce];
	[buffer appendFormat:@"nc=00000001,"];
	[buffer appendFormat:@"qop=auth,"];
	[buffer appendFormat:@"digest-uri=\"%@\",", digestURI];
	[buffer appendFormat:@"response=%@,", [self response]];
	[buffer appendFormat:@"charset=utf-8"];
	
	XMPPLogVerbose(@"%@: Decoded response: %@", THIS_FILE, buffer);
	
	NSData *utf8data = [buffer dataUsingEncoding:NSUTF8StringEncoding];
	
	return [utf8data base64Encoded];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPStream (XMPPDigestMD5Authentication)

- (BOOL)supportsDigestMD5Authentication
{
	return [self supportsAuthenticationMechanism:[XMPPDigestMD5Authentication mechanismName]];
}

@end
