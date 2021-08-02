//
//  XMPPCapabilities+XEP_0359.h
//  XMPPFramework
//
//  Created by Chris Ballinger on 10/11/17.
//  Copyright © 2017 Chris Ballinger. All rights reserved.
//

#import "XMPPCapabilities.h"
#import "XMPPMessage.h"

NS_ASSUME_NONNULL_BEGIN
@interface XMPPCapabilities (XEP_0359)

/**
 * Whether or not the stanza-id can be trusted.
 *
 * Before processing the stanza ID of a message and using it for deduplication purposes or for MAM catchup, the receiving entity SHOULD ensure that the stanza ID could not have been faked, by verifying that the entity referenced in the by attribute does annouce the 'urn:xmpp:sid:0' namespace in its disco features.
 *
 * The value of the 'by' attribute MUST be the XMPP address of the entity assigning the unique and stable stanza ID. For one-on-one messages the assigning entity is the account. In groupchats the assigning entity is the room. Note that XMPP addresses are normalized as defined in RFC 6122 [4].
 */
- (BOOL) hasValidStanzaId:(XMPPMessage*)message;

@end
NS_ASSUME_NONNULL_END
