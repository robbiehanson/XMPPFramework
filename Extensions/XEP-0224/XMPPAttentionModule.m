#import "XMPPAttentionModule.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

@implementation XMPPAttentionModule

- (id)init
{
	return [self initWithDispatchQueue:NULL];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	if ((self = [super initWithDispatchQueue:queue]))
	{
		respondsToQueries = YES;
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

- (BOOL)respondsToQueries
{
	if (dispatch_get_specific(moduleQueueTag))
	{
		return respondsToQueries;
	}
	else
	{
		__block BOOL result;
		
		dispatch_sync(moduleQueue, ^{
			result = respondsToQueries;
		});
		return result;
	}
}

- (void)setRespondsToQueries:(BOOL)flag
{
	dispatch_block_t block = ^{
		
		if (respondsToQueries != flag)
		{
			respondsToQueries = flag;
			
#ifdef _XMPP_CAPABILITIES_H
			@autoreleasepool {
				// Capabilities may have changed, need to notify others.
				[xmppStream resendMyPresence];
			}
#endif
		}
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}


- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	// This method is invoked on the moduleQueue.
	
    // Format of an attention message. Body is optional and not used by clients like Pidgin
    //    <message from='calvin@usrobots.lit/lab' to='herbie@usrobots.lit/home' type='headline'>
    //        <attention xmlns='urn:xmpp:attention:0'/>
    //        <body>Why don't you answer, Herbie?</body>
    //    </message>
    
    if ([message isAttentionMessage])
	{
        [multicastDelegate xmppAttention:self didReceiveAttentionHeadlineMessage:message];
    }
}


#ifdef _XMPP_CAPABILITIES_H
/**
 * If an XMPPCapabilites instance is used we want to advertise our support for attention requests.
 **/
- (void)xmppCapabilities:(XMPPCapabilities *)sender collectingMyCapabilities:(NSXMLElement *)query
{
	// This method is invoked on the moduleQueue.
	
	if (respondsToQueries)
	{
		// <query xmlns="http://jabber.org/protocol/disco#info">
		//   ...
		//   <feature var="urn:xmpp:attention:0"/>
		//   ...
		// </query>
		
		NSXMLElement *feature = [NSXMLElement elementWithName:@"feature"];
		[feature addAttributeWithName:@"var" stringValue:XMLNS_ATTENTION];
		
		[query addChild:feature];
	}
}
#endif

@end
