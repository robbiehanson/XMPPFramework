#import "XMPPDeprecatedDigestAuthentication.h"
#import "XMPP.h"
#import "XMPPInternal.h"
#import "XMPPLogging.h"
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


@implementation XMPPDeprecatedDigestAuthentication
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
	// This deprecated method isn't listed in the normal mechanisms list
	return nil;
}

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
	
	// The server does not appear to support SASL authentication (at least any type we can use)
	// So we'll revert back to the old fashioned jabber:iq:auth mechanism
	
	XMPPJID *myJID = xmppStream.myJID;
	
	NSString *username = [myJID user];
	NSString *resource = [myJID resource];
	
	if ([resource length] == 0)
	{
		// If resource is nil or empty, we need to auto-create one
		
		resource = [XMPPStream generateUUID];
	}
	
	NSString *rootID = [[[xmppStream rootElement] attributeForName:@"id"] stringValue];
	NSString *digestStr = [NSString stringWithFormat:@"%@%@", rootID, password];
	
	NSString *digest = [[[digestStr dataUsingEncoding:NSUTF8StringEncoding] xmpp_sha1Digest] xmpp_hexStringValue];
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:auth"];
	[query addChild:[NSXMLElement elementWithName:@"username" stringValue:username]];
	[query addChild:[NSXMLElement elementWithName:@"resource" stringValue:resource]];
	[query addChild:[NSXMLElement elementWithName:@"digest"   stringValue:digest]];
	
	XMPPIQ *iq = [XMPPIQ iqWithType:@"set"];
	[iq addChild:query];
	
	[xmppStream sendAuthElement:iq];
	
	return YES;
}

- (XMPPHandleAuthResponse)handleAuth:(NSXMLElement *)authResponse
{
	XMPPLogTrace();
	
	// We used the old fashioned jabber:iq:auth mechanism
	
	if ([[authResponse attributeStringValueForName:@"type"] isEqualToString:@"error"])
	{
		return XMPPHandleAuthResponseFailed;
	}
	else
	{
		return XMPPHandleAuthResponseSuccess;
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

@implementation XMPPStream (XMPPDeprecatedDigestAuthentication)

/**
 * This method only applies to servers that don't support XMPP version 1.0, as defined in RFC 3920.
 * With these servers, we attempt to discover supported authentication modes via the jabber:iq:auth namespace.
**/
- (BOOL)supportsDeprecatedDigestAuthentication
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		// The root element can be properly queried for authentication mechanisms anytime after the
		// stream:features are received, and TLS has been setup (if required)
		if (self.state >= STATE_XMPP_POST_NEGOTIATION)
		{
			// Search for an iq element within the rootElement.
			// Recall that some servers might stupidly add a "jabber:client" namespace which might cause problems
			// if we simply used the elementForName method.
			
			NSXMLElement *iq = nil;
			
			NSUInteger i, count = [self.rootElement childCount];
			for (i = 0; i < count; i++)
			{
				NSXMLNode *childNode = [self.rootElement childAtIndex:i];
				
				if ([childNode kind] == NSXMLElementKind)
				{
					if ([[childNode name] isEqualToString:@"iq"])
					{
						iq = (NSXMLElement *)childNode;
					}
				}
			}
			
			NSXMLElement *query = [iq elementForName:@"query" xmlns:@"jabber:iq:auth"];
			NSXMLElement *digest = [query elementForName:@"digest"];
			
			result = (digest != nil);
		}
	}};

	if (dispatch_get_specific(self.xmppQueueTag))
		block();
	else
		dispatch_sync(self.xmppQueue, block);
	
	return result;
}

@end
