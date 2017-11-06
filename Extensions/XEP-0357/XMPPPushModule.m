//
//  XMPPPushModule.m
//  ChatSecure
//
//  Created by Chris Ballinger on 2/27/17.
//  Copyright © 2017 Chris Ballinger. All rights reserved.
//

#import "XMPPPushModule.h"
#import "XMPPLogging.h"
#import "XMPPIDTracker.h"
#import "XMPPCapabilities.h"
#import "XMPPIQ+XEP_0357.h"
#import "XMPPInternal.h"

// Log levels: off, error, warn, info, verbose
#if DEBUG
static const int xmppLogLevel = XMPP_LOG_LEVEL_INFO | XMPP_LOG_FLAG_SEND_RECV; // | XMPP_LOG_FLAG_TRACE;
#else
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

@interface XMPPPushModule()
@property (nonatomic, strong, readonly) XMPPIDTracker *tracker;
/** Only access this from within the moduleQueue */
@property (nonatomic, strong, readonly) NSMutableSet <XMPPCapabilities*> *capabilitiesModules;
/** Prevents multiple requests. Only access this from within the moduleQueue */
@property (nonatomic, strong, readonly) NSMutableDictionary<XMPPJID*,NSNumber*> *registrationStatus;
@end

@implementation XMPPPushModule

#pragma mark Public API

/**
 * This value only reflects local in-memory status and will not check the server. It is reset to XMPPPushStatusUnknown after
 * re-authentication because some servers clear this value on new streams.
 */
- (XMPPPushStatus) registrationStatusForServerJID:(XMPPJID*)serverJID {
    NSParameterAssert(serverJID != nil);
    if (!serverJID) { return XMPPPushStatusUnknown; }
    __block XMPPPushStatus status = XMPPPushStatusUnknown;
    [self performBlock:^{
        NSNumber *number = [self.registrationStatus objectForKey:serverJID];
        status = number.unsignedIntegerValue;
    }];
    return status;
}

- (void) setRegistrationStatus:(XMPPPushStatus)registrationStatus forServerJID:(XMPPJID*)serverJID {
    NSParameterAssert(serverJID != nil);
    if (!serverJID) { return; }
    [self performBlockAsync:^{
        [self.registrationStatus setObject:@(registrationStatus) forKey:serverJID];
    }];
}

/** Manually refresh your push registration */
- (void) registerForPushWithOptions:(XMPPPushOptions*)options
                          elementId:(nullable NSString*)elementId {
    __weak typeof(self) weakSelf = self;
    __weak id weakMulticast = multicastDelegate;
    [self performBlockAsync:^{
        if ([self registrationStatusForServerJID:options.serverJID] == XMPPPushStatusRegistering) {
            XMPPLogVerbose(@"Already registering push options...");
            return;
        }
        NSString *eid = [self fixElementId:elementId];
        XMPPIQ *enableElement = [XMPPIQ enableNotificationsElementWithJID:options.serverJID node:options.node options:options.formOptions elementId:eid];
        [self.tracker addElement:enableElement block:^(XMPPIQ *responseIq, id<XMPPTrackingInfo> info) {
            __typeof__(self) strongSelf = weakSelf;
            if (!strongSelf) { return; }
            if (!responseIq || [responseIq isErrorIQ]) {
                // timeout
                XMPPLogWarn(@"refreshRegistration error: %@ %@", enableElement, responseIq);
                [strongSelf setRegistrationStatus:XMPPPushStatusError forServerJID:options.serverJID];
                [weakMulticast pushModule:strongSelf failedToRegisterWithErrorIq:responseIq outgoingIq:enableElement];
                return;
            }
            [strongSelf setRegistrationStatus:XMPPPushStatusRegistered forServerJID:options.serverJID];
            [weakMulticast pushModule:strongSelf didRegisterWithResponseIq:responseIq outgoingIq:enableElement];
        } timeout:30];
        [self setRegistrationStatus:XMPPPushStatusRegistering forServerJID:options.serverJID];
        [xmppStream sendElement:enableElement];
    }];
}

/** Disables push for a specified node on serverJID. Warning: If node is nil it will disable for all nodes (and disable push on your other devices) */
- (void) disablePushForServerJID:(XMPPJID*)serverJID
                            node:(nullable NSString*)node
                       elementId:(nullable NSString*)elementId {
    __weak typeof(self) weakSelf = self;
    __weak id weakMulticast = multicastDelegate;
    [self performBlockAsync:^{
        NSString *eid = [self fixElementId:elementId];
        XMPPIQ *disableElement = [XMPPIQ disableNotificationsElementWithJID:serverJID node:node elementId:eid];
        [self.tracker addElement:disableElement block:^(XMPPIQ *responseIq, id<XMPPTrackingInfo> info) {
            __typeof__(self) strongSelf = weakSelf;
            if (!strongSelf) { return; }
            if (!responseIq || [responseIq isErrorIQ]) {
                // timeout
                XMPPLogWarn(@"disablePush error: %@ %@", disableElement, responseIq);
                [strongSelf setRegistrationStatus:XMPPPushStatusError forServerJID:serverJID];
                [weakMulticast pushModule:strongSelf failedToDisablePushWithErrorIq:responseIq serverJID:serverJID node:node outgoingIq:disableElement];
                return;
            }
            [strongSelf setRegistrationStatus:XMPPPushStatusNotRegistered forServerJID:serverJID];
            [weakMulticast pushModule:strongSelf disabledPushForServerJID:serverJID node:node responseIq:responseIq outgoingIq:disableElement];
        } timeout:30];
        [xmppStream sendElement:disableElement];
    }];
}

#pragma mark Setup

- (BOOL)activate:(XMPPStream *)aXmppStream
{
    if ([super activate:aXmppStream])
    {
        [self performBlock:^{
            _registrationStatus = [NSMutableDictionary dictionary];
            _capabilitiesModules = [NSMutableSet set];
            [xmppStream autoAddDelegate:self delegateQueue:moduleQueue toModulesOfClass:[XMPPCapabilities class]];
            _tracker = [[XMPPIDTracker alloc] initWithStream:aXmppStream dispatchQueue:moduleQueue];
            
            [xmppStream enumerateModulesWithBlock:^(XMPPModule *module, NSUInteger idx, BOOL *stop) {
                if ([module isKindOfClass:[XMPPCapabilities class]]) {
                    [self.capabilitiesModules addObject:(XMPPCapabilities*)module];
                }
            }];
        }];
        return YES;
    }
    
    return NO;
}

- (void) deactivate {
    [self performBlock:^{
        [_tracker removeAllIDs];
        _tracker = nil;
        [xmppStream removeAutoDelegate:self delegateQueue:moduleQueue fromModulesOfClass:[XMPPCapabilities class]];
        _capabilitiesModules = nil;
        _registrationStatus = nil;
    }];
    [super deactivate];
}

#pragma mark XMPPStream Delegate

- (void) refresh {
    [self performBlockAsync:^{
        if (xmppStream.state != STATE_XMPP_CONNECTED) {
            XMPPLogError(@"XMPPPushModule: refresh error - not connected. %@", self);
            return;
        }
        [self.registrationStatus removeAllObjects];
        XMPPJID *jid = xmppStream.myJID.bareJID;
        if (!jid) { return; }
        __block BOOL supportsPush = NO;
        __block NSXMLElement *capabilities = nil;
        [self.capabilitiesModules enumerateObjectsUsingBlock:^(XMPPCapabilities * _Nonnull capsModule, BOOL * _Nonnull stop) {
            id <XMPPCapabilitiesStorage> storage = capsModule.xmppCapabilitiesStorage;
            BOOL fetched = [storage areCapabilitiesKnownForJID:jid xmppStream:xmppStream];
            if (fetched) {
                capabilities = [storage capabilitiesForJID:jid xmppStream:xmppStream];
                if (capabilities) {
                    supportsPush = [self supportsPushFromCaps:capabilities];
                    *stop = YES;
                }
            } else {
                [capsModule fetchCapabilitiesForJID:jid];
            }
        }];
        if (supportsPush) {
            [multicastDelegate pushModule:self readyWithCapabilities:capabilities jid:jid];
        }
    }];
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
    [self refresh];
}


- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq {
    BOOL success = NO;
    if (!iq.from) {
        // Some error responses for self or contacts don't have a "from"
        success = [self.tracker invokeForID:iq.elementID withObject:iq];
    } else {
        success = [self.tracker invokeForElement:iq withObject:iq];
    }
    //DDLogWarn(@"Could not match IQ: %@", iq);
    return success;
}

- (void)xmppStream:(XMPPStream *)sender didRegisterModule:(id)module
{
    if (![module isKindOfClass:[XMPPCapabilities class]]) {
        return;
    }
    [self performBlockAsync:^{
        [self.capabilitiesModules addObject:(XMPPCapabilities*)module];
    }];
    
}

- (void)xmppStream:(XMPPStream *)sender willUnregisterModule:(id)module
{
    if (![module isKindOfClass:[XMPPCapabilities class]]) {
        return;
    }
    [self performBlockAsync:^{
        [self.capabilitiesModules removeObject:(XMPPCapabilities*)module];
    }];
}

#pragma mark XMPPCapabilitiesDelegate

- (void)xmppCapabilities:(XMPPCapabilities *)sender didDiscoverCapabilities:(NSXMLElement *)caps forJID:(XMPPJID *)jid {
    XMPPLogVerbose(@"%@: %@\n%@:%@", THIS_FILE, THIS_METHOD, jid, caps);
    NSString *myDomain = [self.xmppStream.myJID domain];
    if ([[jid bare] isEqualToString:[jid domain]]) {
        if (![[jid domain] isEqualToString:myDomain]) {
            // You're checking the server's capabilities but it's not your server(?)
            return;
        }
    } else {
        if (![[self.xmppStream.myJID bare] isEqualToString:[jid bare]]) {
            // You're checking someone else's capabilities
            return;
        }
    }
    BOOL supportsXEP = [self supportsPushFromCaps:caps];
    if (supportsXEP) {
        [multicastDelegate pushModule:self readyWithCapabilities:caps jid:jid];
    }
}

#pragma mark Utility

/** Generate elementId UUID if needed */
- (nonnull NSString*) fixElementId:(nullable NSString*)elementId {
    NSString *eid = nil;
    if (!elementId.length) {
        eid = [[NSUUID UUID] UUIDString];
    } else {
        eid = [elementId copy];
    }
    return eid;
}

- (BOOL) supportsPushFromCaps:(NSXMLElement*)caps {
    __block BOOL supportsPushXEP = NO;
    NSArray <NSXMLElement*> *featureElements = [caps elementsForName:@"feature"];
    [featureElements enumerateObjectsUsingBlock:^(NSXMLElement * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *featureName = [obj attributeStringValueForName:@"var"];
        if ([featureName isEqualToString:XMPPPushXMLNS]){
            supportsPushXEP = YES;
            *stop = YES;
        }
    }];
    return supportsPushXEP;
}

@end

@implementation XMPPPushOptions

- (instancetype) initWithServerJID:(XMPPJID*)serverJID
                              node:(NSString*)node
                       formOptions:(NSDictionary<NSString*,NSString*>*)formOptions {
    NSParameterAssert(serverJID != nil);
    NSParameterAssert(node != nil);
    NSParameterAssert(formOptions != nil);
    if (self = [super init]) {
        _serverJID = [serverJID copy];
        _node = [node copy];
        _formOptions = [formOptions copy];
    }
    return self;
}

@end
