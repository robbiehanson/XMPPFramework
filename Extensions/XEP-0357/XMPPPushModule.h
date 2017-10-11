//
//  XMPPPushModule.h
//  ChatSecure
//
//  Created by Chris Ballinger on 2/27/17.
//  Copyright © 2017 Chris Ballinger. All rights reserved.
//

#import "XMPPModule.h"
#import "XMPPJID.h"
#import "XMPPIQ.h"

@import KissXML;

@class XMPPPushOptions;

typedef NS_ENUM(NSUInteger, XMPPPushStatus) {
    XMPPPushStatusUnknown,
    XMPPPushStatusNotRegistered,
    XMPPPushStatusRegistering,
    XMPPPushStatusRegistered,
    XMPPPushStatusError
};

NS_ASSUME_NONNULL_BEGIN
@interface XMPPPushModule : XMPPModule

/** 
 * This value only reflects local in-memory status and will not check the server. It is reset to XMPPPushStatusUnknown after
 * re-authentication because some servers clear this value on new streams.
 */
- (XMPPPushStatus) registrationStatusForServerJID:(XMPPJID*)serverJID;

/** Manually update your push registration. */
- (void) registerForPushWithOptions:(XMPPPushOptions*)options
                          elementId:(nullable NSString*)elementId;

/** Disables push for a specified node on serverJID. Warning: If node is nil it will disable for all nodes (and disable push on your other devices) */
- (void) disablePushForServerJID:(XMPPJID*)serverJID
                            node:(nullable NSString*)node
                       elementId:(nullable NSString*)elementId;

/** This will trigger the same logic as xmppStreamDidAuthenticate: */
- (void) refresh;

@end

/** Multicast delegate methods */
@protocol XMPPPushDelegate <NSObject>
@optional

/** This is called after capabilities are processed so you can safely call registerForPushWithOptions or  disablePush */
- (void)pushModule:(XMPPPushModule*)module readyWithCapabilities:(NSXMLElement *)caps jid:(XMPPJID *)jid;

- (void)pushModule:(XMPPPushModule*)module
didRegisterWithResponseIq:(XMPPIQ*)responseIq
        outgoingIq:(XMPPIQ*)outgoingIq;

- (void)pushModule:(XMPPPushModule*)module
failedToRegisterWithErrorIq:(nullable XMPPIQ*)errorIq
        outgoingIq:(XMPPIQ*)outgoingIq;

- (void)pushModule:(XMPPPushModule*)module
disabledPushForServerJID:(XMPPJID*)serverJID
              node:(nullable NSString*)node
        responseIq:(XMPPIQ*)responseIq
        outgoingIq:(XMPPIQ*)outgoingIq;

- (void)pushModule:(XMPPPushModule*)module
failedToDisablePushWithErrorIq:(nullable XMPPIQ*)errorIq
         serverJID:(XMPPJID*)serverJID
              node:(nullable NSString*)node
        outgoingIq:(XMPPIQ*)outgoingIq;

@end

@interface XMPPPushOptions : NSObject
/** Maps to FORM_OPTIONS. This could include the device token, secret value, etc. */
@property (nonatomic, strong, readonly) NSDictionary<NSString*,NSString*> *formOptions;
/** This should be a unique, persistent value for this app install. */
@property (nonatomic, strong, readonly) NSString *node;
/** The server JID that's running the pubsub node */
@property (nonatomic, strong, readonly) XMPPJID *serverJID;

- (instancetype) initWithServerJID:(XMPPJID*)serverJID
                              node:(NSString*)node
                       formOptions:(NSDictionary<NSString*,NSString*>*)formOptions;
@end
NS_ASSUME_NONNULL_END
