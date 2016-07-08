//
//  XMPPMessageArchiveManagement.m
//
//  Created by Andres Canal on 4/8/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

#import "XMPPMessageArchiveManagement.h"
#import "XMPPFramework.h"
#import "XMPPLogging.h"
#import "XMPPIDTracker.h"
#import "NSXMLElement+XEP_0297.h"

#define XMLNS_XMPP_MAM @"urn:xmpp:mam:1"

@interface XMPPMessageArchiveManagement()
@property (strong, nonatomic) NSString *queryID;
@end

@implementation XMPPMessageArchiveManagement

- (void)retrieveMessageArchiveWithFields:(NSArray *)fields withResultSet:(XMPPResultSet *)resultSet {
	dispatch_block_t block = ^{

		XMPPIQ *iq = [XMPPIQ iqWithType:@"set"];
		[iq addAttributeWithName:@"id" stringValue:[XMPPStream generateUUID]];

		self.queryID = [XMPPStream generateUUID];
		
		NSXMLElement *queryElement = [NSXMLElement elementWithName:@"query" xmlns:XMLNS_XMPP_MAM];
		[queryElement addAttributeWithName:@"queryid" stringValue:self.queryID];
		[iq addChild:queryElement];

		NSXMLElement *xElement = [NSXMLElement elementWithName:@"x" xmlns:@"jabber:x:data"];
		[xElement addAttributeWithName:@"type" stringValue:@"submit"];
		[xElement addChild:[XMPPMessageArchiveManagement fieldWithVar:@"FORM_TYPE" type:@"hidden" andValue:@"urn:xmpp:mam:1"]];

		for (NSXMLElement *field in fields) {
			[xElement addChild:field];
		}

		[queryElement addChild:xElement];

		if (resultSet) {
			[queryElement addChild:resultSet];
		}
        
		[xmppIDTracker addElement:iq
						   target:self
						 selector:@selector(handleMessageArchiveIQ:withInfo:)
						  timeout:60];

		[xmppStream sendElement:iq];

	};
	
	if (dispatch_get_specific(moduleQueueTag)) {
		block();
	} else {
		dispatch_sync(moduleQueue, block);
	}
}

- (void)handleMessageArchiveIQ:(XMPPIQ *)iq withInfo:(XMPPBasicTrackingInfo *)trackerInfo {
	
	if ([[iq type] isEqualToString:@"result"]) {
		
		NSXMLElement *finElement = [iq elementForName:@"fin" xmlns:XMLNS_XMPP_MAM];
		NSXMLElement *setElement = [finElement elementForName:@"set" xmlns:@"http://jabber.org/protocol/rsm"];
		
		XMPPResultSet *resultSet = [XMPPResultSet resultSetFromElement:setElement];
		[multicastDelegate xmppMessageArchiveManagement:self didFinishReceivingMessagesWithSet:resultSet];
	} else {
		[multicastDelegate xmppMessageArchiveManagement:self didFailToReceiveMessages:iq];
	}
}

+ (NSXMLElement *)fieldWithVar:(NSString *)var type:(NSString *)type andValue:(NSString *)value {
	NSXMLElement *field = [NSXMLElement elementWithName:@"field"];
	[field addAttributeWithName:@"var" stringValue:var];
	
	if(type){
		[field addAttributeWithName:@"type" stringValue:type];
	}
	
	NSXMLElement *elementValue = [NSXMLElement elementWithName:@"value"];
	elementValue.stringValue = value;
	
	[field addChild:elementValue];
	
	return field;
}

- (void)retrieveFormFields {

	dispatch_block_t block = ^{

		XMPPIQ *iq = [XMPPIQ iqWithType:@"get"];
		[iq addAttributeWithName:@"id" stringValue:[XMPPStream generateUUID]];

		NSXMLElement *queryElement = [NSXMLElement elementWithName:@"query" xmlns:XMLNS_XMPP_MAM];
		[iq addChild:queryElement];

		[xmppIDTracker addElement:iq
						   target:self
						 selector:@selector(handleFormFieldsIQ:withInfo:)
						  timeout:60];

		[xmppStream sendElement:iq];
	};

	if (dispatch_get_specific(moduleQueueTag)) {
		block();
	} else {
		dispatch_sync(moduleQueue, block);
	}
}

- (void)handleFormFieldsIQ:(XMPPIQ *)iq withInfo:(XMPPBasicTrackingInfo *)trackerInfo {
	
	if ([[iq type] isEqualToString:@"result"]) {
		[multicastDelegate xmppMessageArchiveManagement:self didReceiveFormFields:iq];
	} else {
		[multicastDelegate xmppMessageArchiveManagement:self didFailToReceiveFormFields:iq];
	}
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
	
	if (dispatch_get_specific(moduleQueueTag)) {
		block();
	} else {
		dispatch_sync(moduleQueue, block);
	}
	
	[super deactivate];
}

#pragma mark XMPPStream Delegate

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	NSString *type = [iq type];
	if ([type isEqualToString:@"result"] || [type isEqualToString:@"error"])
	{
		return [xmppIDTracker invokeForID:[iq elementID] withObject:iq];
	}
	
	return NO;
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message {
	NSXMLElement *result = [message elementForName:@"result" xmlns:XMLNS_XMPP_MAM];
	BOOL forwarded = [result hasForwardedStanza];
	
	NSString *queryID = [result attributeForName:@"queryid"].stringValue;
	
	if (forwarded && [queryID isEqualToString:self.queryID]) {
		[multicastDelegate xmppMessageArchiveManagement:self didReceiveMAMMessage:message];
	}
}

@end
