//
//  XMPPLastActivity.h
//  XEP-0012
//
//  Created by Daniel Rodríguez Troitiño on 1/26/2013.
//
//

#import "XMPP.h"
#import "XMPPIQ+LastActivity.h"

#define _XMPP_LAST_ACTIVITY_H

/**
 * Provides support to both sending last activity queries and answering those
 * last activity queries done by other entities, as documented in the XEP-0012.
 *
 * The automatic responses can be disabled setting respondsToQueries to NO.
 *
 * If no delegate of this class responds to
 * numberOfIdleTimeSecondsForXMPPLastActivity:currentIdleTimeSeconds: a default
 * value of 0 will be send to the other entities. You are encouraged to provide
 * at least one delegate with this method implemented.
 */
@interface XMPPLastActivity : XMPPModule

/**
 * Whether or not the module should respond to incoming last activity queries.
 *
 * If you create multiple instances of this module, only one instance should
 * respond to queries.
 *
 * It is recommended you set this (if needed) before you activate the module.
 *
 * The default value is YES.
 */
@property (atomic, assign) BOOL respondsToQueries;

/**
 * Send a last activity query to an specific JID.
 *
 * XEP-0012 specifies that last activity queries can be send to offline
 * entities (bare JID), to online resources (full JID) or servers (domain only
 * JID). The answers of each of those kind of JIDs are a little different and
 * has different meaning. It is responsability of the consumer to interpretate
 * those answers.
 *
 * The module will wait for an answer from the server or the entity for at most
 * 30 seconds before considering this request a timeout failure.
 *
 * The delegates of the module should implement
 * xmppLastActivity:didReceiveResponse: and
 * xmppLastActivity:didNotReceiveResponse:dueToTimeout: to be informed when the
 * result of the IQ arrives (or the timeout happens).
 *
 * The returning string is the element ID of the IQ that was sent including the
 * last activity query.
 */
- (NSString *)sendLastActivityQueryToJID:(XMPPJID *)jid;

/**
 * Send a last activity query to an specific JID with an specific timeout.
 *
 * XEP-0012 specifies that last activity queries can be send to offline
 * entities (bare JID), to online resources (full JID) or servers (domain only
 * JID). The answers of each of those kind of JIDs are a little different and
 * has different meaning. It is responsability of the consumer to interpretate
 * those answers.
 *
 * The module will wait for an answer from the server or the entity for at most
 * the number seconds given by tiemout before considering this request a timeout
 * failure.
 *
 * The delegates of the module should implement
 * xmppLastActivity:didReceiveResponse: and
 * xmppLastActivity:didNotReceiveResponse:dueToTimeout: to be informed when the
 * result of the IQ arrives (or the timeout happens).
 *
 * The returning string is the element ID of the IQ that was sent including the
 * last activity query.
 */
- (NSString *)sendLastActivityQueryToJID:(XMPPJID *)jid withTimeout:(NSTimeInterval)timeout;

@end

@protocol XMPPLastActivityDelegate <NSObject>

/**
 * Callback when the XMPPLastActivity sender receives a result IQ or an error IQ
 * for a previous get IQ.
 *
 * The XMPPIQ response can be queried using the methods in the category
 * XMPPIQ (LastActivity) for the seconds and status value.
 */
- (void)xmppLastActivity:(XMPPLastActivity *)sender didReceiveResponse:(XMPPIQ *)response;

/**
 * Callback when the XMPPLastActivity sender does not receive neither a result
 * IQ nor a error IQ after timeout seconds have passed.
 *
 * The queryID is the element ID used to send the query, so the consumer can
 * compare it with the element ID returned by the sendLastActivityQueryToJID:
 * methods and act accordingly.
 */
- (void)xmppLastActivity:(XMPPLastActivity *)sender didNotReceiveResponse:(NSString *)queryID dueToTimeout:(NSTimeInterval)timeout;

/**
 * Callback to obtain the number of idle seconds that the XMPPLastActivity
 * sender should use as answer to a last activity query iq.
 *
 * Each delegate will be asked in turn (the order is not guaranteed) and each of
 * then should decide to return the given idleSeconds value, or a new value as
 * the number of idleSeconds. The first delegate will receive NSNotFound as the
 * value of idleSecond. If the last delegate returns NSNotFound as result, the
 * answer will be 0 seconds.
 */
- (NSUInteger)numberOfIdleTimeSecondsForXMPPLastActivity:(XMPPLastActivity *)sender queryIQ:(XMPPIQ *)iq currentIdleTimeSeconds:(NSUInteger)idleSeconds;

@end
