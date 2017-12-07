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
#import "XMPPLogging.h"
#import "XMPPMessage+XEP_0313.h"

// Log levels: off, error, warn, info, verbose
#if DEBUG
static const int xmppLogLevel = XMPP_LOG_LEVEL_INFO | XMPP_LOG_FLAG_SEND_RECV; // | XMPP_LOG_FLAG_TRACE;
#else
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

NSString *const XMLNS_XMPP_MAM = @"urn:xmpp:mam:2";
static NSString *const QueryIdAttributeName = @"queryid";


@interface XMPPMessageArchiveManagement()
/** Only safe to access on moduleQueue. */
@property (nonatomic, strong, readonly, nonnull) NSMutableSet<NSString*> *outstandingQueryIds;
/** Setup in activate: */
@property (strong, nonatomic, nullable, readonly) XMPPIDTracker *xmppIDTracker;
@end

@implementation XMPPMessageArchiveManagement
@synthesize resultAutomaticPagingPageSize = _resultAutomaticPagingPageSize;
@synthesize xmppIDTracker = _xmppIDTracker;

- (instancetype) initWithDispatchQueue:(dispatch_queue_t)queue {
    if (self = [super initWithDispatchQueue:queue]) {
        _outstandingQueryIds = [NSMutableSet set];
    }
    return self;
}

- (NSInteger)resultAutomaticPagingPageSize
{
    __block NSInteger result = NO;
    [self performBlock:^{
        result = _resultAutomaticPagingPageSize;
    }];
    return result;
}

- (void)setResultAutomaticPagingPageSize:(NSInteger)resultAutomaticPagingPageSize
{
    [self performBlockAsync:^{
        _resultAutomaticPagingPageSize = resultAutomaticPagingPageSize;
    }];
}

- (void)retrieveMessageArchiveWithFields:(NSArray *)fields withResultSet:(XMPPResultSet *)resultSet {
	[self retrieveMessageArchiveAt:nil withFields:fields withResultSet:resultSet];
}

- (void)retrieveMessageArchiveAt:(XMPPJID *)archiveJID withFields:(NSArray *)fields withResultSet:(XMPPResultSet *)resultSet {
    NSXMLElement *formElement = [NSXMLElement elementWithName:@"x" xmlns:@"jabber:x:data"];
    [formElement addAttributeWithName:@"type" stringValue:@"submit"];
    [formElement addChild:[XMPPMessageArchiveManagement fieldWithVar:@"FORM_TYPE" type:@"hidden" andValue:XMLNS_XMPP_MAM]];
    
    for (NSXMLElement *field in fields) {
        [formElement addChild:field];
    }

    [self retrieveMessageArchiveAt:archiveJID withFormElement:formElement resultSet:resultSet];
}

- (void)retrieveMessageArchiveAt:(XMPPJID *)archiveJID withFormElement:(NSXMLElement *)formElement resultSet:(XMPPResultSet *)resultSet {
	[self performBlockAsync:^{
		XMPPIQ *iq = [XMPPIQ iqWithType:@"set"];
		[iq addAttributeWithName:@"id" stringValue:[XMPPStream generateUUID]];
		
		if (archiveJID) {
			[iq addAttributeWithName:@"to" stringValue:[archiveJID full]];
		}

		NSString *queryId = [XMPPStream generateUUID];
        [_outstandingQueryIds addObject:queryId];
		
		NSXMLElement *queryElement = [NSXMLElement elementWithName:@"query" xmlns:XMLNS_XMPP_MAM];
		[queryElement addAttributeWithName:QueryIdAttributeName stringValue:queryId];
		[iq addChild:queryElement];

		[queryElement addChild:formElement];

		if (resultSet) {
			[queryElement addChild:resultSet];
		}
        
		[self.xmppIDTracker addElement:iq
						   target:self
						 selector:@selector(handleMessageArchiveIQ:withInfo:)
						  timeout:60];

		[xmppStream sendElement:iq];
	}];
}

- (void)handleMessageArchiveIQ:(XMPPIQ *)iq withInfo:(XMPPBasicTrackingInfo *)trackerInfo {
	
	if ([[iq type] isEqualToString:@"result"]) {
		
		NSXMLElement *finElement = [iq elementForName:@"fin" xmlns:XMLNS_XMPP_MAM];
        NSString *queryId = [finElement attributeStringValueForName:QueryIdAttributeName];
		NSXMLElement *setElement = [finElement elementForName:@"set" xmlns:@"http://jabber.org/protocol/rsm"];
		
        XMPPResultSet *resultSet = [XMPPResultSet resultSetFromElement:setElement];
        NSString *lastId = [resultSet elementForName:@"last"].stringValue;
        
        if (self.resultAutomaticPagingPageSize == 0 || [finElement attributeBoolValueForName:@"complete"] || !lastId) {
            
            if (queryId.length) {
                [self.outstandingQueryIds removeObject:queryId];
            }
            
            [multicastDelegate xmppMessageArchiveManagement:self didFinishReceivingMessagesWithSet:resultSet];
            return;
        }
        
        XMPPIQ *originalIq = [XMPPIQ iqFromElement:[trackerInfo element]];
        XMPPJID *originalArchiveJID = [originalIq to];
        NSXMLElement *originalFormElement = [[[originalIq elementForName:@"query"] elementForName:@"x"] copy];
        XMPPResultSet *pagingResultSet = [[XMPPResultSet alloc] initWithMax:self.resultAutomaticPagingPageSize after:lastId];
        
        [self retrieveMessageArchiveAt:originalArchiveJID withFormElement:originalFormElement resultSet:pagingResultSet];
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
	[self performBlockAsync:^{
		XMPPIQ *iq = [XMPPIQ iqWithType:@"get"];
		[iq addAttributeWithName:@"id" stringValue:[XMPPStream generateUUID]];

		NSXMLElement *queryElement = [NSXMLElement elementWithName:@"query" xmlns:XMLNS_XMPP_MAM];
		[iq addChild:queryElement];

		[self.xmppIDTracker addElement:iq
						   target:self
						 selector:@selector(handleFormFieldsIQ:withInfo:)
						  timeout:60];

		[xmppStream sendElement:iq];
	}];
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
		_xmppIDTracker = [[XMPPIDTracker alloc] initWithDispatchQueue:moduleQueue];
		return YES;
	}
	return NO;
}

- (void)deactivate {
	[self performBlock:^{ @autoreleasepool {
		[self.xmppIDTracker removeAllIDs];
		_xmppIDTracker = nil;
	}}];
	[super deactivate];
}

#pragma mark XMPPStream Delegate

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	NSString *type = [iq type];
	if ([type isEqualToString:@"result"] || [type isEqualToString:@"error"])
	{
		return [self.xmppIDTracker invokeForID:[iq elementID] withObject:iq];
	}
	
	return NO;
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message {
    NSXMLElement *result = message.mamResult;
	BOOL forwarded = result.hasForwardedStanza;
    if (!forwarded) {
        return;
    }
	NSString *queryID = [result attributeForName:QueryIdAttributeName].stringValue;
	if (queryID.length && [self.outstandingQueryIds containsObject:queryID]) {
		[multicastDelegate xmppMessageArchiveManagement:self didReceiveMAMMessage:message];
    } else {
        XMPPLogWarn(@"Received unexpected MAM response queryid %@", queryID);
    }
}

@end
