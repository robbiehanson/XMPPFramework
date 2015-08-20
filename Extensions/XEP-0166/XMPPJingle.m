//
//  XMPPJingle.m
//  xfinity-webrtc-sdk
//
//  Created by Ganvir, Manish  on 2/5/15.
//

/* The purpose of this extension is to use jingle protocol as described in
 * http://xmpp.org/extensions/xep-0166.html and handle the urn urn:xmpp:jingle
 * and manage the messages such as session-initiate, session-accept
 * session-terminate.
 * This extension will also extract SDP and candidates so that a SIP/Webrtc
 * call can work.
 * It will provide an extension which will do translation of XMPP based message
 * to \r\n based SDP messages.
 * The delegate will send the SDP messages to the application later and API
 * calls will allow to send SDP message to XMPP
 */
#import "XMPP.h"
#import "XMPPFramework.h"
#import "XMPPJingle.h"
#import "XMPPJingleSDP.h"


@interface XMPPJingle()
{
    BOOL enableLogging;
    XMPPJingleSDPUtil *sdpUtil;
}
- (NSString *)ParseSDP:(XMPPIQ *)iq;

// Called when a session-initiate message is received
- (void)onSessionInitiate:(XMPPIQ *)iq;

// Called when a session-info message is received
- (void)onSessionInfo:(XMPPIQ *)iq;

// Called when a session-accept message is received
- (void)onSessionAccept:(XMPPIQ *)iq;

// Called when a session-terminate message is received
- (void)onSessionTerminate:(XMPPIQ *)iq;

// Called when a transport-accept message is received
- (void)onTransportAccept:(XMPPIQ *)iq;

// Called when a transport-info message is received
- (void)onTransportInfo:(XMPPIQ *)iq;

// Called when a transport-reject message is received
- (void)onTransportReject:(XMPPIQ *)iq;

// Called when a transport-replace message is received
- (void)onTransportReplace:(XMPPIQ *)iq;

// Called when a content-accept message is received
- (void)onContentAccept:(XMPPIQ *)iq;

// Called when a content-add message is received
- (void)onContentAdd:(XMPPIQ *)iq;

// Called when a content-modify message is received
- (void)onContentModify:(XMPPIQ *)iq;

// Called when a content-reject message is received
- (void)onContentReject:(XMPPIQ *)iq;

// Called when a content-remove message is received
- (void)onContentRemove:(XMPPIQ *)iq;

// Called when a description-info message is received
- (void)onDescriptionInfo:(XMPPIQ *)iq;
@end

@implementation XMPPJingle

#pragma mark - XMPP module related methods

// Init
- (id)init
{
    _delegate = nil;
    enableLogging = NO;
    sdpUtil = [[XMPPJingleSDPUtil alloc]init];
    UID = [XMPPStream generateUUID];
    SID = [[UID substringToIndex:12] lowercaseString];
    return [self initWithDispatchQueue:NULL];
}

// Init with queue
- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
    _delegate = nil;
    enableLogging = NO;
    sdpUtil = [[XMPPJingleSDPUtil alloc]init];
    UID = [XMPPStream generateUUID];
    SID = [[UID substringToIndex:12] lowercaseString];
    if ((self = [super initWithDispatchQueue:queue]))
    {
    }
    return self;
}

// Activate module
- (BOOL)activate:(XMPPStream *)aXmppStream
{
    if ([super activate:aXmppStream])
    {
        myStream = aXmppStream;
#ifdef _XMPP_CAPABILITIES_H
        [xmppStream autoAddDelegate:self delegateQueue:moduleQueue toModulesOfClass:[XMPPCapabilities class]];
#endif
        [self initialize];
        return YES;
    }
    
    return NO;
}

// Deactivate module
- (void)deactivate
{
    [super deactivate];
}



#pragma mark - Public methods

// Set delegate method
- (void)SetDelegate:(id <XMPPJingleDelegate>)appDelegate;
{
    // Set delegate
    _delegate = appDelegate;
}

// Set delegate method
- (void)SetLoggingFlag:(BOOL)enable;
{
    // Set delegate
    enableLogging = YES;
}

// For Action (type) attribute: "session-accept", "session-info", "session-initiate", "session-terminate"
- (BOOL)sendSessionMsg:(NSString *)type  data:(NSDictionary *)data target:(XMPPJID *)target
{
    // Parse SDP
    if ([type isEqualToString:@"session-initiate"])
    {
        XMPPIQ *sdp = [sdpUtil SDPToXMPP:[data objectForKey:@"sdp"] action:type initiator:[myStream myJID] target:target UID:UID SID:SID];
        if (sdp != nil)
            [myStream sendElement:sdp];
    }
    else if ([type isEqualToString:@"session-accept"])
    {
        XMPPIQ *sdp = [sdpUtil SDPToXMPP:[data objectForKey:@"sdp"] action:type initiator:[myStream myJID] target:target UID:UID SID:SID];
        if (sdp != nil)
            [myStream sendElement:sdp];
    }
    
    return true;
}

- (NSXMLElement*) getVideoContent:(NSString *)type  data:(NSDictionary *)data target:(XMPPJID *)target
{
    return [sdpUtil MediaToXMPP:type data:data target:target UID:UID SID:SID];    
}

// For Action (type) attribute: "transport-accept", "transport-info", "transport-reject", "transport-replace"
- (BOOL)sendTransportMsg:(NSString *)type  data:(NSDictionary *)data target:(XMPPJID *)target
{
    // Parse SDP
    if ([type isEqualToString:@"transport-info"])
    {
        XMPPIQ *candidate = [sdpUtil CandidateToXMPP:data action:type initiator:target/*[myStream myJID]*/ target:target UID:UID SID:SID];
        if (candidate != nil)
            [myStream sendElement:candidate];
    }
    return true;
}

// For Action (type) attribute: "content-accept", "content-add", "content-modify", "content-reject", "content-remove"
- (BOOL)sendContentMsg:(NSString *)type data:(NSDictionary *)data
{
    return true;
}

// For Action (type) attribute: "description-info"
- (BOOL)sendDescriptionMsg:(NSString *)type data:(NSDictionary *)data
{
    return true;
}

#pragma mark - Internal methods

- (void)initialize
{
    // This extension has been activated, so start listening to the messages
}

// Called when a session-initiate message is received
- (void)onSessionInitiate:(XMPPIQ *)iq sid:(NSString *)sid
{
    // Parse SDP
    NSString *sdp = [sdpUtil XMPPToSDP:iq];
    
    // Prepare the JSON dictionary
    NSMutableDictionary * jsonDict = [[NSMutableDictionary alloc] init];
    [jsonDict setValue:sdp forKey:@"sdp"];
    //[jsonDict setValue:iq.fromStr forKey:@"from"];
    [jsonDict setValue:from forKey:@"from"];
    //[jsonDict setValue:iq.toStr forKey:@"to"];
    [jsonDict setValue:to forKey:@"to"];
    
    // Set the sid if it exists
    NSString *sessionid = [[iq elementForName:@"jingle"] attributeStringValueForName:@"sid"  ];
    if (sessionid)
    {
        SID = sessionid;
    }
    // post the message to delegate
    [self.delegate didReceiveSessionMsg:sid type:@"session-initiate" data:jsonDict];
    
}

// Called when a session-info message is received
- (void)onSessionInfo:(XMPPIQ *)iq sid:(NSString *)sid
{
    // TBD
}

// Called when a session-accept message is received
- (void)onSessionAccept:(XMPPIQ *)iq sid:(NSString *)sid
{
    // Parse SDP
    NSString *sdp = [sdpUtil XMPPToSDP:iq];
    
    // Prepare the JSON dictionary
    NSMutableDictionary * jsonDict = [[NSMutableDictionary alloc] init];
    [jsonDict setValue:sdp forKey:@"sdp"];
    [jsonDict setValue:iq.fromStr forKey:@"from"];
    [jsonDict setValue:iq.toStr forKey:@"to"];
    
    
    // post the message to delegate
    [self.delegate didReceiveSessionMsg:sid type:@"session-accept" data:jsonDict];
}

// Called when a session-terminate message is received
- (void)onSessionTerminate:(XMPPIQ *)iq sid:(NSString *)sid
{
    
}

// Called when a transport-accept message is received
- (void)onTransportAccept:(XMPPIQ *)iq
{
    
}

// Called when a transport-info message is received
- (void)onTransportInfo:(XMPPIQ *)iq
{
    // Parse SDP
    NSDictionary *candidate = [sdpUtil XMPPToCandidate:iq];

    // post the message to delegate
    [self.delegate didReceiveTransportMsg:[candidate objectForKey:@"sid"] type:@"transport-info" data:candidate];
}

// Called when a transport-reject message is received
- (void)onTransportReject:(XMPPIQ *)iq
{
    
}

// Called when a transport-replace message is received
- (void)onTransportReplace:(XMPPIQ *)iq
{
    
}

// Called when a content-accept message is received
- (void)onContentAccept:(XMPPIQ *)iq
{
    
}

// Called when a content-add message is received
- (void)onContentAdd:(XMPPIQ *)iq
{
    
}

// Called when a content-modify message is received
- (void)onContentModify:(XMPPIQ *)iq
{
    
}

// Called when a content-reject message is received
- (void)onContentReject:(XMPPIQ *)iq
{
    
}

// Called when a content-remove message is received
- (void)onContentRemove:(XMPPIQ *)iq
{
    
}

// Called when a description-info message is received
- (void)onDescriptionInfo:(XMPPIQ *)iq
{
    
}

// Called when a source-add message is received
- (void)onSourceAdd:(XMPPIQ *)iq
{
    // Parse SDP
    /*NSString *sdp = [sdpUtil XMPPToSDP:iq];
    
    // Prepare the JSON dictionary
    NSMutableDictionary * jsonDict = [[NSMutableDictionary alloc] init];
    [jsonDict setValue:sdp forKey:@"sdp"];
    [jsonDict setValue:iq.fromStr forKey:@"from"];
    [jsonDict setValue:iq.toStr forKey:@"to"];*/
    
   [self.delegate didReceiveSessionMsg:nil type:@"source-add" data:nil];
}


# pragma mark - XMPP stream methods

// Called when a iq message is received
- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
    NSLog(@"XMPP : Jingle : didReceiveIQ %@", iq.description);

    // Check if it is a jingle message
    NSXMLElement *jingleElement = [iq elementForName:@"jingle" xmlns:XEP_0166_XMLNS];
    
    // We are only looking for jingle related messages
    if (jingleElement == nil)
        return NO;
    
    from = iq.fromStr;
    to = iq.toStr;
    
    // Check the type of the message
    NSString *type = [jingleElement attributeStringValueForName:@"action"];
    
    // If the message doesnt have a type, dont parser
    if (type == nil)
        return NO;
    
    NSLog(@"XMPP : Jingle : didReceiveIQ :: Got a jingle message %@ of type %@", jingleElement, type);
    
    // Based on
    if ([type isEqualToString:@"session-initiate"])
    {
        [self onSessionInitiate:iq sid:[jingleElement attributeStringValueForName:@"sid"]];
    }
    else if ([type isEqualToString:@"session-info"])
    {
        [self onSessionAccept:iq sid:[jingleElement attributeStringValueForName:@"sid"]];
    }
    else if ([type isEqualToString:@"session-accept"])
    {
        [self onSessionAccept:iq sid:[jingleElement attributeStringValueForName:@"sid"]];
    }
    else if ([type isEqualToString:@"session-terminate"])
    {
        [self onSessionTerminate:iq];
    }
    else if ([type isEqualToString:@"transport-accept"])
    {
        [self onTransportAccept:iq];
    }
    else if ([type isEqualToString:@"transport-info"])
    {
        [self onTransportInfo:iq];
    }
    else if ([type isEqualToString:@"transport-reject"])
    {
        [self onTransportReject:iq];
    }
    else if ([type isEqualToString:@"transport-replace"])
    {
        [self onTransportReplace:iq];
    }
    else if ([type isEqualToString:@"content-accept"])
    {
        [self onContentAccept:iq];
    }
    else if ([type isEqualToString:@"content-add"])
    {
        [self onContentAdd:iq];
    }
    else if ([type isEqualToString:@"content-modify"])
    {
        [self onContentModify:iq];
    }
    else if ([type isEqualToString:@"content-reject"])
    {
        [self onContentReject:iq];
    }
    else if ([type isEqualToString:@"content-remove"])
    {
        [self onContentRemove:iq];
    }
    else if ([type isEqualToString:@"description-info"])
    {
        [self onDescriptionInfo:iq];
    }
    else if ([type isEqualToString:@"source-add"])
    {
        [self onSourceAdd:iq];
    }
    else
    {
        NSLog(@"XMPP : Jingle : didReceiveIQ :: Not a jingle message type %@",  type);
        return NO;
    }

    XMPPIQ *iqResponse = [XMPPIQ iqWithType:@"result" to:[iq from] elementID:[iq elementID]];
    [xmppStream sendElement:iqResponse];

    // Check if we have received a IQ for jingle
    //if (iq.namespaces)

    return YES;
}

// Called when a message is received
- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
    NSLog(@"XMPP : Jingle : didReceiveMessage %@", message.description);
    
    //TBD
}

// Called when a presence message is received
- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
    NSLog(@"XMPP : Jingle : didReceivePresence %@", presence.description);
    
    //TBD

    
}

@end
