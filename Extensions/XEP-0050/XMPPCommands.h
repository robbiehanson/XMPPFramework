//
//  XMPPCommands.h
//  iPhoneXMPP
//
//  Created by Rick Mellor on 1/29/13.
//
//

#import "XMPP.h"
#import "XMPPDisco.h"

#define XMPP_FEATURE_CMDS  @"http://jabber.org/protocol/commands"

@interface XMPPCommands : XMPPModule
{
    NSXMLElement *myDiscoCommandsQuery;
    XMPPDisco *xmppDisco;
    
    BOOL collectingMyDiscoCommands;
}

- (BOOL)activate:(XMPPStream *)aXmppStream withXMPPDisco:(XMPPDisco*)aXmppDisco;
- (void)getEndpointCommandsList:(XMPPJID *)jid;
- (void)executeCommand:(NSString*)command withType:(NSString*)type onEndpoint:(XMPPJID*)jid withXData:(NSXMLElement*)xData;
- (void)returnExecutionResult:(NSXMLElement *)data toEndpoint:(XMPPJID*)endpoint forCommand:(NSString*)command withStatus:(NSString*)status;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPCommandsDelegate
@optional

/**
 * Use this delegate method to add specific capabilities.
 * This method in invoked automatically when the stream is connected for the first time,
 * or if the module detects an outgoing presence element and my capabilities haven't been collected yet
 *
 * The design of XEP-115 is such that capabilites are expected to remain rather static.
 * However, if the capabilities change, the recollectMyCapabilities method may be used to perform a manual update.
 **/
- (void)xmppCommands:(XMPPCommands *)sender collectingMyDiscoCommands:(NSXMLElement *)commandsQuery;

/**
 * Invoked when identity/feature info have been discovered for an available JID.
 *
 * The discoInfo element is the <query/> element response to a disco#info request.
 **/
- (void)xmppCommands:(XMPPCommands *)sender didReceiveCommandsList:(NSXMLElement *)commandsList forJID:(XMPPJID *)forJID;

/**
 * Invoked when items have been returned in response to an items disco query.
 *
 * The discoItems element is the <query/> element response to a disco#items request.
 **/
- (void)xmppCommands:(XMPPCommands *)sender executeCommand:(NSString *)command fromJID:(XMPPJID *)fromJID withXData:(NSXMLElement *)xData;

/**
 * Invoked when identity/feature disco failed and we recieved an error response.
 *
 * The errorInfo element is the <error/> element response to a disco#info request.
 **/
- (void)xmppCommands:(XMPPCommands *)sender receivedCommandResult:(NSString*)status fromEndpoint:(XMPPJID*)fromJID forCommand:(NSString*)node
       withSessionId:(NSString*)sessionid andPayload:(NSXMLElement*)xmlPayload;

@end