#import "XMPPMessageCarbons.h"
#import "XMPP.h"
#import "XMPPFramework.h"
#import "XMPPLogging.h"
#import "XMPPIDTracker.h"
#import "NSXMLElement+XEP_0297.h"
#import "XMPPMessage+XEP_0280.h"
#import "XMPPInternal.h"

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


#define XMLNS_XMPP_MESSAGE_CARBONS @"urn:xmpp:carbons:2"

@interface XMPPMessageCarbons()
{
    BOOL autoEnableMessageCarbons;
    BOOL allowsUntrustedMessageCarbons;
    BOOL messageCarbonsEnabled;
    
    XMPPIDTracker *xmppIDTracker;
}
@end

@implementation XMPPMessageCarbons

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
    if((self = [super initWithDispatchQueue:queue]))
    {
        autoEnableMessageCarbons = YES;
    }
    return self;
}

- (BOOL)activate:(XMPPStream *)aXmppStream
{
	XMPPLogTrace();
	
	if ([super activate:aXmppStream])
	{
		XMPPLogVerbose(@"%@: Activated", THIS_FILE);
		
        xmppIDTracker = [[XMPPIDTracker alloc] initWithDispatchQueue:moduleQueue];
        
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
    
	[super deactivate];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)autoEnableMessageCarbons
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		result = autoEnableMessageCarbons;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

- (void)setAutoEnableMessageCarbons:(BOOL)flag
{
	dispatch_block_t block = ^{
		autoEnableMessageCarbons = flag;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (BOOL)isMessageCarbonsEnabled
{
    __block BOOL result = NO;
	
	dispatch_block_t block = ^{
		result = messageCarbonsEnabled;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

- (BOOL)allowsUntrustedMessageCarbons
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		result = allowsUntrustedMessageCarbons;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

- (void)setAllowsUntrustedMessageCarbons:(BOOL)flag
{
	dispatch_block_t block = ^{
		allowsUntrustedMessageCarbons = flag;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)enableMessageCarbons
{
    dispatch_block_t block = ^{
        
        if(!messageCarbonsEnabled && [xmppIDTracker numberOfIDs] == 0)
        {
            NSString *elementID = [XMPPStream generateUUID];
            XMPPIQ *iq = [XMPPIQ iqWithType:@"set" elementID:elementID];
            [iq setXmlns:@"jabber:client"];
            
            NSXMLElement *enable = [NSXMLElement elementWithName:@"enable" xmlns:XMLNS_XMPP_MESSAGE_CARBONS];
            [iq addChild:enable];
            
            [xmppIDTracker addElement:iq
                               target:self
                             selector:@selector(enableMessageCarbonsIQ:withInfo:)
                              timeout:XMPPIDTrackerTimeoutNone];
            
            [xmppStream sendElement:iq];
        }
    };
    
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
}

- (void)disableMessageCarbons
{
    dispatch_block_t block = ^{
        
        if(messageCarbonsEnabled && [xmppIDTracker numberOfIDs] == 0)
        {
            NSString *elementID = [XMPPStream generateUUID];
            
            XMPPIQ *iq = [XMPPIQ iqWithType:@"set" elementID:elementID];
            [iq setXmlns:@"jabber:client"];
            
            NSXMLElement *enable = [NSXMLElement elementWithName:@"disable" xmlns:XMLNS_XMPP_MESSAGE_CARBONS];
            [iq addChild:enable];
            
            [xmppIDTracker addElement:iq
                               target:self
                             selector:@selector(disableMessageCarbonsIQ:withInfo:)
                              timeout:XMPPIDTrackerTimeoutNone];
            
            [xmppStream sendElement:iq];
        }
    };
    
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	XMPPLogTrace();
        
    messageCarbonsEnabled = NO;

    if(self.autoEnableMessageCarbons)
    {
        [self enableMessageCarbons];
    }
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
    messageCarbonsEnabled = NO;
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
    [xmppIDTracker invokeForID:[iq elementID] withObject:iq];

	return NO;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)enableMessageCarbonsIQ:(XMPPIQ *)iq withInfo:(XMPPBasicTrackingInfo *)trackerInfo
{
    XMPPLogTrace();
    
    if([iq isResultIQ])
    {
        messageCarbonsEnabled = YES;
    }
}

- (void)disableMessageCarbonsIQ:(XMPPIQ *)iq withInfo:(XMPPBasicTrackingInfo *)trackerInfo
{
    XMPPLogTrace();
    
    if([iq isResultIQ])
    {
        messageCarbonsEnabled = NO;
    }
}

- (XMPPMessage *)xmppStream:(XMPPStream *)sender willReceiveMessage:(XMPPMessage *)message
{
	XMPPLogTrace();
	
    if([message isTrustedMessageCarbonForMyJID:sender.myJID] ||
       ([message isMessageCarbon] && allowsUntrustedMessageCarbons))
    {
        BOOL outgoing = [message isSentMessageCarbon];
        
        XMPPMessage *messageCarbonForwardedMessage = [message messageCarbonForwardedMessage];
        
        [multicastDelegate xmppMessageCarbons:self
                           willReceiveMessage:messageCarbonForwardedMessage
                                     outgoing:outgoing];
    }
    
    return message;
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	XMPPLogTrace();
	
    if([message isTrustedMessageCarbonForMyJID:sender.myJID] ||
       ([message isMessageCarbon] && allowsUntrustedMessageCarbons))
    {
        BOOL outgoing = [message isSentMessageCarbon];
        
        XMPPMessage *messageCarbonForwardedMessage = [message messageCarbonForwardedMessage];
                
        [multicastDelegate xmppMessageCarbons:self
                            didReceiveMessage:messageCarbonForwardedMessage
                                     outgoing:outgoing];
    }
}


@end
