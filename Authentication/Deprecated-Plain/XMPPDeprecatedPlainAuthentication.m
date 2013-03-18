#import "XMPPDeprecatedPlainAuthentication.h"
#import "XMPP.h"
#import "XMPPInternal.h"
#import "XMPPLogging.h"
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


@implementation XMPPDeprecatedPlainAuthentication
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
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:auth"];
	[query addChild:[NSXMLElement elementWithName:@"username" stringValue:username]];
	[query addChild:[NSXMLElement elementWithName:@"resource" stringValue:resource]];
	[query addChild:[NSXMLElement elementWithName:@"password" stringValue:password]];
	
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
		return XMPP_AUTH_FAIL;
	}
	else
	{
		return XMPP_AUTH_SUCCESS;
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

@implementation XMPPStream (XMPPDeprecatedPlainAuthentication)

/**
 * This method only applies to servers that don't support XMPP version 1.0, as defined in RFC 3920.
 * With these servers, we attempt to discover supported authentication modes via the jabber:iq:auth namespace.
**/
- (BOOL)supportsDeprecatedPlainAuthentication
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
			NSXMLElement *plain = [query elementForName:@"password"];
			
			result = (plain != nil);
		}
	}};
	
	if (dispatch_get_current_queue() == self.xmppQueue)
		block();
	else
		dispatch_sync(self.xmppQueue, block);
	
	return result;
}

@end
