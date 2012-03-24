//
//  XMPPPubSub.m
//
//  Created by Duncan Robertson [duncan@whomwah.com]
//

#import "XMPPPubSub.h"
#import "XMPPFramework.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#define NS_PUBSUB          @"http://jabber.org/protocol/pubsub"
#define NS_PUBSUB_EVENT    @"http://jabber.org/protocol/pubsub#event"
#define NS_PUBSUB_CONFIG   @"http://jabber.org/protocol/pubsub#node_config"
#define NS_PUBSUB_OWNER    @"http://jabber.org/protocol/pubsub#owner"
#define NS_DISCO_ITEMS     @"http://jabber.org/protocol/disco#items"


@implementation XMPPPubSub

@synthesize serviceJID;

- (id)init
{
	return [self initWithServiceJID:nil dispatchQueue:NULL];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	return [self initWithServiceJID:nil dispatchQueue:NULL];
}

- (id)initWithServiceJID:(XMPPJID *)aServiceJID
{
	return [self initWithServiceJID:aServiceJID dispatchQueue:NULL];
}

- (id)initWithServiceJID:(XMPPJID *)aServiceJID dispatchQueue:(dispatch_queue_t)queue
{
	NSParameterAssert(aServiceJID != nil);
	
	if ((self = [super initWithDispatchQueue:queue]))
	{
		serviceJID = [aServiceJID copy];
	}
	return self;
}

- (BOOL)activate:(XMPPStream *)aXmppStream
{
	if ([super activate:aXmppStream])
	{
	#ifdef _XMPP_CAPABILITIES_H
		[xmppStream autoAddDelegate:self delegateQueue:moduleQueue toModulesOfClass:[XMPPCapabilities class]];
	#endif
		
		return YES;
	}
	
	return NO;
}

- (void)deactivate
{
#ifdef _XMPP_CAPABILITIES_H
	[xmppStream removeAutoDelegate:self delegateQueue:moduleQueue fromModulesOfClass:[XMPPCapabilities class]];
#endif
	
	[super deactivate];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Delegate method to receive incoming IQ stanzas.
**/
- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	if ([iq isResultIQ])
	{
		NSXMLElement *pubsub = [iq elementForName:@"pubsub" xmlns:NS_PUBSUB];
		if (pubsub)
		{
			// <iq from="pubsub.host.com" to="user@host.com/rsrc" id="ABC123:subscribenode" type="result">
			//   <pubsub xmlns="http://jabber.org/protocol/pubsub">
			//     <subscription jid="tv@xmpp.local" subscription="subscribed" subid="DEF456"/>
			//   </pubsub>
			// </iq>
			
			NSXMLElement *subscription = [pubsub elementForName:@"subscription"];
			if (subscription)
			{
				NSString *value = [subscription attributeStringValueForName:@"subscription"];
				if (value && ([value caseInsensitiveCompare:@"subscribed"] == NSOrderedSame))
				{
					[multicastDelegate xmppPubSub:self didSubscribe:iq];
					return YES;
				}
			}
		} else {
            //Check if it was a publish
            NSString *elementID = [iq attributeStringValueForName:@"id"];
            if (elementID) {
                NSArray * elementIDComp = [elementID componentsSeparatedByString:@":"];
                if (elementIDComp > 0) {
                    NSString * opType = [elementIDComp objectAtIndex:1];
                    
                    if ([opType isEqualToString:@"publish_node"]) {
                        [multicastDelegate xmppPubSub:self didPublish:iq];
                        return YES;
                        
                    } else if([opType isEqualToString:@"unsubscribe_node"]) {
                        [multicastDelegate xmppPubSub:self didUnsubscribe:iq];
                        return YES;
                    }
                }
            }
        }
		
		[multicastDelegate xmppPubSub:self didReceiveResult:iq];
		return YES;
	}
	else if ([iq isErrorIQ])
	{
		[multicastDelegate xmppPubSub:self didReceiveError:iq];
		return YES;
	}
	
	return NO;
}

/**
 * Delegate method to receive incoming message stanzas.
**/
- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	// <message from='pubsub.foo.co.uk' to='admin@foo.co.uk'>
	//   <event xmlns='http://jabber.org/protocol/pubsub#event'>
	//     <items node='/pubsub.foo'>
	//       <item id='5036AA52A152B'>
	//         <text id='724427814855'>
	//           Huw Stephens sits in for Greg James and David Garrido takes a look at the sporting week
	//         </text>
	//       </item>
	//     </items>
	//   </event>
	// </message>
	
	NSXMLElement *event = [message elementForName:@"event" xmlns:NS_PUBSUB_EVENT];
	if (event)
	{
		[multicastDelegate xmppPubSub:self didReceiveMessage:message];
	}
}

#ifdef _XMPP_CAPABILITIES_H
/**
 * If an XMPPCapabilites instance is used we want to advertise our support for pubsub support.
**/
- (void)xmppCapabilities:(XMPPCapabilities *)sender collectingMyCapabilities:(NSXMLElement *)query
{
	// <query xmlns="http://jabber.org/protocol/disco#info">
	//   ...
	//   <identity category='pubsub' type='service'/>
	//   <feature var='http://jabber.org/protocol/pubsub' />
	//   ...
	// </query>
	
	NSXMLElement *identity = [NSXMLElement elementWithName:@"identity"];
	[identity addAttributeWithName:@"category" stringValue:@"pubsub"];
	[identity addAttributeWithName:@"type" stringValue:@"service"];
	[query addChild:identity];
	
	NSXMLElement *feature = [NSXMLElement elementWithName:@"feature"];
	[feature addAttributeWithName:@"var" stringValue:NS_PUBSUB];
	[query addChild:feature];
}
#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Subscription Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)subscribeToNode:(NSString *)node withOptions:(NSDictionary *)options
{
	// <iq type='set' from='francisco@denmark.lit/barracks' to='pubsub.shakespeare.lit' id='sub1'>
	//   <pubsub xmlns='http://jabber.org/protocol/pubsub'>
	//     <subscribe node='princely_musings' jid='francisco@denmark.lit'/>
	//   </pubsub>
	// </iq>

	NSString *sid = [NSString stringWithFormat:@"%@:subscribe_node", xmppStream.generateUUID];

	XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:serviceJID elementID:sid];
	NSXMLElement *ps = [NSXMLElement elementWithName:@"pubsub" xmlns:NS_PUBSUB];
	NSXMLElement *subscribe = [NSXMLElement elementWithName:@"subscribe"];
	[subscribe addAttributeWithName:@"node" stringValue:node];
	[subscribe addAttributeWithName:@"jid" stringValue:[xmppStream.myJID full]];

	[ps addChild:subscribe];
	[iq addChild:ps];

	[xmppStream sendElement:iq];

	return sid;
}

- (NSString *)unsubscribeFromNode:(NSString*)node {
    return [self unsubscribeFromNode:node withSubid:nil];
}

- (NSString *)unsubscribeFromNode:(NSString *)node withSubid:(NSString *)subid 
{
	// <iq type='set' from='francisco@denmark.lit/barracks' to='pubsub.shakespeare.lit' id='unsub1'>
	//   <pubsub xmlns='http://jabber.org/protocol/pubsub'>
	//     <unsubscribe node='princely_musings' jid='francisco@denmark.lit'/>
	//   </pubsub>
	// </iq>

	NSString *sid = [NSString stringWithFormat:@"%@:unsubscribe_node", xmppStream.generateUUID]; 

	XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:serviceJID elementID:sid];
	NSXMLElement *ps = [NSXMLElement elementWithName:@"pubsub" xmlns:NS_PUBSUB];
	NSXMLElement *subscribe = [NSXMLElement elementWithName:@"unsubscribe"];
	[subscribe addAttributeWithName:@"node" stringValue:node];
	[subscribe addAttributeWithName:@"jid" stringValue:[xmppStream.myJID bare]];
    
    if (subid) {
        [subscribe addAttributeWithName:@"subid" stringValue:subid];
    }

	// join them all together
	[ps addChild:subscribe];
	[iq addChild:ps];

	[xmppStream sendElement:iq];

	return sid;
}

- (NSString *)getSubscriptions {
    return [self getSubscriptionsForNode:nil];
}

- (NSString *)getSubscriptionsForNode:(NSString *)node {
    //<iq type='get' from='francisco@denmark.lit/barracks' to='pubsub.shakespeare.lit' id='subscriptions1'>
    //  <pubsub xmlns='http://jabber.org/protocol/pubsub'>
    //      <subscriptions/>
    //  </pubsub>
    //</iq>
    
	NSString *sid = [NSString stringWithFormat:@"%@:subscriptions_for_node", xmppStream.generateUUID]; 
    
	XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:serviceJID elementID:sid];
	NSXMLElement *ps = [NSXMLElement elementWithName:@"pubsub" xmlns:NS_PUBSUB];
	NSXMLElement *subscriptions = [NSXMLElement elementWithName:@"subscriptions"];
    
    if (node) {
        [subscriptions addAttributeWithName:@"node" stringValue:node];
    }
    
	// join them all together
	[ps addChild:subscriptions];
	[iq addChild:ps];
    
	[xmppStream sendElement:iq];
    
	return sid;
    
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Node Admin
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)createNode:(NSString *)node withOptions:(NSDictionary *)options
{
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

	NSString *sid = [NSString stringWithFormat:@"%@:create_node", xmppStream.generateUUID];

	XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:serviceJID elementID:sid];
	NSXMLElement *ps = [NSXMLElement elementWithName:@"pubsub" xmlns:NS_PUBSUB];
	NSXMLElement *create = [NSXMLElement elementWithName:@"create"];
	[create addAttributeWithName:@"node" stringValue:node];

	if (options != nil && [options count] > 0)
	{

		NSXMLElement *config = [NSXMLElement elementWithName:@"configure"];
		NSXMLElement *x = [NSXMLElement elementWithName:@"x" xmlns:@"jabber:x:data"];
		[x addAttributeWithName:@"type" stringValue:@"submit"];

		NSXMLElement *field = [NSXMLElement elementWithName:@"field"];
		[field addAttributeWithName:@"var" stringValue:@"FORM_TYPE"];
		[field addAttributeWithName:@"type" stringValue:@"hidden"];
		NSXMLElement *value = [NSXMLElement elementWithName:@"value"];
		[value setStringValue:NS_PUBSUB_CONFIG];
		[field addChild:value];
		[x addChild:field];

		NSXMLElement *f;
		NSXMLElement *v;
		for (NSString *item in options)
		{
			f = [NSXMLElement elementWithName:@"field"];
			[f addAttributeWithName:@"var"
			            stringValue:[NSString stringWithFormat:@"pubsub#%@", [options valueForKey:item]]];
			v = [NSXMLElement elementWithName:@"value"];
			[v setStringValue:item];
			[f addChild:v];
			[x addChild:f];
		}

		[config addChild:x];
		[ps addChild:config];

	}

	[ps addChild:create];
	[iq addChild:ps];

	[xmppStream sendElement:iq];

	return sid;
}

/**
 * This method currently does not support redirection
**/
- (NSString*)deleteNode:(NSString*)node
{
	// <iq type='set' from='hamlet@denmark.lit/elsinore' to='pubsub.shakespeare.lit' id='delete1'>
	//   <pubsub xmlns='http://jabber.org/protocol/pubsub#owner'>
	//     <delete node='princely_musings'>
	//       <redirect uri='xmpp:hamlet@denmark.lit?;node=blog'/>
	//     </delete>
	//   </pubsub>
	// </iq>

	NSString *sid = [NSString stringWithFormat:@"%@:delete_node", xmppStream.generateUUID];
	XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:serviceJID elementID:sid];
	NSXMLElement *ps = [NSXMLElement elementWithName:@"pubsub" xmlns:NS_PUBSUB_OWNER];

	NSXMLElement *delete = [NSXMLElement elementWithName:@"delete"];
	[delete addAttributeWithName:@"node" stringValue:node];

	[ps addChild:delete];
	[iq addChild:ps];

	[xmppStream sendElement:iq];

	return sid;
}


- (NSString*)discoverItemsForNode:(NSString*)node
{
	// <iq type='get' from='francisco@denmark.lit/barracks' to='pubsub.shakespeare.lit' id='nodes2'>
	//   <query xmlns='http://jabber.org/protocol/disco#items' node='blogs'/>
	// </iq>

	NSString *sid = [NSString stringWithFormat:@"%@:items_for_node", xmppStream.generateUUID];
	XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:serviceJID elementID:sid];
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:NS_DISCO_ITEMS];

	if (node != nil) {
		[query addAttributeWithName:@"node" stringValue:node];  
	}

	[iq addChild:query];

	[xmppStream sendElement:iq];

	return sid;
}

- (NSString*)allItemsForNode:(NSString*)node
{
	//<iq type='get' from='francisco@denmark.lit/barracks' to='pubsub.shakespeare.lit' id='items1'>
    //  <pubsub xmlns='http://jabber.org/protocol/pubsub'>
    //      <items node='princely_musings'/>
    //  </pubsub>
    //</iq>
    
	NSString *sid = [NSString stringWithFormat:@"%@:allitems_for_node", xmppStream.generateUUID];
	XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:serviceJID elementID:sid];
    NSXMLElement *pubsub = [NSXMLElement elementWithName:@"pubsub" xmlns:NS_PUBSUB];
    NSXMLElement *items = [NSXMLElement elementWithName:@"items"];
    
    if (node != nil) {
        [items addAttributeWithName:@"node" stringValue:node];
    }

    [pubsub addChild:items];
    [iq addChild:pubsub];
    
	[xmppStream sendElement:iq];
    
	return sid;
}

- (NSString*)configureNode:(NSString*)node
{
	// <iq type='get' from='hamlet@denmark.lit/elsinore' to='pubsub.shakespeare.lit' id='config1'>
	//   <pubsub xmlns='http://jabber.org/protocol/pubsub#owner'>
	//     <configure node='princely_musings'/>
	//   </pubsub>
	// </iq>

	NSString *sid = [NSString stringWithFormat:@"%@:configure_node", xmppStream.generateUUID];
	XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:serviceJID elementID:sid];
	NSXMLElement *ps = [NSXMLElement elementWithName:@"pubsub" xmlns:NS_PUBSUB_OWNER];

	NSXMLElement *conf  = [NSXMLElement elementWithName:@"configure"];
	[conf addAttributeWithName:@"node" stringValue:node];

	[ps addChild:conf];
	[iq addChild:ps];

	[xmppStream sendElement:iq];

	return sid;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - publication methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)publishToNode:(NSString *)node entry:(NSXMLElement *)entry {
    //<iq type='set' from='hamlet@denmark.lit/blogbot' to='pubsub.shakespeare.lit' id='publish1'>
    //  <pubsub xmlns='http://jabber.org/protocol/pubsub'>
    //      <publish node='princely_musings'>
    //          <item id='bnd81g37d61f49fgn581'>
    //              Some content
    //          </item>
    //      </publish>
    //  </pubsub>
    //</iq>
    
	NSString *sid = [NSString stringWithFormat:@"%@:publish_node", xmppStream.generateUUID];
    
    //create iq message
    XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:serviceJID elementID:sid];
    
    //create child nodes
    NSXMLElement * pubsub = [NSXMLElement elementWithName:@"pubsub" xmlns:NS_PUBSUB];
    
    NSXMLElement * publish = [NSXMLElement elementWithName:@"publish"];
    [publish addAttributeWithName:@"node" stringValue:node];
    
    NSXMLElement * item = [NSXMLElement elementWithName:@"item"];
    
    //create node hierarchy
    [item addChild:entry];
    [publish addChild:item];
    [pubsub addChild:publish];
    [iq addChild:pubsub];

	[xmppStream sendElement:iq];
    
	return sid;
}

@end
