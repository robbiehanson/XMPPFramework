#import "XMPPMessageArchiving.h"
#import "XMPPFramework.h"
#import "XMPPLogging.h"
#import "NSNumber+XMPP.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
// Log flags: trace
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_VERBOSE; // | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

#define XMLNS_XMPP_ARCHIVE @"urn:xmpp:archive"


@implementation XMPPMessageArchiving

- (id)init
{
	// This will cause a crash - it's designed to.
	// Only the init methods listed in XMPPMessageArchiving.h are supported.
	
	return [self initWithMessageArchivingStorage:nil dispatchQueue:NULL];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	// This will cause a crash - it's designed to.
	// Only the init methods listed in XMPPMessageArchiving.h are supported.
	
	return [self initWithMessageArchivingStorage:nil dispatchQueue:queue];
}

- (id)initWithMessageArchivingStorage:(id <XMPPMessageArchivingStorage>)storage
{
	return [self initWithMessageArchivingStorage:storage dispatchQueue:NULL];
}

- (id)initWithMessageArchivingStorage:(id <XMPPMessageArchivingStorage>)storage dispatchQueue:(dispatch_queue_t)queue
{
	NSParameterAssert(storage != nil);
	
	if ((self = [super initWithDispatchQueue:queue]))
	{
		if ([storage configureWithParent:self queue:moduleQueue])
		{
			xmppMessageArchivingStorage = storage;
		}
		else
		{
			XMPPLogError(@"%@: %@ - Unable to configure storage!", THIS_FILE, THIS_METHOD);
		}
		
		NSXMLElement *_default = [NSXMLElement elementWithName:@"default"];
		[_default addAttributeWithName:@"expire" stringValue:@"604800"];
		[_default addAttributeWithName:@"save" stringValue:@"body"];
		
		NSXMLElement *pref = [NSXMLElement elementWithName:@"pref" xmlns:XMLNS_XMPP_ARCHIVE];
		[pref addChild:_default];
		
		preferences = pref;
	}
	return self;
}

- (BOOL)activate:(XMPPStream *)aXmppStream
{
	XMPPLogTrace();
	
	if ([super activate:aXmppStream])
	{
		XMPPLogVerbose(@"%@: Activated", THIS_FILE);
		
		// Reserved for future potential use
		
		return YES;
	}
	
	return NO;
}

- (void)deactivate
{
	XMPPLogTrace();
	
	// Reserved for future potential use
	
	[super deactivate];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)clientSideMessageArchivingOnly
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		result = clientSideMessageArchivingOnly;
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

- (void)setClientSideMessageArchivingOnly:(BOOL)flag
{
	dispatch_block_t block = ^{
		clientSideMessageArchivingOnly = flag;
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (NSXMLElement *)preferences
{
	__block NSXMLElement *result = nil;
	
	dispatch_block_t block = ^{
		
		result = [preferences copy];
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

- (void)setPreferences:(NSXMLElement *)newPreferences
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		// Update cached value
		
		preferences = [newPreferences copy];
		
		// Update storage
		
		if ([xmppMessageArchivingStorage respondsToSelector:@selector(setPreferences:forUser:)])
		{
			XMPPJID *myBareJid = [[xmppStream myJID] bareJID];
			
			[xmppMessageArchivingStorage setPreferences:preferences forUser:myBareJid];
		}
		
		// Todo:
		// 
		//  - Send new pref to server (if changed)
	}};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)shouldArchiveMessage:(XMPPMessage *)message outgoing:(BOOL)isOutgoing xmppStream:(XMPPStream *)xmppStream
{
	// XEP-0136 Section 2.9: Preferences precedence rules:
	// 
	// When determining archiving preferences for a given message, the following rules shall apply:
	// 
	// 1. 'save' value is taken from the <session> element that matches the conversation, if present,
	//    else from the <item> element that matches the contact (see JID Matching), if present,
	//    else from the default element.
	// 
	// 2. 'otr' and 'expire' value are taken from the <item> element that matches the contact, if present,
	//    else from the default element.
	
	NSXMLElement *match = nil;
	
	NSString *messageThread = [[message elementForName:@"thread"] stringValue];
	if (messageThread)
	{
		// First priority - matching session element
		
		for (NSXMLElement *session in [preferences elementsForName:@"session"])
		{
			NSString *sessionThread = [session attributeStringValueForName:@"thread"];
			if ([messageThread isEqualToString:sessionThread])
			{
				match = session;
				break;
			}
		}
	}
	
	if (match == nil)
	{
		// Second priority - matching item element
		//
		// 
		// XEP-0136 Section 10.1: JID Matching
		// 
		// The following rules apply:
		// 
		// 1. If the JID is of the form <localpart@domain.tld/resource>, only this particular JID matches.
		// 2. If the JID is of the form <localpart@domain.tld>, any resource matches.
		// 3. If the JID is of the form <domain.tld>, any node matches.
		// 
		// However, having these rules only would make impossible a match like "all collections having JID
		// exactly equal to bare JID/domain JID". Therefore, when the 'exactmatch' attribute is set to "true" or
		// "1" on the <list/>, <remove/> or <item/> element, a JID value such as "example.com" matches
		// that exact JID only rather than <*@example.com>, <*@example.com/*>, or <example.com/*>, and
		// a JID value such as "localpart@example.com" matches that exact JID only rather than
		// <localpart@example.com/*>.
		
		XMPPJID *messageJid;
		if (isOutgoing)
			messageJid = [message to];
		else
			messageJid = [message from];
		
		NSXMLElement *match_full = nil;
		NSXMLElement *match_bare = nil;
		NSXMLElement *match_domain = nil;
		
		for (NSXMLElement *item in [preferences elementsForName:@"item"])
		{
			XMPPJID *itemJid = [XMPPJID jidWithString:[item attributeStringValueForName:@"jid"]];
			
			if (itemJid.resource)
			{
				BOOL match = [messageJid isEqualToJID:itemJid options:XMPPJIDCompareFull];
				
				if (match && (match_full == nil))
				{
					match_full = item;
				}
			}
			else if (itemJid.user)
			{
				BOOL exactmatch = [item attributeBoolValueForName:@"exactmatch" withDefaultValue:NO];
				BOOL match;
				
				if (exactmatch)
					match = [messageJid isEqualToJID:itemJid options:XMPPJIDCompareFull];
				else
					match = [messageJid isEqualToJID:itemJid options:XMPPJIDCompareBare];
				
				if (match && (match_bare == nil))
				{
					match_bare = item;
				}
			}
			else
			{
				BOOL exactmatch = [item attributeBoolValueForName:@"exactmatch" withDefaultValue:NO];
				BOOL match;
				
				if (exactmatch)
					match = [messageJid isEqualToJID:itemJid options:XMPPJIDCompareFull];
				else
					match = [messageJid isEqualToJID:itemJid options:XMPPJIDCompareDomain];
				
				if (match && (match_domain == nil))
				{
					match_domain = item;
				}
			}
		}
		
		if (match_full)
			match = match_full;
		else if (match_bare)
			match = match_bare;
		else if (match_domain)
			match = match_domain;
	}
	
	if (match == nil)
	{
		// Third priority - default element
		
		match = [preferences elementForName:@"default"];
	}
	
	if (match == nil)
	{
		XMPPLogWarn(@"%@: No message archive rule found for message! Discarding...", THIS_FILE);
		return NO;
	}
	
	// The 'save' attribute specifies the user's default setting for Save Mode.
	// The allowable values are:
	// 
	// - body    : the saving entity SHOULD save only <body/> elements.
	// - false   : the saving entity MUST save nothing.
	// - message : the saving entity SHOULD save the full XML content of each <message/> element.
	// - stream  : the saving entity SHOULD save every byte that passes over the stream in either direction.
	// 
	// Note: We currently only support body, and treat values of 'message' or 'stream' the same as 'body'.
	
	NSString *save = [[match attributeStringValueForName:@"save"] lowercaseString];
	
	if ([save isEqualToString:@"false"])
		return NO;
	else
		return YES;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	XMPPLogTrace();
	
	if (clientSideMessageArchivingOnly) return;
	
	// Fetch most recent preferences
	
	if ([xmppMessageArchivingStorage respondsToSelector:@selector(preferencesForUser:)])
	{
		XMPPJID *myBareJid = [[xmppStream myJID] bareJID];
		
		preferences = [xmppMessageArchivingStorage preferencesForUser:myBareJid];
	}
	
	// Request archiving preferences from server
	// 
	// <iq type='get'>
	//   <pref xmlns='urn:xmpp:archive'/>
	// </iq>
	
	NSXMLElement *pref = [NSXMLElement elementWithName:@"pref" xmlns:XMLNS_XMPP_ARCHIVE];
	XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:nil elementID:nil child:pref];
	
	[sender sendElement:iq];
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	NSString *type = [iq type];
	
	if ([type isEqualToString:@"result"])
	{
		NSXMLElement *pref = [iq elementForName:@"pref" xmlns:XMLNS_XMPP_ARCHIVE];
		if (pref)
		{
			[self setPreferences:pref];
		}
	}
	else if ([type isEqualToString:@"set"])
	{
		// We receive the following type of IQ when we send a chat message within facebook from another device:
		// 
		// <iq from="chat.facebook.com" to="-121201407@chat.facebook.com/e49b026a_4BA226A73192D type="set">
		//   <own-message xmlns="http://www.facebook.com/xmpp/messages" to="-123@chat.facebook.com" self="false">
		//     <body>Hi Jilr</body>
		//   </own-message>
		// </iq>
		
		NSXMLElement *ownMessage = [iq elementForName:@"own-message" xmlns:@"http://www.facebook.com/xmpp/messages"];
		if (ownMessage)
		{
			BOOL isSelf = [ownMessage attributeBoolValueForName:@"self" withDefaultValue:NO];
			if (!isSelf)
			{
				NSString *bodyStr = [[ownMessage elementForName:@"body"] stringValue];
				if ([bodyStr length] > 0)
				{
					NSXMLElement *body = [NSXMLElement elementWithName:@"body" stringValue:bodyStr];
					
					XMPPJID *to = [XMPPJID jidWithString:[ownMessage attributeStringValueForName:@"to"]];
					XMPPMessage *message = [XMPPMessage messageWithType:@"chat" to:to];
					[message addChild:body];
					
					if ([self shouldArchiveMessage:message outgoing:YES xmppStream:sender])
					{
						[xmppMessageArchivingStorage archiveMessage:message outgoing:YES xmppStream:sender];
					}
				}
			}
			
			return YES;
		}
	}
	
	return NO;
}

- (void)xmppStream:(XMPPStream *)sender didSendMessage:(XMPPMessage *)message
{
	XMPPLogTrace();
	
	if ([self shouldArchiveMessage:message outgoing:YES xmppStream:sender])
	{
		[xmppMessageArchivingStorage archiveMessage:message outgoing:YES xmppStream:sender];
	}
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	XMPPLogTrace();
	
	if ([self shouldArchiveMessage:message outgoing:NO xmppStream:sender])
	{
		[xmppMessageArchivingStorage archiveMessage:message outgoing:NO xmppStream:sender];
	}
}

@end
