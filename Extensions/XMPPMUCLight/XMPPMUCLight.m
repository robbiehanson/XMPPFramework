//
//  XMPPMUCLight.m
//  Mangosta
//
//  Created by Andres on 5/30/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

#import "XMPPMUC.h"
#import "XMPPFramework.h"
#import "XMPPLogging.h"
#import "XMPPIDTracker.h"
#import "XMPPMUCLight.h"
#import "XMPPRoomLight.h"

NSString *const XMPPMUCLightDiscoItemsNamespace = @"http://jabber.org/protocol/disco#items";
NSString *const XMPPRoomLightAffiliations = @"urn:xmpp:muclight:0#affiliations";
NSString *const XMPPMUCLightErrorDomain = @"XMPPMUCErrorDomain";
NSString *const XMPPMUCLightBlocking = @"urn:xmpp:muclight:0#blocking";

@interface XMPPMUCLight() {
	NSMutableSet *rooms;
}
@end

@implementation XMPPMUCLight

- (instancetype)init {
	return [self initWithDispatchQueue:nil];
}

- (instancetype)initWithDispatchQueue:(dispatch_queue_t)queue {
	if ((self = [super initWithDispatchQueue:queue])) {
		rooms = [[NSMutableSet alloc] init];
	}
	return self;
}


- (BOOL)activate:(XMPPStream *)aXmppStream {
	if ([super activate:aXmppStream]) {
		xmppIDTracker = [[XMPPIDTracker alloc] initWithDispatchQueue:moduleQueue];
		return YES;
	}
	
	return NO;
}

- (void)deactivate {
	dispatch_block_t block = ^{ @autoreleasepool {
		[xmppIDTracker removeAllIDs];
		xmppIDTracker = nil;
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	[super deactivate];
}

- (nonnull NSSet *)rooms{
	@synchronized(rooms) {
		return [rooms copy];
	}
}

- (BOOL)discoverRoomsForServiceNamed:(nonnull NSString *)serviceName {
	
	if (serviceName.length < 2)
		return NO;
	
	dispatch_block_t block = ^{ @autoreleasepool {

		NSXMLElement *query = [NSXMLElement elementWithName:@"query"
													  xmlns:XMPPMUCLightDiscoItemsNamespace];
		XMPPIQ *iq = [XMPPIQ iqWithType:@"get"
									 to:[XMPPJID jidWithString:serviceName]
							  elementID:[xmppStream generateUUID]
								  child:query];
		
		[xmppIDTracker addElement:iq
						   target:self
						 selector:@selector(handleDiscoverRoomsQueryIQ:withInfo:)
						  timeout:60];
		
		[xmppStream sendElement:iq];
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
	
	return YES;
}

- (void)handleDiscoverRoomsQueryIQ:(XMPPIQ *)iq withInfo:(XMPPBasicTrackingInfo *)info {
	dispatch_block_t block = ^{ @autoreleasepool {
		NSXMLElement *errorElem = [iq elementForName:@"error"];
		NSString *serviceName = [iq attributeStringValueForName:@"from" withDefaultValue:@""];
		
		if (errorElem) {
			NSString *errMsg = [errorElem.children componentsJoinedByString:@", "];
			NSInteger errorCode = [errorElem attributeIntegerValueForName:@"code" withDefaultValue:0];
			NSDictionary *dict = @{NSLocalizedDescriptionKey : errMsg};
			NSError *error = [NSError errorWithDomain:XMPPMUCLightErrorDomain
												 code:errorCode
											 userInfo:dict];
			
			[multicastDelegate xmppMUCLight:self failedToDiscoverRoomsForServiceNamed:serviceName withError:error];
			return;
		}
		
		NSXMLElement *query = [iq elementForName:@"query"
										   xmlns:XMPPMUCLightDiscoItemsNamespace];
		
		NSArray *items = [query elementsForName:@"item"];

		[multicastDelegate xmppMUCLight:self didDiscoverRooms:items forServiceNamed:serviceName];
		
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (BOOL)requestBlockingList:(nonnull NSString *)serviceName{
	if (serviceName.length < 2)
		return NO;

	// <iq from='crone1@shakespeare.lit/desktop' id='getblock1' to='muclight.shakespeare.lit' type='get'>
	//		<query xmlns='urn:xmpp:muclight:0#blocking'> </query>
	// </iq>

	dispatch_block_t block = ^{ @autoreleasepool {

		NSXMLElement *query = [NSXMLElement elementWithName:@"query"
													  xmlns:XMPPMUCLightBlocking];
		XMPPIQ *iq = [XMPPIQ iqWithType:@"get"
									 to:[XMPPJID jidWithString:serviceName]
							  elementID:[xmppStream generateUUID]
								  child:query];

		[xmppIDTracker addElement:iq
						   target:self
						 selector:@selector(handleRequestBlockingList:withInfo:)
						  timeout:60];

		[xmppStream sendElement:iq];
	}};

	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);

	return YES;
}

- (void)handleRequestBlockingList:(XMPPIQ *)iq withInfo:(XMPPBasicTrackingInfo *)info {
	NSString *serviceName = [iq attributeStringValueForName:@"from" withDefaultValue:@""];
	if ([[iq type] isEqualToString:@"result"]) {
		NSXMLElement *query = [iq elementForName:@"query"];
        NSArray *children = [query children];
        if (!children) { children = @[]; }
		[multicastDelegate xmppMUCLight:self didRequestBlockingList:children forServiceNamed:serviceName];
	}else{
		[multicastDelegate xmppMUCLight:self failedToRequestBlockingList:serviceName withError:iq];
	}
}

- (BOOL)performActionOnElements:(nonnull NSArray<NSXMLElement *> *)elements forServiceNamed:(nonnull NSString *)serviceName{
	if (serviceName.length < 2)
		return NO;

	//	<iq from='crone1@shakespeare.lit/desktop' id='block2' to='muclight.shakespeare.lit' type='set'>
	//		<query xmlns='urn:xmpp:muclight:0#blocking'>
	//			<user action='deny'>hag66@shakespeare.lit</room>
	//			<user action='deny'>hag77@shakespeare.lit</room>
	//		</query>
	//	</iq>

	dispatch_block_t block = ^{ @autoreleasepool {

		NSXMLElement *query = [NSXMLElement elementWithName:@"query"
													  xmlns:XMPPMUCLightBlocking];
		for (NSXMLElement *element in elements) {
			[query addChild:element];
		}

		XMPPIQ *iq = [XMPPIQ iqWithType:@"set"
									 to:[XMPPJID jidWithString:serviceName]
							  elementID:[xmppStream generateUUID]
								  child:query];

		[xmppIDTracker addElement:iq
						   target:self
						 selector:@selector(handlePerformAction:withInfo:)
						  timeout:60];

		[xmppStream sendElement:iq];
	}};

	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
	return YES;
}

- (void)handlePerformAction:(XMPPIQ *)iq withInfo:(XMPPBasicTrackingInfo *)info {
	//NSString *serviceName = [iq attributeStringValueForName:@"from" withDefaultValue:@""];
	if ([[iq type] isEqualToString:@"result"]) {
		//NSXMLElement *query = [iq elementForName:@"query"];
		[multicastDelegate xmppMUCLight:self didPerformAction:iq];
	}else{
		[multicastDelegate xmppMUCLight:self failedToPerformAction:iq];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message {

	//  <message from='coven@muclight.shakespeare.lit'
	//           to='user2@shakespeare.lit'
	//           type='groupchat'
	//           id='createnotif'>
	//      <x xmlns='urn:xmpp:muclight:0#affiliations'>
	//          <version>aaaaaaa</version>
	//          <user affiliation='member'>user2@shakespeare.lit</user>
	//      </x>
	//      <body />
	//  </message>

	XMPPJID *from = message.from;
	NSXMLElement *x = [message elementForName:@"x" xmlns:XMPPRoomLightAffiliations];
    for (NSXMLElement *user in [x elementsForName:@"user"]) {
        NSString *affiliation = [user attributeForName:@"affiliation"].stringValue;
        XMPPJID *userJID = [XMPPJID jidWithString:user.stringValue];
        [multicastDelegate xmppMUCLight:self changedAffiliation:affiliation userJID:userJID roomJID:from];
    }
}

- (void)xmppStream:(XMPPStream *)sender didRegisterModule:(id)module {

	dispatch_block_t block = ^{ @autoreleasepool {
		if ([module isKindOfClass:[XMPPRoomLight class]]){

			XMPPJID *roomJID = [(XMPPRoomLight *)module roomJID];

			[rooms addObject:roomJID];
		}
	}};

	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)xmppStream:(XMPPStream *)sender willUnregisterModule:(id)module {
	dispatch_block_t block = ^{ @autoreleasepool {
		if ([module isKindOfClass:[XMPPRoomLight class]]){

			XMPPJID *roomJID = [(XMPPRoomLight *)module roomJID];

			// It's common for the room to get deactivated and deallocated before
			// we've received the goodbye presence from the server.
			// So we're going to postpone for a bit removing the roomJID from the list.
			// This way the isMUCRoomElement will still remain accurate
			// for presence elements that may arrive momentarily.

			double delayInSeconds = [self delayInSeconds];
			dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
			dispatch_after(popTime, moduleQueue, ^{ @autoreleasepool {
				[rooms removeObject:roomJID];
			}});
		}
	}};

	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq {
	NSString *type = [iq type];

	if ([type isEqualToString:@"result"] || [type isEqualToString:@"error"]) {
		return [xmppIDTracker invokeForID:[iq elementID] withObject:iq];
	}

	return NO;
}

- (double) delayInSeconds {
	return 30.0;
}

@end
