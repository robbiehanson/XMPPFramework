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
@property (strong, nonatomic) XMPPIDTracker *xmppIDTracker;
@property (strong, nonatomic) NSMutableDictionary<NSString *, NSXMLElement *> *resultSetPageElementsIndex;
@property (strong, nonatomic) dispatch_group_t resultSetPageProcessingGroup;

@end

@implementation XMPPMessageArchiveManagement

@synthesize resultAutomaticPagingPageSize=_resultAutomaticPagingPageSize;
@synthesize xmppIDTracker;
@synthesize submitsPayloadMessagesForStreamProcessing=_submitsPayloadMessagesForStreamProcessing;

- (NSInteger)resultAutomaticPagingPageSize
{
    __block NSInteger result = NO;
    
    dispatch_block_t block = ^{
        result = _resultAutomaticPagingPageSize;
    };
    
    if (dispatch_get_specific(moduleQueueTag))
        block();
    else
        dispatch_sync(moduleQueue, block);
    
    return result;
}

- (void)setResultAutomaticPagingPageSize:(NSInteger)resultAutomaticPagingPageSize
{
    dispatch_block_t block = ^{
        _resultAutomaticPagingPageSize = resultAutomaticPagingPageSize;
    };
    
    if (dispatch_get_specific(moduleQueueTag))
        block();
    else
        dispatch_async(moduleQueue, block);
}

- (BOOL)submitsPayloadMessagesForStreamProcessing
{
    __block BOOL result = NO;
    
    dispatch_block_t block = ^{
        result = _submitsPayloadMessagesForStreamProcessing;
    };
    
    if (dispatch_get_specific(moduleQueueTag))
        block();
    else
        dispatch_sync(moduleQueue, block);
    
    return result;
}

- (void)setSubmitsPayloadMessagesForStreamProcessing:(BOOL)submitsPayloadMessagesForStreamProcessing
{
    dispatch_block_t block = ^{
        _submitsPayloadMessagesForStreamProcessing = submitsPayloadMessagesForStreamProcessing;
    };
    
    if (dispatch_get_specific(moduleQueueTag))
        block();
    else
        dispatch_async(moduleQueue, block);
}

- (void)retrieveMessageArchiveWithFields:(NSArray *)fields withResultSet:(XMPPResultSet *)resultSet {
	[self retrieveMessageArchiveAt:nil withFields:fields withResultSet:resultSet];
}

- (void)retrieveMessageArchiveAt:(XMPPJID *)archiveJID withFields:(NSArray *)fields withResultSet:(XMPPResultSet *)resultSet {
    NSXMLElement *formElement = [NSXMLElement elementWithName:@"x" xmlns:@"jabber:x:data"];
    [formElement addAttributeWithName:@"type" stringValue:@"submit"];
    [formElement addChild:[XMPPMessageArchiveManagement fieldWithVar:@"FORM_TYPE" type:@"hidden" andValue:@"urn:xmpp:mam:1"]];
    
    for (NSXMLElement *field in fields) {
        [formElement addChild:field];
    }

    [self retrieveMessageArchiveAt:archiveJID withFormElement:formElement resultSet:resultSet];
}

- (void)retrieveMessageArchiveAt:(XMPPJID *)archiveJID withFormElement:(NSXMLElement *)formElement resultSet:(XMPPResultSet *)resultSet {
	dispatch_block_t block = ^{

		XMPPIQ *iq = [XMPPIQ iqWithType:@"set"];
		[iq addAttributeWithName:@"id" stringValue:[XMPPStream generateUUID]];
		
		if (archiveJID) {
			[iq addAttributeWithName:@"to" stringValue:[archiveJID full]];
		}

		self.queryID = [XMPPStream generateUUID];
        self.resultSetPageElementsIndex = [[NSMutableDictionary alloc] init];
        self.resultSetPageProcessingGroup = dispatch_group_create();
		
		NSXMLElement *queryElement = [NSXMLElement elementWithName:@"query" xmlns:XMLNS_XMPP_MAM];
		[queryElement addAttributeWithName:@"queryid" stringValue:self.queryID];
		[iq addChild:queryElement];

		[queryElement addChild:formElement];

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
	
    NSString *finalizedQueryID = self.queryID;
    
    dispatch_group_notify(self.resultSetPageProcessingGroup, self.moduleQueue, ^{
        NSMutableArray *pageArchiveIDs;
        if ([finalizedQueryID isEqualToString:self.queryID]) {
            pageArchiveIDs = [[NSMutableArray alloc] init];
            for (NSXMLElement *result in self.resultSetPageElementsIndex.allValues) {
                [pageArchiveIDs addObject:[result attributeStringValueForName:@"id"]];
            }
            
            self.queryID = nil;
            self.resultSetPageElementsIndex = nil;
            self.resultSetPageProcessingGroup = nil;
        }
        
        if ([[iq type] isEqualToString:@"result"]) {
            NSXMLElement *finElement = [iq elementForName:@"fin" xmlns:XMLNS_XMPP_MAM];
            NSXMLElement *setElement = [finElement elementForName:@"set" xmlns:@"http://jabber.org/protocol/rsm"];
            
            XMPPResultSet *resultSet = [XMPPResultSet resultSetFromElement:setElement];
            [multicastDelegate xmppMessageArchiveManagement:self didFinishReceivingMessagesWithSet:resultSet];
            
            if (pageArchiveIDs.count > 0) {
                [multicastDelegate xmppMessageArchiveManagement:self didFinishReceivingMessagesWithArchiveIDs:pageArchiveIDs];
            }
            
            NSString *lastId = [resultSet elementForName:@"last"].stringValue;
            if (self.resultAutomaticPagingPageSize != 0 && ![finElement attributeBoolValueForName:@"complete"] && lastId) {
                [self continueAutomaticPagingWithOriginalIQ:[XMPPIQ iqFromElement:[trackerInfo element]] lastResultID:lastId];
            }
        } else {
            [multicastDelegate xmppMessageArchiveManagement:self didFailToReceiveMessages:iq];
        }
    });
}

- (void)continueAutomaticPagingWithOriginalIQ:(XMPPIQ *)originalIQ lastResultID:(NSString *)lastResultID
{
    XMPPJID *originalArchiveJID = [originalIQ to];
    NSXMLElement *originalFormElement = [[[originalIQ elementForName:@"query"] elementForName:@"x"] copy];
    XMPPResultSet *pagingResultSet = [[XMPPResultSet alloc] initWithMax:self.resultAutomaticPagingPageSize after:lastResultID];
    
    [self retrieveMessageArchiveAt:originalArchiveJID withFormElement:originalFormElement resultSet:pagingResultSet];
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

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
    XMPPElementEvent *event = [sender currentElementEvent];
    
	NSXMLElement *result = [message elementForName:@"result" xmlns:XMLNS_XMPP_MAM];
	NSString *queryID = [result attributeForName:@"queryid"].stringValue;
    
    if ([queryID isEqualToString:self.queryID]) {
        NSString *processingID = [sender generateUUID];
        self.resultSetPageElementsIndex[processingID] = result;
        
        [multicastDelegate xmppMessageArchiveManagement:self didReceiveMAMMessage:message];
        
        if (self.submitsPayloadMessagesForStreamProcessing && [result forwardedMessage]) {
            dispatch_group_enter(self.resultSetPageProcessingGroup);
            [self.xmppStream injectElement:[result forwardedMessage] registeringEventWithID:processingID];
        }
    }
    
    NSXMLElement *injectedPayloadMessageResult = self.resultSetPageElementsIndex[event.uniqueID];
    if (injectedPayloadMessageResult) {
        [multicastDelegate xmppMessageArchiveManagement:self didSubmitPayloadMessageFromQueryResult:injectedPayloadMessageResult];
    }
}

- (void)xmppStream:(XMPPStream *)sender didFinishProcessingElementEvent:(XMPPElementEvent *)event
{
    if (self.resultSetPageElementsIndex[event.uniqueID]) {
        dispatch_group_leave(self.resultSetPageProcessingGroup);
    }
}

@end
