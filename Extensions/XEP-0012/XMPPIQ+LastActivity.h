//
//  XMPPIQ+LastActivity.h
//  XEP-0012
//
//  Created by Daniel Rodríguez Troitiño on 1/26/2013.
//

#import <Foundation/Foundation.h>

#import "XMPPIQ.h"

@class XMPPJID;

/**
 * Last Activity XEP-0012 namespace: "jabber:iq:last".
 */
extern NSString *const XMPPLastActivityNamespace;

/**
 * Helper methods to create last activity queries inside IQ stanzas or to
 * inspect result IQ answering last activity queries.
 */
@interface XMPPIQ (LastActivity)

/**
 * Returns an get XMPPIQ with a last activity query child element addressed to
 * the given JID.
 */
+ (XMPPIQ *)lastActivityQueryTo:(XMPPJID *)jid;

/**
 * Returns a result XMPPIQ answering the given XMPPIQ request with the given
 * number of seconds.
 *
 * The from and to attributes of the returned XMPPIQ will be switched from the
 * from and to attributes of the given request. The element ID will be the same
 * of the given request. No status message will be included.
 */
+ (XMPPIQ *)lastActivityResponseToIQ:(XMPPIQ *)request withSeconds:(NSUInteger)seconds;

/**
 * Returns a result XMPPIQ answering the given XMPPIQ request with the given
 * number of seconds and the given unavailable status.
 *
 * The from and to attributes of the returned XMPPIQ will be switched from the
 * from and to attributes of the given request. The element ID will be the same
 * of the given request.
 */
+ (XMPPIQ *)lastActivityResponseToIQ:(XMPPIQ *)request withSeconds:(NSUInteger)seconds status:(NSString *)status;

/**
 * Returns an error XMPPIQ answering the given XMPPIQ request.
 *
 * The from and to attributes of the returned XMPPIQ will be switched from the
 * from and to attributes of the given request. The element ID will be the same
 * of the given request.
 *
 * An error element with a forbidden element will be included as child element:
 *
 * <iq from='juliet@capulet.com'
 *     id='last1'
 *     to='romeo@montague.net/orchard'
 *     type='error'>
 *   <error type='auth'>
 *     <forbidden xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
 *   </error>
 *  </iq>
 */
+ (XMPPIQ *)lastActivityResponseForbiddenToIQ:(XMPPIQ *)request;

/**
 * Returns YES if the child element of this XMPPIQ is a query element from the
 * XMPPLastActivityNamespace. Otherwise returns NO.
 */
- (BOOL)isLastActivityQuery;

/**
 * Returns the parsed number from the seconds attribute of the query subelement.
 *
 * Returns NSNotFound in case this XMPPIQ has no query element, or that query
 * element does not have a seconds attribute. Returns 0 in case the seconds
 * attribute cannot be parsed as a integer.
 */
- (NSUInteger)lastActivitySeconds;

/**
 * Returns the contents of the query subelement.
 *
 * Returns nil in case this XMPPIQ has no query element, or the query element
 * does not have contents.
 */
- (NSString *)lastActivityUnavailableStatus;

@end
