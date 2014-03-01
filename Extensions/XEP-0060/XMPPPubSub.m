#import "XMPPPubSub.h"
#import "XMPPIQ+XEP_0060.h"
#import "XMPPInternal.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Defined in XMPPIQ+XEP_0060.h
//
// #define XMLNS_PUBSUB             @"http://jabber.org/protocol/pubsub"
// #define XMLNS_PUBSUB_OWNER       @"http://jabber.org/protocol/pubsub#owner"
// #define XMLNS_PUBSUB_EVENT       @"http://jabber.org/protocol/pubsub#event"
// #define XMLNS_PUBSUB_NODE_CONFIG @"http://jabber.org/protocol/pubsub#node_config"


@implementation XMPPPubSub
{
	XMPPJID *serviceJID;
	XMPPJID *myJID;
	
	NSMutableDictionary *subscribeDict;
	NSMutableDictionary *unsubscribeDict;
	NSMutableDictionary *retrieveDict;
	NSMutableDictionary *configSubDict;
	NSMutableDictionary *createDict;
	NSMutableDictionary *deleteDict;
	NSMutableDictionary *configNodeDict;
	NSMutableDictionary *publishDict;
}

+ (BOOL)isPubSubMessage:(XMPPMessage *)message
{
	NSXMLElement *event = [message elementForName:@"event" xmlns:XMLNS_PUBSUB_EVENT];
	return (event != nil);
}

@synthesize serviceJID;

- (id)init
{
	// This will cause a crash - it's designed to.
	// Only the init methods listed in XMPPPubSub.h are supported.
	
	return [self initWithServiceJID:nil dispatchQueue:NULL];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	// This will cause a crash - it's designed to.
	// Only the init methods listed in XMPPPubSub.h are supported.
	
	return [self initWithServiceJID:nil dispatchQueue:NULL];
}

- (id)initWithServiceJID:(XMPPJID *)aServiceJID
{
	return [self initWithServiceJID:aServiceJID dispatchQueue:NULL];
}

- (id)initWithServiceJID:(XMPPJID *)aServiceJID dispatchQueue:(dispatch_queue_t)queue
{
	// If aServiceJID is nil, we won't include a 'to' attribute in the <iq/> element(s) we send.
	// This is the proper configuration for PEP, as it uses the bare JID as the pubsub node.
	
	if ((self = [super initWithDispatchQueue:queue]))
	{
		serviceJID = [aServiceJID copy];
		
		subscribeDict   = [[NSMutableDictionary alloc] init];
		unsubscribeDict = [[NSMutableDictionary alloc] init];
		retrieveDict    = [[NSMutableDictionary alloc] init];
		configSubDict   = [[NSMutableDictionary alloc] init];
		createDict      = [[NSMutableDictionary alloc] init];
		deleteDict      = [[NSMutableDictionary alloc] init];
		configNodeDict  = [[NSMutableDictionary alloc] init];
		publishDict     = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (BOOL)activate:(XMPPStream *)aXmppStream
{
	if ([super activate:aXmppStream])
	{
		if (serviceJID == nil)
		{
			myJID = xmppStream.myJID;
			[[NSNotificationCenter defaultCenter] addObserver:self
			                                         selector:@selector(myJIDDidChange:)
			                                             name:XMPPStreamDidChangeMyJIDNotification
			                                           object:nil];
		}
		
		return YES;
	}
	
	return NO;
}

- (void)deactivate
{
	[subscribeDict   removeAllObjects];
	[unsubscribeDict removeAllObjects];
	[retrieveDict    removeAllObjects];
	[configSubDict   removeAllObjects];
	[createDict      removeAllObjects];
	[deleteDict      removeAllObjects];
	[configNodeDict  removeAllObjects];
	[publishDict     removeAllObjects];
	
	if (serviceJID == nil) {
		[[NSNotificationCenter defaultCenter] removeObserver:self name:XMPPStreamDidChangeMyJIDNotification object:nil];
	}
	[super deactivate];
}

- (void)myJIDDidChange:(NSNotification *)notification
{
	// Notifications are delivered on the thread/queue that posted them.
	// In this case, they are delivered on xmppStream's internal processing queue.
	
	XMPPStream *stream = (XMPPStream *)[notification object];
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if (xmppStream == stream)
		{
			myJID = xmppStream.myJID;
		}
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Delegate method to receive incoming IQ stanzas.
**/
- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	// Check to see if IQ is from our PubSub/PEP service
	if (serviceJID) {
		if (![serviceJID isEqualToJID:[iq from]]) return NO;
	}
	else {
		if (![myJID isEqualToJID:[iq from] options:XMPPJIDCompareBare]) return NO;
	}
	
	NSString *elementID = [iq elementID];
	NSString *node = nil;
	
	if ((node = [subscribeDict objectForKey:elementID]))
	{
		// Example subscription success response:
		//
		// <iq type='result' from='pubsub.shakespeare.lit' to='francisco@denmark.lit/barracks' id='sub1'>
		//   <pubsub xmlns='http://jabber.org/protocol/pubsub'>
		//     <subscription
		//         node='princely_musings'
		//         jid='francisco@denmark.lit'
		//         subid='ba49252aaa4f5d320c24d3766f0bdcade78c78d3'
		//         subscription='subscribed'/>
		//   </pubsub>
		// </iq>
		//
		// Example subscription error response:
		//
		// <iq type='error' from='pubsub.shakespeare.lit' to='francisco@denmark.lit/barracks' id='sub1'>
		//   <error type='modify'>
		//     <bad-request xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
		//     <invalid-jid xmlns='http://jabber.org/protocol/pubsub#errors'/>
		//   </error>
		// </iq>
		// 
		// XEP-0060 provides many other example responses, but
		// not all of them fit perfectly into the subscribed/not-subscribed categories.
		// For example, the subscription could be:
		// 
		// - pending, approval required
		// - unconfigured, configuration required
		// - unconfigured, configuration supported
		//
		// However, in the general sense, the subscription request was accepted.
		// So these special cases will still be broadcast as "subscibed",
		// and it is the delegates responsibility to handle these special cases if the server is configured as such.
		
		if ([[iq type] isEqualToString:@"result"])
			[multicastDelegate xmppPubSub:self didSubscribeToNode:node withResult:iq];
		else
			[multicastDelegate xmppPubSub:self didNotSubscribeToNode:node withError:iq];
		
		[subscribeDict removeObjectForKey:elementID];
		return YES;
	}
	else if ((node = [unsubscribeDict objectForKey:elementID]))
	{
		// Example unsubscribe success response:
		//
		// <iq type='result' from='pubsub.shakespeare.lit' to='francisco@denmark.lit/barracks' id='unsub1'/>
		//
		// Example unsubscribe error response:
		//
		// <iq type='error' from='pubsub.shakespeare.lit' to='francisco@denmark.lit/barracks' id='unsub1'>
		//   <error type='modify'>
		//     <bad-request xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
		//     <subid-required xmlns='http://jabber.org/protocol/pubsub#errors'/>
		//   </error>
		// </iq>
		//
		// XEP-0060 provides many other example responses, but
		// not all of them fit perfectly into the unsubscribed/not-unsubscribed categories.
		//
		// For example, there's an error that gets returned if the client wasn't subscribed.
		// Depending on the client, this could possibly get treated as a successful unsubscribe action.
		//
		// It is the delegates responsibility to handle these special cases.
		
		if ([[iq type] isEqualToString:@"result"])
			[multicastDelegate xmppPubSub:self didUnsubscribeFromNode:node withResult:iq];
		else
			[multicastDelegate xmppPubSub:self didNotUnsubscribeFromNode:node withError:iq];
		
		[unsubscribeDict removeObjectForKey:elementID];
		return YES;
	}
	else if ((node = [retrieveDict objectForKey:elementID]))
	{
		// Example retrieve success response:
		//
		// <iq type='result' from='pubsub.shakespeare.lit' to='francisco@denmark.lit' id='subscriptions1'>
		//   <pubsub xmlns='http://jabber.org/protocol/pubsub'>
		//     <subscriptions>
		//       <subscription node='node1' jid='francisco@denmark.lit' subscription='subscribed'/>
		//       <subscription node='node2' jid='francisco@denmark.lit' subscription='subscribed'/>
		//       <subscription node='node5' jid='francisco@denmark.lit' subscription='unconfigured'/>
		//       <subscription node='node6' jid='francisco@denmark.lit' subscription='subscribed' subid='123-abc'/>
		//       <subscription node='node6' jid='francisco@denmark.lit' subscription='subscribed' subid='004-yyy'/>
		//     </subscriptions>
		//   </pubsub>
		// </iq>
		//
		// Example retrieve error response:
		//
		// <iq type='error' from='pubsub.shakespeare.lit' to='francisco@denmark.lit/barracks' id='subscriptions1'>
		//   <error type='cancel'>
		//     <feature-not-implemented xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
		//     <unsupported xmlns='http://jabber.org/protocol/pubsub#errors' feature='retrieve-subscriptions'/>
		//   </error>
		// </iq>
		
		if ([[iq type] isEqualToString:@"result"])
		{
			if ([node isKindOfClass:[NSNull class]])
				[multicastDelegate xmppPubSub:self didRetrieveSubscriptions:iq];
			else
				[multicastDelegate xmppPubSub:self didRetrieveSubscriptions:iq forNode:node];
		}
		else
		{
			if ([node isKindOfClass:[NSNull class]])
				[multicastDelegate xmppPubSub:self didNotRetrieveSubscriptions:iq];
			else
				[multicastDelegate xmppPubSub:self didNotRetrieveSubscriptions:iq forNode:node];
		}
		
		[retrieveDict removeObjectForKey:elementID];
		return YES;
	}
	else if ((node = [configSubDict objectForKey:elementID]))
	{
		// Example configure subscription success response:
		//
		// <iq type='result' from='pubsub.shakespeare.lit' to='francisco@denmark.lit/barracks' id='options2'/>
		//
		// Example configure subscription error response:
		//
		// <iq type='error' from='pubsub.shakespeare.lit' to='francisco@denmark.lit/barracks' id='options2'>
		//   <error type='modify'>
		//     <bad-request xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
		//     <invalid-options xmlns='http://jabber.org/protocol/pubsub#errors'/>
		//   </error>
		// </iq>
		
		if ([[iq type] isEqualToString:@"result"])
			[multicastDelegate xmppPubSub:self didConfigureSubscriptionToNode:node withResult:iq];
		else
			[multicastDelegate xmppPubSub:self didNotConfigureSubscriptionToNode:node withError:iq];
		
		[configSubDict removeObjectForKey:elementID];
		return YES;
	}
	else if ((node = [publishDict objectForKey:elementID]))
	{
		// Example publish success response:
		//
		// <iq type='result' from='pubsub.shakespeare.lit' to='hamlet@denmark.lit/blogbot' id='publish1'>
		//   <pubsub xmlns='http://jabber.org/protocol/pubsub'>
		//     <publish node='princely_musings'>
		//       <item id='ae890ac52d0df67ed7cfdf51b644e901'/>
		//     </publish>
		//   </pubsub>
		// </iq>
		//
		// Example publish error response:
		//
		// <iq type='error' from='pubsub.shakespeare.lit' id='publish1'>
		//   <error type='auth'>
		//     <forbidden xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
		//   </error>
		// </iq>
		
		if ([[iq type] isEqualToString:@"result"])
			[multicastDelegate xmppPubSub:self didPublishToNode:node withResult:iq];
		else
			[multicastDelegate xmppPubSub:self didNotPublishToNode:node withError:iq];
		
		[publishDict removeObjectForKey:elementID];
		return YES;
	}
	else if ((node = [createDict objectForKey:elementID]))
	{
		// Example create success response:
		//
		// <iq type='result' from='pubsub.shakespeare.lit' to='francisco@denmark.lit/barracks' id='options2'/>
		//
		// Example create error response:
		//
		// <iq type='error' from='pubsub.shakespeare.lit' to='francisco@denmark.lit/barracks' id='options2'>
		//   <error type='modify'>
		//     <bad-request xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
		//     <invalid-options xmlns='http://jabber.org/protocol/pubsub#errors'/>
		//   </error>
		// </iq>
		
		if ([[iq type] isEqualToString:@"result"])
			[multicastDelegate xmppPubSub:self didCreateNode:node withResult:iq];
		else
			[multicastDelegate xmppPubSub:self didNotCreateNode:node withError:iq];
		
		[createDict removeObjectForKey:elementID];
		return YES;
	}
	else if ((node = [deleteDict objectForKey:elementID]))
	{
		// Example delete success response:
		//
		// <iq type='result' from='pubsub.shakespeare.lit' id='delete1'/>
		//
		// Example delete error response:
		//
		// <iq type='error' from='pubsub.shakespeare.lit' to='hamlet@denmark.lit/elsinore' id='delete1'>
		//   <error type='auth'>
		//     <forbidden xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
		//   </error>
		// </iq>
		
		if ([[iq type] isEqualToString:@"result"])
			[multicastDelegate xmppPubSub:self didDeleteNode:node withResult:iq];
		else
			[multicastDelegate xmppPubSub:self didNotDeleteNode:node withError:iq];
		
		[deleteDict removeObjectForKey:elementID];
		return YES;
	}
	else if ((node = [configNodeDict objectForKey:elementID]))
	{
		// Example configure node success response:
		//
		// <iq type='result' from='pubsub.shakespeare.lit' to='hamlet@denmark.lit/elsinore' id='config2'/>
		//
		// Example configure node error response:
		//
		// <iq type='error' from='pubsub.shakespeare.lit' to='hamlet@denmark.lit/elsinore' id='config2'>
		//   <error type='modify'>
		//     <not-acceptable xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
		//   </error>
		// </iq>
		
		if ([[iq type] isEqualToString:@"result"])
			[multicastDelegate xmppPubSub:self didConfigureNode:node withResult:iq];
		else
			[multicastDelegate xmppPubSub:self didNotConfigureNode:node withError:iq];
		
		[configNodeDict removeObjectForKey:elementID];
		return YES;
	}
	
	return NO;
}

/**
 * Delegate method to receive incoming message stanzas.
**/
- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	// Check to see if message is from our PubSub/PEP service
	if (serviceJID) {
		if (![serviceJID isEqualToJID:[message from]]) return;
	}
	else {
		if ([myJID isEqualToJID:[message from] options:XMPPJIDCompareBare]) return;
	}
	
	// <message from='pubsub.foo.co.uk' to='admin@foo.co.uk'>
	//   <event xmlns='http://jabber.org/protocol/pubsub#event'>
	//     <items node='/pubsub.foo'>
	//       <item id='5036AA52A152B'>
	//         [... entry ...]
	//       </item>
	//     </items>
	//   </event>
	// </message>
	
	NSXMLElement *event = [message elementForName:@"event" xmlns:XMLNS_PUBSUB_EVENT];
	if (event)
	{
		[multicastDelegate xmppPubSub:self didReceiveMessage:message];
	}
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
	[subscribeDict   removeAllObjects];
	[unsubscribeDict removeAllObjects];
	[retrieveDict    removeAllObjects];
	[configSubDict   removeAllObjects];
	[createDict      removeAllObjects];
	[deleteDict      removeAllObjects];
	[configNodeDict  removeAllObjects];
	[publishDict     removeAllObjects];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utility Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSXMLElement *)formForOptions:(NSDictionary *)options withFromType:(NSString *)formTypeValue
{
	// <x xmlns='jabber:x:data' type='submit'>
	//   <field var='FORM_TYPE' type='hidden'>
	//     <value>http://jabber.org/protocol/pubsub#subscribe_options</value>
	//   </field>
	//   <field var='pubsub#deliver'><value>1</value></field>
	//   <field var='pubsub#digest'><value>0</value></field>
	//   <field var='pubsub#include_body'><value>false</value></field>
	//   <field var='pubsub#show-values'>
	//     <value>chat</value>
	//     <value>online</value>
	//     <value>away</value>
	//   </field>
	// </x>
	
	NSXMLElement *x = [NSXMLElement elementWithName:@"x" xmlns:@"jabber:x:data"];
	[x addAttributeWithName:@"type" stringValue:@"submit"];
	
	NSXMLElement *formTypeField = [NSXMLElement elementWithName:@"field"];
	[formTypeField addAttributeWithName:@"var" stringValue:@"FORM_TYPE"];
	[formTypeField addAttributeWithName:@"type" stringValue:@"hidden"];
	[formTypeField addChild:[NSXMLElement elementWithName:@"value" stringValue:formTypeValue]];
	
	[x addChild:formTypeField];
	
	[options enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop){
		
		NSAssert([key isKindOfClass:[NSString class]], @"The keys within an options dictionary must be strings");
		
		NSXMLElement *field = [NSXMLElement elementWithName:@"field"];
		
		NSString *var = (NSString *)key;
		[field addAttributeWithName:@"var" stringValue:var];
		
		if ([obj isKindOfClass:[NSArray class]])
		{
			NSArray *values = (NSArray *)obj;
			for (id value in values)
			{
				[field addChild:[NSXMLElement elementWithName:@"value" objectValue:value]];
			}
		}
		else
		{
			[field addChild:[NSXMLElement elementWithName:@"value" objectValue:obj]];
		}
		
		[x addChild:field];
	}];
	return x;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Subscription Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)subscribeToNode:(NSString *)node
{
	return [self subscribeToNode:node withJID:nil options:nil];
}

- (NSString *)subscribeToNode:(NSString *)node withJID:(XMPPJID *)myBareOrFullJid
{
	return [self subscribeToNode:node withJID:myBareOrFullJid options:nil];
}

- (NSString *)subscribeToNode:(NSString *)aNode withJID:(XMPPJID *)myBareOrFullJid options:(NSDictionary *)options
{
	if (aNode == nil) return nil;
	
	// In-case aNode is mutable
	NSString *node = [aNode copy];
	
	// We default to using the full JID
	NSString *jidStr = myBareOrFullJid ? [myBareOrFullJid full] : [xmppStream.myJID full];
	
	// Generate uuid and add to dict
	NSString *uuid = [xmppStream generateUUID];
	dispatch_async(moduleQueue, ^{
		[subscribeDict setObject:node forKey:uuid];
	});
	
	// Example from XEP-0060 section 6.1.1:
	// 
	// <iq type='set' from='francisco@denmark.lit/barracks' to='pubsub.shakespeare.lit' id='sub1'>
	//   <pubsub xmlns='http://jabber.org/protocol/pubsub'>
	//     <subscribe node='princely_musings' jid='francisco@denmark.lit'/>
	//   </pubsub>
	// </iq>
	
	NSXMLElement *subscribe = [NSXMLElement elementWithName:@"subscribe"];
	[subscribe addAttributeWithName:@"node" stringValue:node];
	[subscribe addAttributeWithName:@"jid" stringValue:jidStr];
	
	NSXMLElement *pubsub = [NSXMLElement elementWithName:@"pubsub" xmlns:XMLNS_PUBSUB];
	[pubsub addChild:subscribe];
	
	if (options)
	{
		// Example from XEP-0060 section 6.3.7:
		// 
		// <options>
		//   <x xmlns='jabber:x:data' type='submit'>
		//     <field var='FORM_TYPE' type='hidden'>
		//       <value>http://jabber.org/protocol/pubsub#subscribe_options</value>
		//     </field>
		//     <field var='pubsub#deliver'><value>1</value></field>
		//     <field var='pubsub#digest'><value>0</value></field>
		//     <field var='pubsub#include_body'><value>false</value></field>
		//     <field var='pubsub#show-values'>
		//       <value>chat</value>
		//       <value>online</value>
		//       <value>away</value>
		//     </field>
		//   </x>
		// </options>
		
		NSXMLElement *x = [self formForOptions:options withFromType:XMLNS_PUBSUB_SUBSCRIBE_OPTIONS];
		
		NSXMLElement *optionsStanza = [NSXMLElement elementWithName:@"options"];
		[optionsStanza addChild:x];
		
		[pubsub addChild:optionsStanza];
	}
	
	XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:serviceJID elementID:uuid];
	[iq addChild:pubsub];
	
	[xmppStream sendElement:iq];
	return uuid;
}

- (NSString *)unsubscribeFromNode:(NSString *)node
{
	return [self unsubscribeFromNode:node withJID:nil subid:nil];
}

- (NSString *)unsubscribeFromNode:(NSString *)node withJID:(XMPPJID *)myBareOrFullJid
{
	return [self unsubscribeFromNode:node withJID:myBareOrFullJid subid:nil];
}

- (NSString *)unsubscribeFromNode:(NSString *)aNode withJID:(XMPPJID *)myBareOrFullJid subid:(NSString *)subid
{
	if (aNode == nil) return nil;
	
	// In-case aNode is mutable
	NSString *node = [aNode copy];
	
	// We default to using the full JID
	NSString *jidStr = myBareOrFullJid ? [myBareOrFullJid full] : [xmppStream.myJID full];
	
	// Generate uuid and add to dict
	NSString *uuid = [xmppStream generateUUID];
	dispatch_async(moduleQueue, ^{
		[unsubscribeDict setObject:node forKey:uuid];
	});
	
	// Example from XEP-0060 section 6.2.1:
	// 
	// <iq type='set' from='francisco@denmark.lit/barracks' to='pubsub.shakespeare.lit' id='unsub1'>
	//   <pubsub xmlns='http://jabber.org/protocol/pubsub'>
	//     <unsubscribe node='princely_musings' jid='francisco@denmark.lit'/>
	//   </pubsub>
	// </iq>
	
	NSXMLElement *unsubscribe = [NSXMLElement elementWithName:@"unsubscribe"];
	[unsubscribe addAttributeWithName:@"node" stringValue:node];
	[unsubscribe addAttributeWithName:@"jid" stringValue:jidStr];
    if (subid)
        [unsubscribe addAttributeWithName:@"subid" stringValue:subid];
	
	NSXMLElement *pubsub = [NSXMLElement elementWithName:@"pubsub" xmlns:XMLNS_PUBSUB];
	[pubsub addChild:unsubscribe];
	
	XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:serviceJID elementID:uuid];
	[iq addChild:pubsub];

	[xmppStream sendElement:iq];
	return uuid;
}

- (NSString *)retrieveSubscriptions
{
	return [self retrieveSubscriptionsForNode:nil];
}

- (NSString *)retrieveSubscriptionsForNode:(NSString *)aNode
{
	// Parameter aNode is optional
	
	// In-case aNode is mutable
	NSString *node = [aNode copy];
	
	// Generate uuid and add to dict
	NSString *uuid = [xmppStream generateUUID];
	dispatch_async(moduleQueue, ^{
		if (node)
			[retrieveDict setObject:node forKey:uuid];
		else
			[retrieveDict setObject:[NSNull null] forKey:uuid];
	});
	
	// Get subscriptions for all nodes:
	//
	// <iq type='get' from='francisco@denmark.lit/barracks' to='pubsub.shakespeare.lit' id='subscriptions1'>
	//   <pubsub xmlns='http://jabber.org/protocol/pubsub'>
	//     <subscriptions/>
	//   </pubsub>
	// </iq>
	//
	//
	// Get subscriptions for a specific node:
	//
	// <iq type='get' from='francisco@denmark.lit/barracks' to='pubsub.shakespeare.lit' id='subscriptions1'>
	//   <pubsub xmlns='http://jabber.org/protocol/pubsub'>
	//     <subscriptions node='princely_musings'/>
	//   </pubsub>
	// </iq>
	
	NSXMLElement *subscriptions = [NSXMLElement elementWithName:@"subscriptions"];
	if (node) {
		[subscriptions addAttributeWithName:@"node" stringValue:node];
	}
	
	NSXMLElement *pubsub = [NSXMLElement elementWithName:@"pubsub" xmlns:XMLNS_PUBSUB];
	[pubsub addChild:subscriptions];
	
	XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:serviceJID elementID:uuid];
	[iq addChild:pubsub];

	[xmppStream sendElement:iq];
	return uuid;
}

- (NSString *)configureSubscriptionToNode:(NSString *)aNode
                                  withJID:(XMPPJID *)myBareOrFullJid
                                    subid:(NSString *)subid
                                  options:(NSDictionary *)options
{
	if (aNode == nil) return nil;
	
	// In-case aNode is mutable
	NSString *node = [aNode copy];
	
	// We default to using the full JID
	NSString *jidStr = myBareOrFullJid ? [myBareOrFullJid full] : [xmppStream.myJID full];
	
	// Generate uuid and add to dict
	NSString *uuid = [xmppStream generateUUID];
	dispatch_async(moduleQueue, ^{
		[configSubDict setObject:node forKey:uuid];
	});
	
	// Example from XEP-0060 section 6.3.5:
	//
	// <iq type='set' from='francisco@denmark.lit/barracks' to='pubsub.shakespeare.lit' id='options2'>
	//   <pubsub xmlns='http://jabber.org/protocol/pubsub'>
	//     <options node='princely_musings' jid='francisco@denmark.lit'>
	//       <x xmlns='jabber:x:data' type='submit'>
	//         <field var='FORM_TYPE' type='hidden'>
	//           <value>http://jabber.org/protocol/pubsub#subscribe_options</value>
	//         </field>
	//         <field var='pubsub#deliver'><value>1</value></field>
	//         <field var='pubsub#digest'><value>0</value></field>
	//         <field var='pubsub#include_body'><value>false</value></field>
	//         <field var='pubsub#show-values'>
	//           <value>chat</value>
	//           <value>online</value>
	//           <value>away</value>
	//         </field>
	//       </x>
	//     </options>
	//   </pubsub>
	// </iq>
	
	NSXMLElement *optionsStanza = [NSXMLElement elementWithName:@"options"];
	[optionsStanza addAttributeWithName:@"node" stringValue:node];
	[optionsStanza addAttributeWithName:@"jid" stringValue:jidStr];
	if (subid) {
		[optionsStanza addAttributeWithName:@"subid" stringValue:subid];
	}
	if (options) {
		NSXMLElement *x = [self formForOptions:options withFromType:XMLNS_PUBSUB_NODE_CONFIG];
		[optionsStanza addChild:x];
	}
	
	NSXMLElement *pubsub = [NSXMLElement elementWithName:@"pubsub" xmlns:XMLNS_PUBSUB_OWNER];
	[pubsub addChild:optionsStanza];
	
	XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:serviceJID elementID:uuid];
	[iq addChild:pubsub];
	
	[xmppStream sendElement:iq];
	return uuid;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Node Admin
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)createNode:(NSString *)node
{
	return [self createNode:node withOptions:nil];
}

- (NSString *)createNode:(NSString *)aNode withOptions:(NSDictionary *)options
{
	if (aNode == nil) return nil;
	
	// In-case aNode is mutable
	NSString *node = [aNode copy];
	
	// Generate uuid and add to dict
	NSString *uuid = [xmppStream generateUUID];
	dispatch_async(moduleQueue, ^{
		[createDict setObject:node forKey:uuid];
	});
	
	// <iq type='set' from='hamlet@denmark.lit/elsinore' to='pubsub.shakespeare.lit' id='create1'>
	//   <pubsub xmlns='http://jabber.org/protocol/pubsub'>
	//     <create node='princely_musings'/>
	//     <configure>
	//       <x xmlns='jabber:x:data' type='submit'>
	//         <field var='FORM_TYPE' type='hidden'>
	//           <value>http://jabber.org/protocol/pubsub#node_config</value>
	//         </field>
	//         <field var='pubsub#title'><value>Princely Musings (Atom)</value></field>
	//         <field var='pubsub#deliver_notifications'><value>1</value></field>
	//         <field var='pubsub#deliver_payloads'><value>1</value></field>
	//         <field var='pubsub#persist_items'><value>1</value></field>
	//         <field var='pubsub#max_items'><value>10</value></field>
	//         ...
	//       </x>
	//     </configure>
	//   </pubsub>
	// </iq>
	
	NSXMLElement *create = [NSXMLElement elementWithName:@"create"];
	[create addAttributeWithName:@"node" stringValue:node];
	
	NSXMLElement *pubsub = [NSXMLElement elementWithName:@"pubsub" xmlns:XMLNS_PUBSUB];
	[pubsub addChild:create];

	if (options)
	{
		// Example from XEP-0060 section 8.1.3 show above
		
		NSXMLElement *x = [self formForOptions:options withFromType:XMLNS_PUBSUB_NODE_CONFIG];
		
		NSXMLElement *configure = [NSXMLElement elementWithName:@"configure"];
		[configure addChild:x];
		
		[pubsub addChild:configure];
	}

	XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:serviceJID elementID:uuid];
	[iq addChild:pubsub];

	[xmppStream sendElement:iq];
	return uuid;
}

/**
 * This method currently does not support redirection
**/
- (NSString *)deleteNode:(NSString *)aNode
{
	if (aNode == nil) return nil;
	
	// In-case aNode is mutable
	NSString *node = [aNode copy];
	
	// Generate uuid and add to dict
	NSString *uuid = [xmppStream generateUUID];
	dispatch_async(moduleQueue, ^{
		[deleteDict setObject:node forKey:uuid];
	});
	
	// Example XEP-0060 section 8.4.1:
	// 
	// <iq type='set' from='hamlet@denmark.lit/elsinore' to='pubsub.shakespeare.lit' id='delete1'>
	//   <pubsub xmlns='http://jabber.org/protocol/pubsub#owner'>
	//     <delete node='princely_musings'/>
	//   </pubsub>
	// </iq>

	NSXMLElement *delete = [NSXMLElement elementWithName:@"delete"];
	[delete addAttributeWithName:@"node" stringValue:node];
	
	NSXMLElement *pubsub = [NSXMLElement elementWithName:@"pubsub" xmlns:XMLNS_PUBSUB_OWNER];
	[pubsub addChild:delete];
	
	XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:serviceJID elementID:uuid];
	[iq addChild:pubsub];

	[xmppStream sendElement:iq];
	return uuid;
}

- (NSString *)configureNode:(NSString *)node
{
	return [self configureNode:node withOptions:nil];
}

- (NSString *)configureNode:(NSString *)aNode withOptions:(NSDictionary *)options
{
	if (aNode == nil) return nil;
	
	// In-case aNode is mutable
	NSString *node = [aNode copy];
	
	// Generate uuid and add to dict
	NSString *uuid = [xmppStream generateUUID];
	dispatch_async(moduleQueue, ^{
		[configNodeDict setObject:node forKey:uuid];
	});
	
	// <iq type='get' from='hamlet@denmark.lit/elsinore' to='pubsub.shakespeare.lit' id='config1'>
	//   <pubsub xmlns='http://jabber.org/protocol/pubsub#owner'>
	//     <configure node='princely_musings'/>
	//   </pubsub>
	// </iq>
	
	NSXMLElement *configure  = [NSXMLElement elementWithName:@"configure"];
	[configure addAttributeWithName:@"node" stringValue:node];
	if (options)
	{
		NSXMLElement *x = [self formForOptions:options withFromType:XMLNS_PUBSUB_NODE_CONFIG];
		[configure addChild:x];
	}
	
	NSXMLElement *pubsub = [NSXMLElement elementWithName:@"pubsub" xmlns:XMLNS_PUBSUB_OWNER];
	[pubsub addChild:configure];
	
	XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:serviceJID elementID:uuid];
	[iq addChild:pubsub];

	[xmppStream sendElement:iq];
	return uuid;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Publication methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)publishToNode:(NSString *)node entry:(NSXMLElement *)entry
{
	return [self publishToNode:node entry:entry withItemID:nil options:nil];
}

- (NSString *)publishToNode:(NSString *)node entry:(NSXMLElement *)entry withItemID:(NSString *)itemId
{
	return [self publishToNode:node entry:entry withItemID:itemId options:nil];
}

- (NSString *)publishToNode:(NSString *)node
                      entry:(NSXMLElement *)entry
                 withItemID:(NSString *)itemId
                    options:(NSDictionary *)options
{
	if (node == nil) return nil;
	if (entry == nil) return nil;
	
	// <iq type='set' from='hamlet@denmark.lit/blogbot' to='pubsub.shakespeare.lit' id='publish1'>
	//   <pubsub xmlns='http://jabber.org/protocol/pubsub'>
	//     <publish node='princely_musings'>
	//       <item id='bnd81g37d61f49fgn581'>
	//         Some content
	//       </item>
	//     </publish>
	//     <publish-options>
	//       [... FORM ... ]
	//     </publish-options>
	//   </pubsub>
	// </iq>
    
	NSString *uuid = [xmppStream generateUUID];

	NSXMLElement *item = [NSXMLElement elementWithName:@"item"];
	if (itemId)
		[item addAttributeWithName:@"id" stringValue:itemId];
	[item addChild:entry];
	
	NSXMLElement *publish = [NSXMLElement elementWithName:@"publish"];
	[publish addAttributeWithName:@"node" stringValue:node];
	[publish addChild:item];
	
	NSXMLElement *pubsub = [NSXMLElement elementWithName:@"pubsub" xmlns:XMLNS_PUBSUB];
	[pubsub addChild:publish];
	
	if (options)
	{
		// Example from XEP-0060 section 7.1.5:
		//
		// <publish-options>
		//   <x xmlns='jabber:x:data' type='submit'>
		//     <field var='FORM_TYPE' type='hidden'>
		//       <value>http://jabber.org/protocol/pubsub#publish-options</value>
		//     </field>
		//     <field var='pubsub#access_model'>
		//       <value>presence</value>
		//     </field>
		//   </x>
		// </publish-options>
		
		NSXMLElement *x = [self formForOptions:options withFromType:XMLNS_PUBSUB_PUBLISH_OPTIONS];
		
		NSXMLElement *publishOptions = [NSXMLElement elementWithName:@"publish-options"];
		[publishOptions addChild:x];
		
		[pubsub addChild:publishOptions];
	}
	
	XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:serviceJID elementID:uuid];
	[iq addChild:pubsub];
	
	[xmppStream sendElement:iq];
	
	dispatch_async(moduleQueue, ^{
		[publishDict setObject:node forKey:uuid];
	});
	return uuid;
}

@end
