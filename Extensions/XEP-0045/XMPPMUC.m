#import "XMPPMUC.h"
#import "XMPPFramework.h"
#import "XMPPLogging.h"
#import "XMPPIDTracker.h"

#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_VERBOSE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

NSString *const XMPPDiscoverItemsNamespace = @"http://jabber.org/protocol/disco#items";
NSString *const XMPPMUCErrorDomain = @"XMPPMUCErrorDomain";

@interface XMPPMUC()
{
  BOOL hasRequestedServices;
  BOOL hasRequestedRooms;
}

@end

@implementation XMPPMUC

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	if ((self = [super initWithDispatchQueue:queue])) {
		rooms = [[NSMutableSet alloc] init];
	}
	return self;
}

- (BOOL)activate:(XMPPStream *)aXmppStream
{
	if ([super activate:aXmppStream])
	{
    XMPPLogVerbose(@"%@: Activated", THIS_FILE);

    xmppIDTracker = [[XMPPIDTracker alloc] initWithStream:xmppStream
                                            dispatchQueue:moduleQueue];

#ifdef _XMPP_CAPABILITIES_H
		[xmppStream autoAddDelegate:self
		              delegateQueue:moduleQueue
		           toModulesOfClass:[XMPPCapabilities class]];
#endif
		return YES;
	}
	
	return NO;
}

- (void)deactivate
{
  XMPPLogTrace();

  dispatch_block_t block = ^{ @autoreleasepool {
    [xmppIDTracker removeAllIDs];
    xmppIDTracker = nil;
  }};

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_sync(moduleQueue, block);

#ifdef _XMPP_CAPABILITIES_H
	[xmppStream removeAutoDelegate:self delegateQueue:moduleQueue fromModulesOfClass:[XMPPCapabilities class]];
#endif
	
	[super deactivate];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Public API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)isMUCRoomElement:(XMPPElement *)element
{
	XMPPJID *bareFrom = [[element from] bareJID];
	if (bareFrom == nil)
	{
		return NO;
	}
	
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		result = [rooms containsObject:bareFrom];
		
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

- (BOOL)isMUCRoomPresence:(XMPPPresence *)presence
{
	return [self isMUCRoomElement:presence];
}

- (BOOL)isMUCRoomMessage:(XMPPMessage *)message
{
	return [self isMUCRoomElement:message];
}

/**
* This method provides functionality of XEP-0045 6.1 Discovering a MUC Service.
*
* @link {http://xmpp.org/extensions/xep-0045.html#disco-service}
*
* Example 1. Entity Queries Server for Associated Services
*
* <iq from='hag66@shakespeare.lit/pda'
*       id='h7ns81g'
*       to='shakespeare.lit'
*     type='get'>
*   <query xmlns='http://jabber.org/protocol/disco#items'/>
* </iq>
*/
- (void)discoverServices
{
  // This is a public method, so it may be invoked on any thread/queue.

  dispatch_block_t block = ^{ @autoreleasepool {
    if (hasRequestedServices) return; // We've already requested services

    NSString *toStr = xmppStream.myJID.domain;
    NSXMLElement *query = [NSXMLElement elementWithName:@"query"
                                                  xmlns:XMPPDiscoverItemsNamespace];
    XMPPIQ *iq = [XMPPIQ iqWithType:@"get"
                                 to:[XMPPJID jidWithString:toStr]
                          elementID:[xmppStream generateUUID]
                              child:query];

    [xmppIDTracker addElement:iq
                       target:self
                     selector:@selector(handleDiscoverServicesQueryIQ:withInfo:)
                      timeout:60];

    [xmppStream sendElement:iq];
    hasRequestedServices = YES;
  }};

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

/**
* This method provides functionality of XEP-0045 6.3 Discovering Rooms
*
* @link {http://xmpp.org/extensions/xep-0045.html#disco-rooms}
*
* Example 5. Entity Queries Chat Service for Rooms
*
* <iq from='hag66@shakespeare.lit/pda'
*       id='zb8q41f4'
*       to='chat.shakespeare.lit'
*     type='get'>
*   <query xmlns='http://jabber.org/protocol/disco#items'/>
* </iq>
*/
- (BOOL)discoverRoomsForServiceNamed:(NSString *)serviceName
{
  // This is a public method, so it may be invoked on any thread/queue.

  if (serviceName.length < 2)
    return NO;

  dispatch_block_t block = ^{ @autoreleasepool {
    if (hasRequestedRooms) return; // We've already requested rooms

    NSXMLElement *query = [NSXMLElement elementWithName:@"query"
                                                  xmlns:XMPPDiscoverItemsNamespace];
    XMPPIQ *iq = [XMPPIQ iqWithType:@"get"
                                 to:[XMPPJID jidWithString:serviceName]
                          elementID:[xmppStream generateUUID]
                              child:query];

    [xmppIDTracker addElement:iq
                       target:self
                     selector:@selector(handleDiscoverRoomsQueryIQ:withInfo:)
                      timeout:60];

    [xmppStream sendElement:iq];
    hasRequestedRooms = YES;
  }};

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);

  return YES;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPIDTracker
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
* This method handles the response received (or not received) after calling discoverServices.
*/
- (void)handleDiscoverServicesQueryIQ:(XMPPIQ *)iq withInfo:(XMPPBasicTrackingInfo *)info
{
  dispatch_block_t block = ^{ @autoreleasepool {
    NSXMLElement *errorElem = [iq elementForName:@"error"];

    if (errorElem) {
      NSString *errMsg = [errorElem.children componentsJoinedByString:@", "];
      NSDictionary *dict = @{NSLocalizedDescriptionKey : errMsg};
      NSError *error = [NSError errorWithDomain:XMPPMUCErrorDomain
                                           code:[errorElem attributeIntegerValueForName:@"code"
                                                                       withDefaultValue:0]
                                       userInfo:dict];

      [multicastDelegate xmppMUCFailedToDiscoverServices:self
                                               withError:error];
      return;
    }

    NSXMLElement *query = [iq elementForName:@"query"
                                       xmlns:XMPPDiscoverItemsNamespace];

    NSArray *items = [query elementsForName:@"item"];
    [multicastDelegate xmppMUC:self didDiscoverServices:items];
    hasRequestedServices = NO; // Set this back to NO to allow for future requests
  }};

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

/**
* This method handles the response received (or not received) after calling discoverRoomsForServiceNamed:.
*/
- (void)handleDiscoverRoomsQueryIQ:(XMPPIQ *)iq withInfo:(XMPPBasicTrackingInfo *)info
{
  dispatch_block_t block = ^{ @autoreleasepool {
    NSXMLElement *errorElem = [iq elementForName:@"error"];
    NSString *serviceName = [iq attributeStringValueForName:@"from" withDefaultValue:@""];

    if (errorElem) {
      NSString *errMsg = [errorElem.children componentsJoinedByString:@", "];
      NSDictionary *dict = @{NSLocalizedDescriptionKey : errMsg};
      NSError *error = [NSError errorWithDomain:XMPPMUCErrorDomain
                                           code:[errorElem attributeIntegerValueForName:@"code"
                                                                       withDefaultValue:0]
                                       userInfo:dict];
      [multicastDelegate     xmppMUC:self
failedToDiscoverRoomsForServiceNamed:serviceName
                           withError:error];
      return;
    }

    NSXMLElement *query = [iq elementForName:@"query"
                                       xmlns:XMPPDiscoverItemsNamespace];

    NSArray *items = [query elementsForName:@"item"];
    [multicastDelegate xmppMUC:self
              didDiscoverRooms:items
               forServiceNamed:serviceName];
    hasRequestedRooms = NO; // Set this back to NO to allow for future requests
  }};

  if (dispatch_get_specific(moduleQueueTag))
    block();
  else
    dispatch_async(moduleQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStream:(XMPPStream *)sender didRegisterModule:(id)module
{
	if ([module isKindOfClass:[XMPPRoom class]])
	{
		XMPPJID *roomJID = [(XMPPRoom *)module roomJID];
		
		[rooms addObject:roomJID];
	}
}

- (void)xmppStream:(XMPPStream *)sender willUnregisterModule:(id)module
{
	if ([module isKindOfClass:[XMPPRoom class]])
	{
		XMPPJID *roomJID = [(XMPPRoom *)module roomJID];
		
		// It's common for the room to get deactivated and deallocated before
		// we've received the goodbye presence from the server.
		// So we're going to postpone for a bit removing the roomJID from the list.
		// This way the isMUCRoomElement will still remain accurate
		// for presence elements that may arrive momentarily.
		
		double delayInSeconds = 30.0;
		dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
		dispatch_after(popTime, moduleQueue, ^{ @autoreleasepool {
			
			[rooms removeObject:roomJID];
		}});
	}
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	// Examples from XEP-0045:
	// 
	// 
	// Example 124. Room Sends Invitation to New Member:
	// 
	// <message from='darkcave@chat.shakespeare.lit' to='hecate@shakespeare.lit'>
	//   <x xmlns='http://jabber.org/protocol/muc#user'>
	//     <invite from='bard@shakespeare.lit'/>
	//     <password>cauldronburn</password>
	//   </x>
	// </message>
	// 
	// 
	// Example 125. Service Returns Error on Attempt by Mere Member to Invite Others to a Members-Only Room
	// 
	// <message from='darkcave@chat.shakespeare.lit' to='hag66@shakespeare.lit/pda' type='error'>
	//   <x xmlns='http://jabber.org/protocol/muc#user'>
	//     <invite to='hecate@shakespeare.lit'>
	//       <reason>
	//         Hey Hecate, this is the place for all good witches!
	//       </reason>
	//     </invite>
	//   </x>
	//   <error type='auth'>
	//     <forbidden xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
	//   </error>
	// </message>
	// 
	// 
	// Example 50. Room Informs Invitor that Invitation Was Declined
	// 
	// <message from='darkcave@chat.shakespeare.lit' to='crone1@shakespeare.lit/desktop'>
	//   <x xmlns='http://jabber.org/protocol/muc#user'>
	//     <decline from='hecate@shakespeare.lit'>
	//       <reason>
	//         Sorry, I'm too busy right now.
	//       </reason>
	//     </decline>
	//   </x>
	// </message>
	// 
	// 
	// Examples from XEP-0249:
	// 
	// 
	// Example 1. A direct invitation
	// 
	// <message from='crone1@shakespeare.lit/desktop' to='hecate@shakespeare.lit'>
	//   <x xmlns='jabber:x:conference'
	//      jid='darkcave@macbeth.shakespeare.lit'
	//      password='cauldronburn'
	//      reason='Hey Hecate, this is the place for all good witches!'/>
	// </message>
	
	NSXMLElement * x = [message elementForName:@"x" xmlns:XMPPMUCUserNamespace];
	NSXMLElement * invite  = [x elementForName:@"invite"];
	NSXMLElement * decline = [x elementForName:@"decline"];
	
	NSXMLElement * directInvite = [message elementForName:@"x" xmlns:@"jabber:x:conference"];
    
    XMPPJID * roomJID = [message from];
	
	if (invite || directInvite)
	{
		[multicastDelegate xmppMUC:self roomJID:roomJID didReceiveInvitation:message];
	}
	else if (decline)
	{
		[multicastDelegate xmppMUC:self roomJID:roomJID didReceiveInvitationDecline:message];
	}
}

- (BOOL)xmppStream:(XMPPStream *)stream didReceiveIQ:(XMPPIQ *)iq
{
  NSString *type = [iq type];

  if ([type isEqualToString:@"result"] || [type isEqualToString:@"error"]) {
    return [xmppIDTracker invokeForElement:iq withObject:iq];
  }

  return NO;
}


#ifdef _XMPP_CAPABILITIES_H
/**
 * If an XMPPCapabilites instance is used we want to advertise our support for MUC.
**/
- (void)xmppCapabilities:(XMPPCapabilities *)sender collectingMyCapabilities:(NSXMLElement *)query
{
	// This method is invoked on our moduleQueue.
	
	// <query xmlns="http://jabber.org/protocol/disco#info">
	//   ...
	//   <feature var='http://jabber.org/protocol/muc'/>
	//   ...
	// </query>
	
	NSXMLElement *feature = [NSXMLElement elementWithName:@"feature"];
	[feature addAttributeWithName:@"var" stringValue:@"http://jabber.org/protocol/muc"];
	
	[query addChild:feature];
}
#endif

@end
