#import "XMPPLogging.h"
#import "XMPPFramework.h"
#import "NSDate+XMPPDateTimeProfiles.h"
#import "NSNumber+XMPP.h"
#import "UtilityClass.h"

#import "XMPPMAM.h"

#define XMLNS_XMPP_MAM @"urn:xmpp:mam:1"
#define XMLNS_XMPP_MAM_FORM @"jabber:x:data"


@implementation XMPPMAM

- (NSXMLElement*)getFormField:(NSString*)var withValue:(NSString*)value
{
    NSXMLElement *fieldElement = [NSXMLElement elementWithName:@"field"];
    [fieldElement addAttributeWithName:@"var" stringValue: var];
    NSXMLElement *valueElement = [NSXMLElement elementWithName:@"value" stringValue: value];
    [fieldElement addChild:valueElement];
    return fieldElement;
}


- (void)getMAMMessages:(XMPPJID*)jid startTime:(NSDate*)startTime endTime:(NSDate*)endTime resultSet:(XMPPResultSet*)resultSet isMUC:(BOOL)isMUC
{
    dispatch_block_t block = ^{ @autoreleasepool
        {
            //<iq type='set' id='juliet1'>
            //  <query xmlns='urn:xmpp:mam:1'>
            //    <x xmlns='jabber:x:data' type='submit'>
            //      <field var='FORM_TYPE' type='hidden'>
            //        <value>urn:xmpp:mam:1</value>
            //      </field>
            //      <field var='with'>
            //        <value>juliet@capulet.lit</value>
            //      </field>
            //    </x>
            //  </query>
            //</iq>
            
            NSString *elementID = [XMPPStream generateUUID];
            
            NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:XMLNS_XMPP_MAM];
            
            [query addAttributeWithName:@"queryid" stringValue:[UtilityClass generateUniqueID]];
            
            if(jid != nil || startTime != nil || endTime != nil)
            {
                NSXMLElement *filterForm = [NSXMLElement elementWithName:@"x" xmlns:XMLNS_XMPP_MAM_FORM];
                [filterForm addAttributeWithName:@"type" stringValue:@"submit"];
                
                NSXMLElement *fieldFormType = [self getFormField: @"FORM_TYPE" withValue: XMLNS_XMPP_MAM ];
                [fieldFormType addAttributeWithName:@"type" stringValue:@"hidden"];
                
                [filterForm addChild:fieldFormType];
                
                if(jid != nil)
                {
                    NSXMLElement *fieldJid = [self getFormField:@"with" withValue:jid.full];
                    [filterForm addChild:fieldJid];
                }
                
                if(startTime != nil)
                {
                    NSXMLElement *fieldStart = [self getFormField:@"start" withValue: startTime.xmppDateTimeString];
                    [filterForm addChild:fieldStart];
                }
                
                if(endTime != nil)
                {
                    NSXMLElement *fieldEnd = [self getFormField:@"end" withValue: endTime.xmppDateTimeString];
                    [filterForm addChild:fieldEnd];
                }
                
                [query addChild:filterForm];
            }
            
            if(resultSet != nil)
            {
                [query addChild: resultSet];
            }
            
            XMPPIQ *iq = nil;
            
            if (isMUC)
            {
                iq = [XMPPIQ iqWithType:@"set" to:jid elementID:elementID child:query];
            }
            else
            {
                iq = [XMPPIQ iqWithType:@"set" elementID:elementID child:query];
            }
            
            [xmppStream sendElement:iq];
            
            NSLog(@"XMPP Packet For MAM %@",iq);
            [responseTracker addID:elementID
                                 target:self
                                selector:@selector(mamResponse:withInfo:)
                                timeout:XMPPIDTrackerTimeoutNone];
        }};
    
    if (dispatch_get_specific(moduleQueueTag))
        block();
    else
        dispatch_async(moduleQueue, block);
}

- (void)mamResponse:(XMPPIQ *)iq withInfo:(XMPPBasicTrackingInfo *)trackerInfo
{
    NSLog(@"MAM Response From XMPP %@", iq);
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
    NSString *type = [iq type];
    
    if ([type isEqualToString:@"result"] || [type isEqualToString:@"error"])
    {
        return [responseTracker invokeForID:[iq elementID] withObject:iq];
    }
    
    return NO;
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
    // This method is invoked on the moduleQueue.
    [responseTracker removeAllIDs];
}

- (BOOL)activate:(XMPPStream *)aXmppStream
{
    if ([super activate:aXmppStream])
    {
        responseTracker = [[XMPPIDTracker alloc] initWithDispatchQueue:moduleQueue];
        
        return YES;
    }
    
    return NO;
}

- (void)deactivate
{    
    dispatch_block_t block = ^{ @autoreleasepool {

        [responseTracker removeAllIDs];
        responseTracker = nil;
        
    }};
    
    if (dispatch_get_specific(moduleQueueTag))
        block();
    else
        dispatch_sync(moduleQueue, block);
    
    [super deactivate];
}

@end

