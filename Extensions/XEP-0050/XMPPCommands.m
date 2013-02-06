//
//  XMPPCommands.m
//  iPhoneXMPP
//
//  Created by Rick Mellor on 1/29/13.
//
//

#define XMLNS_DISCO_ITEMS  @"http://jabber.org/protocol/disco#items"

#import "XMPPCommands.h"
#import "XMPPLogging.h"

// Log levels: off, error, warn, info, verbose
// Log flags: trace
#if DEBUG
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#else
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

@implementation XMPPCommands

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Logic
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)activate:(XMPPStream *)aXmppStream withXMPPDisco:(XMPPDisco*)aXmppDisco
{
	if ([super activate:aXmppStream])
	{
		xmppDisco = aXmppDisco;
        [xmppDisco addDelegate:self delegateQueue:dispatch_get_main_queue()];
		
		return YES;
	}
	
	return NO;
}

- (void)deactivate
{
	// Custom code goes here (if needed)
	
	[super deactivate];
}

- (void)getEndpointCommandsList:(XMPPJID *)jid
{
    [xmppDisco sendDiscoInfoQueryTo:jid withNode:XMPP_FEATURE_CMDS ver:nil];
}

- (void)collectMyDiscoCommands
{
	// This method must be invoked on the moduleQueue
	NSAssert(dispatch_get_current_queue() == moduleQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	if (collectingMyDiscoCommands)
	{
		XMPPLogInfo(@"%@: %@ - Existing collection already in progress", [self class], THIS_METHOD);
		return;
	}
	
    myDiscoCommandsQuery = nil;
	
	collectingMyDiscoCommands = YES;
	
	// Create new query and add standard features
	//
	// <query xmlns="http://jabber.org/protocol/disco#items"
	//   node='http://jabber.org/protocol/commands'/>
	// </query>
	
	NSXMLElement *commandsQuery = [NSXMLElement elementWithName:@"query" xmlns:XMLNS_DISCO_ITEMS];
    [commandsQuery addAttributeWithName:@"node" stringValue:XMPP_FEATURE_CMDS];
		
	// Now prompt the delegates to add any additional features.
	SEL selector = @selector(xmppCommands:collectingMyDiscoCommands:);
    
	if (![multicastDelegate hasDelegateThatRespondsToSelector:selector])
	{
		// None of the delegates implement the method.
		// Use a shortcut.
        collectingMyDiscoCommands = NO;
        myDiscoCommandsQuery = commandsQuery;
	}
	else
	{
		// Query all interested delegates.
		// This must be done serially to allow them to alter the element in a thread-safe manner.
		
		GCDMulticastDelegateEnumerator *delegateEnumerator = [multicastDelegate delegateEnumerator];
		
		dispatch_queue_t concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
		dispatch_async(concurrentQueue, ^{ @autoreleasepool {
			
			// Allow delegates to modify outgoing element
			
			id del;
			dispatch_queue_t dq;
			
			while ([delegateEnumerator getNextDelegate:&del delegateQueue:&dq forSelector:selector])
			{
				dispatch_sync(dq, ^{ @autoreleasepool {
					
                    [del xmppCommands:self collectingMyDiscoCommands:commandsQuery];
				}});
			}
            
            collectingMyDiscoCommands = NO;
            myDiscoCommandsQuery = commandsQuery;
		}});
	}
}

- (void)executeCommand:(NSString*)command withType:(NSString*)type onEndpoint:(XMPPJID*)jid withXData:(NSXMLElement*)xData
{
    //<iq type='set' to='responder@domain' id='exec3'>
    //    <command xmlns='http://jabber.org/protocol/commands' sessionid='config:20020923T213616Z-700' node='config'>
    //        <x xmlns='jabber:x:data' type='submit'>
    //            <field var='mode'>
    //                <value>3</value>
    //            </field>
    //            <field var='state'>
    //                <value>on</value>
    //            </field>
    //        </x>
    //    </command>
    //</iq>
    
	NSXMLElement *commandElement = [NSXMLElement elementWithName:@"command" xmlns:XMPP_FEATURE_CMDS];
    [commandElement addAttributeWithName:@"node" stringValue:command];
    [commandElement addAttributeWithName:@"action" stringValue:@"execute"];
        
    if (xData)
    {
        [commandElement addChild:xData];
    }
	
	XMPPIQ *iq = [XMPPIQ iqWithType:type to:jid elementID:[xmppStream generateUUID] child:commandElement];
	
	[xmppStream sendElement:iq];
}

- (void)returnExecutionResult:(NSXMLElement *)data toEndpoint:(XMPPJID*)endpoint forCommand:(NSString*)command withStatus:(NSString*)status
{
    NSXMLElement *commandElement = [NSXMLElement elementWithName:@"command" xmlns:XMPP_FEATURE_CMDS];
    [commandElement addAttributeWithName:@"node" stringValue:command];
    [commandElement addAttributeWithName:@"status" stringValue:status];
    [commandElement addAttributeWithName:@"sessionid" stringValue:[xmppStream generateUUID]];
    
    if (data)
    {
        [commandElement addChild:data];
    }
	
	XMPPIQ *iq = [XMPPIQ iqWithType:@"result" to:endpoint elementID:[xmppStream generateUUID] child:commandElement];
	
	[xmppStream sendElement:iq];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
	if (myDiscoCommandsQuery == nil)
	{
		[self collectMyDiscoCommands];
	}
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
    NSLog(@"Got an IQ");
    
/* Without arguments */
    //<iq type='set' to='responder@domain' id='exec1'>
    //    <command xmlns='http://jabber.org/protocol/commands' node='list' action='execute'/>
    //</iq>


/* With arguments */
    //<iq type='set' to='responder@domain' id='exec3'>
    //    <command xmlns='http://jabber.org/protocol/commands' sessionid='config:20020923T213616Z-700' node='config'>
    //        <x xmlns='jabber:x:data' type='submit'>
    //            <field var='mode'>
    //                <value>3</value>
    //            </field>
    //            <field var='state'>
    //                <value>on</value>
    //            </field>
    //        </x>
    //    </command>
    //</iq>
    
    NSString *node = [iq attributeStringValueForName:@"type"];
    
    if (node != nil && [node isEqualToString:@"set"])
    {
        NSXMLElement *command = [iq elementForName:@"command" xmlns:XMPP_FEATURE_CMDS];
        
        if (command != nil) // disco#info query
        {
            NSString *node = [command attributeStringValueForName:@"node"];
            NSString *action = [command attributeStringValueForName:@"action"];
            
            // Action is optional and implied to be 'execute' if missing
            if (action == nil || (action != nil && [action isEqualToString:@"execute"]))
            {
                NSXMLElement *xData = [command elementForName:@"x" xmlns:@"jabber:x:data"];
                
                [multicastDelegate xmppCommands:self executeCommand:node fromJID:[iq from] withXData:xData];
                return YES;
            }
        }
    }
    else if (node != nil && [node isEqualToString:@"result"])
    {
        NSXMLElement *command = [iq elementForName:@"command" xmlns:XMPP_FEATURE_CMDS];
        
        if (command != nil)
        {
            NSString *node = [command attributeStringValueForName:@"node"];
            NSString *status = [command attributeStringValueForName:@"status"];
            NSString *sessionid = [command attributeStringValueForName:@"sessionid"];
            
            NSXMLElement *morse = [command elementForName:@"m" xmlns:@"morse"];
            
            if (morse != nil)
            {
                [multicastDelegate xmppCommands:self receivedCommandResult:status fromEndpoint:[iq from] forCommand:node withSessionId:sessionid andPayload:morse];
                return NO;
            }
            
        }
    }
    
    return NO;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPDisco Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppDisco:(XMPPDisco *)sender didReceiveDiscoveryItems:(NSXMLElement *)discoItems forJID:(XMPPJID *)jid
{
    NSString *node = [discoItems attributeStringValueForName:@"node"];
    
    if (node != nil && [node isEqualToString:XMPP_FEATURE_CMDS])
    {
        //<iq type='result' to='requester@domain' from='responder@domain'>
        //    <query xmlns='http://jabber.org/protocol/disco#items' node='http://jabber.org/protocol/commands'>
        //        <item jid='responder@domain' node='list' name='List Service Configurations'/>
        //        <item jid='responder@domain' node='config' name='Configure Service'/>
        //        <item jid='responder@domain' node='reset' name='Reset Service Configuration'/>
        //        <item jid='responder@domain' node='start' name='Start Service'/>
        //        <item jid='responder@domain' node='stop' name='Stop Service'/>
        //        <item jid='responder@domain' node='restart' name='Restart Service'/>
        //    </query>
        //</iq>
        
        NSLog(@"XMPPCommands: In didReceiveDiscoveryInfo");
        
        // Remember XML hiearchy memory management rules.
        // The passed parameter is a subnode of the IQ, and we need to pass it asynchronously to delegate(s).
        NSXMLElement *query = [discoItems copy];
        
        // Notify the delegate(s)
        [multicastDelegate xmppCommands:self didReceiveCommandsList:query forJID:jid];
    }
}

@end
