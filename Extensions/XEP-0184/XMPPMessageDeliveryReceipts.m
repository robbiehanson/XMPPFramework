#import "XMPPMessageDeliveryReceipts.h"
#import "XMPPMessage+XEP_0184.h"
#import "XMPPFramework.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#define XMLNS_URN_XMPP_RECEIPTS @"urn:xmpp:receipts"

@implementation XMPPMessageDeliveryReceipts

@synthesize autoSendMessageDeliveryRequests;
@synthesize autoSendMessageDeliveryReceipts;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Init/Dealloc
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
    if((self = [super initWithDispatchQueue:queue]))
    {
        autoSendMessageDeliveryRequests = NO;
        autoSendMessageDeliveryReceipts = NO;
    }
    
    return self;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPModule
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)autoSendMessageDeliveryRequests
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		result = autoSendMessageDeliveryRequests;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

- (void)setAutoSendMessageDeliveryRequests:(BOOL)flag
{
	dispatch_block_t block = ^{
		autoSendMessageDeliveryRequests = flag;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (BOOL)autoSendMessageDeliveryReceipts
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		result = autoSendMessageDeliveryReceipts;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

- (void)setAutoSendMessageDeliveryReceipts:(BOOL)flag
{
	dispatch_block_t block = ^{
		autoSendMessageDeliveryReceipts = flag;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
    if([message hasReceiptRequest])
    {        
        if(self.autoSendMessageDeliveryReceipts)
        {
            XMPPMessage *generatedReceiptResponse = [message generateReceiptResponse];
            [sender sendElement:generatedReceiptResponse];
        }
    }
    
    if ([message hasReceiptResponse])
    {
        [multicastDelegate xmppMessageDeliveryReceipts:self didReceiveReceiptResponseMessage:message];
    }
}

- (XMPPMessage *)xmppStream:(XMPPStream *)sender willSendMessage:(XMPPMessage *)message
{    
    if(self.autoSendMessageDeliveryRequests
       && [message to]
       && ![message isErrorMessage] && ![[[message attributeForName:@"type"] stringValue] isEqualToString:@"groupchat"]
       && [[message elementID] length]
       && ![message hasReceiptRequest] && ![message hasReceiptResponse])
    {
        
#ifdef _XMPP_CAPABILITIES_H
        BOOL addReceiptRequest = NO;
        
        __block XMPPCapabilities *xmppCapabilities = nil;
        
        [xmppStream enumerateModulesOfClass:[XMPPCapabilities class] withBlock:^(XMPPModule *module, NSUInteger idx, BOOL *stop) {
            xmppCapabilities = (XMPPCapabilities *)module;
        }];
        
        if([[message to] isFull] && [xmppCapabilities.xmppCapabilitiesStorage areCapabilitiesKnownForJID:[message to] xmppStream:sender])
        {
            NSXMLElement *capabilities = [xmppCapabilities.xmppCapabilitiesStorage capabilitiesForJID:[message to] xmppStream:xmppStream];
            
            for(NSXMLElement *feature in [capabilities children])
            {
                if([[feature name] isEqualToString:@"feature"]
                   && [[feature attributeStringValueForName:@"var"] isEqualToString:XMLNS_URN_XMPP_RECEIPTS])
                {
                    addReceiptRequest = YES;
                    break;
                }
                
            }
            
        }
        else
        {
            addReceiptRequest = YES;
        }
#else
        BOOL addReceiptRequest = YES;
#endif
        
        if(addReceiptRequest)
        {
            [message addReceiptRequest];
        }
    }
    
    return message;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPCapabilities delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#ifdef _XMPP_CAPABILITIES_H
/**
 * If an XMPPCapabilites instance is used we want to advertise our support for XEP-0184.
 **/
- (void)xmppCapabilities:(XMPPCapabilities *)sender collectingMyCapabilities:(NSXMLElement *)query
{
    // This method is invoked on the moduleQueue.
    
    // <query xmlns="http://jabber.org/protocol/disco#info">
    //   ...
    //   <feature var='urn:xmpp:receipts'/>
    //   ...
    // </query>
    
    NSXMLElement *messageDeliveryReceiptsFeatureElement = [NSXMLElement elementWithName:@"feature"];
    [messageDeliveryReceiptsFeatureElement addAttributeWithName:@"var" stringValue:XMLNS_URN_XMPP_RECEIPTS];
    
    [query addChild:messageDeliveryReceiptsFeatureElement];
}
#endif

@end
