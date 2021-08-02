//
//  XMPPURI.h
//  XMPPFramework
//
//  Created by Christopher Ballinger on 5/15/15.
//  Copyright (c) 2015 Chris Ballinger. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XMPPJID.h"

/** 
 *  For parsing and creating XMPP URIs RFC5122/XEP-0147
 *  e.g. xmpp:username@domain.com?subscribe 
 *  http://www.xmpp.org/extensions/xep-0147.html
 */
NS_ASSUME_NONNULL_BEGIN
@interface XMPPURI : NSObject

/**
 * User JID. e.g. romeo@montague.net
 * Example: xmpp:romeo@montague.net
 */
@property (nonatomic, strong, readonly, nullable) XMPPJID *jid;

/**
 * Account JID. (Optional)
 * Used to specify an account with which to perform an action.
 * For example 'guest@example.com' would be the authority portion of
 *    xmpp://guest@example.com/support@example.com?message
 * so the application would show a dialog with an outgoing message
 * to support@example.com from the user's account guest@example.com.
 */
@property (nonatomic, strong, readonly, nullable) XMPPJID *accountJID;

/** 
 * XMPP query action. e.g. subscribe
 * For example, the query action below would be 'subscribe'
 *    xmpp:romeo@montague.net?subscribe
 * For full list: http://xmpp.org/registrar/querytypes.html
 */
@property (nonatomic, strong, readonly, nullable) NSString *queryAction;

/**
 * XMPP query parameters. e.g. subject=Test
 *
 * For example the query parameters for
 *     xmpp:romeo@montague.net?message;subject=Test%20Message;body=Here%27s%20a%20test%20message
 * would be
 * {"subject": "Test Message",
 *  "body": "Here's a test message"}
 */
@property (nonatomic, strong, readonly, nullable) NSDictionary<NSString*, NSString*> *queryParameters;

/** 
 * Generates URI string from jid, queryAction, and queryParameters
 * e.g. xmpp:romeo@montague.net?subscribe 
 */
- (nullable NSString*) uriString;

// Parsing XMPP URIs
- (instancetype) initWithURL:(NSURL*)url;
- (instancetype) initWithURIString:(NSString*)uriString;

// Creating XMPP URIs
- (instancetype) initWithJID:(XMPPJID*)jid
                 queryAction:(NSString*)queryAction
             queryParameters:(nullable NSDictionary<NSString*, NSString*>*)queryParameters;

@end
NS_ASSUME_NONNULL_END
