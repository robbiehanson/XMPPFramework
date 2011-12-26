#import "XMPPDigestAuthentication.h"

#import "NSData+XMPP.h"
#import "XMPPLogging.h"
#import "XMPPStream.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_INFO; // | XMPP_LOG_FLAG_SEND_RECV; // | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif


@implementation XMPPDigestAuthentication

- (id)initWithChallenge:(NSXMLElement *)challenge
{
	if((self = [super init]))
	{
		// Convert the base 64 encoded data into a string
		NSData *base64Data = [[challenge stringValue] dataUsingEncoding:NSASCIIStringEncoding];
		NSData *decodedData = [base64Data base64Decoded];
		
		NSString *authStr = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
		
		XMPPLogVerbose(@"%@: Decoded challenge: %@", THIS_FILE, authStr);
		
		// Extract all the key=value pairs, and put them in a dictionary for easy lookup
		NSMutableDictionary *auth = [NSMutableDictionary dictionaryWithCapacity:5];
		
		NSArray *components = [authStr componentsSeparatedByString:@","];
		
		int i;
		for(i = 0; i < [components count]; i++)
		{
			NSString *component = [components objectAtIndex:i];
			
			NSRange separator = [component rangeOfString:@"="];
			if(separator.location != NSNotFound)
			{
				NSMutableString *key = [[component substringToIndex:separator.location] mutableCopy];
				NSMutableString *value = [[component substringFromIndex:separator.location+1] mutableCopy];
				
				if(key) CFStringTrimWhitespace((__bridge CFMutableStringRef)key);
				if(value) CFStringTrimWhitespace((__bridge CFMutableStringRef)value);
				
				if([value hasPrefix:@"\""] && [value hasSuffix:@"\""] && [value length] > 2)
				{
					// Strip quotes from value
					[value deleteCharactersInRange:NSMakeRange(0, 1)];
					[value deleteCharactersInRange:NSMakeRange([value length]-1, 1)];
				}
				
				[auth setObject:value forKey:key];
				
			}
		}
		
		// Extract and retain the elements we need
		rspauth = [[auth objectForKey:@"rspauth"] copy];
		realm = [[auth objectForKey:@"realm"] copy];
		nonce = [[auth objectForKey:@"nonce"] copy];
		qop = [[auth objectForKey:@"qop"] copy];
		
		// Generate cnonce
		cnonce = [XMPPStream generateUUID];
	}
	return self;
}


- (NSString *)rspauth
{
	return [rspauth copy];
}

- (NSString *)realm
{
	return [realm copy];
}

- (void)setRealm:(NSString *)newRealm
{
	if(![realm isEqual:newRealm])
	{
		realm = [newRealm copy];
	}
}

- (void)setDigestURI:(NSString *)newDigestURI
{
	if(![digestURI isEqual:newDigestURI])
	{
		digestURI = [newDigestURI copy];
	}
}

- (void)setUsername:(NSString *)newUsername password:(NSString *)newPassword
{
	if(![username isEqual:newUsername])
	{
		username = [newUsername copy];
	}
	
	if(![password isEqual:newPassword])
	{
		password = [newPassword copy];
	}
}

- (NSString *)response
{
	NSString *HA1str = [NSString stringWithFormat:@"%@:%@:%@", username, realm, password];
	NSString *HA2str = [NSString stringWithFormat:@"AUTHENTICATE:%@", digestURI];
	
	NSData *HA1dataA = [[HA1str dataUsingEncoding:NSUTF8StringEncoding] md5Digest];
	NSData *HA1dataB = [[NSString stringWithFormat:@":%@:%@", nonce, cnonce] dataUsingEncoding:NSUTF8StringEncoding];
	
	NSMutableData *HA1data = [NSMutableData dataWithCapacity:([HA1dataA length] + [HA1dataB length])];
	[HA1data appendData:HA1dataA];
	[HA1data appendData:HA1dataB];
	
	NSString *HA1 = [[HA1data md5Digest] hexStringValue];
	
	NSString *HA2 = [[[HA2str dataUsingEncoding:NSUTF8StringEncoding] md5Digest] hexStringValue];
	
	NSString *responseStr = [NSString stringWithFormat:@"%@:%@:00000001:%@:auth:%@",
                           HA1, nonce, cnonce, HA2];
	
	NSString *response = [[[responseStr dataUsingEncoding:NSUTF8StringEncoding] md5Digest] hexStringValue];
	
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
	
	XMPPLogSend(@"decoded response: %@", buffer);
	
	NSData *utf8data = [buffer dataUsingEncoding:NSUTF8StringEncoding];
	
	return [utf8data base64Encoded];
}

@end
