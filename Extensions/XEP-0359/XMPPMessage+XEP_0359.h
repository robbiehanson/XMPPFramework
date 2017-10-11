//
//  XMPPMessage+XEP_0359.h
//  XMPPFramework
//
//  Created by Chris Ballinger on 10/10/17.
//  Copyright © 2017 Chris Ballinger. All rights reserved.
//

#import "XMPPMessage.h"
#import "XMPPElement.h"
#import "XMPPJID.h"

/**
 * This XEP introduces unique and stable IDs for messages, which are beneficial in various ways. For example, they can be used together with Message Archive Management (XEP-0313) [1] to uniquely identify a message within an archive. They are also useful in the context of Multi-User Chat (XEP-0045) [2] conferences, as they allow to identify a message reflected by a MUC service back to the originating entity.
 * https://xmpp.org/extensions/xep-0359.html
 */

NS_ASSUME_NONNULL_BEGIN
@interface XMPPMessage (XEP_0359)

/** XEP-0359: Checks that the `by` attribute matches `from` */
@property (nonatomic, readonly) BOOL hasValidStanzaId;

/** XEP-0359: Stanza Id */
@property (nonatomic, readonly, nullable) NSString *stanzaId;
/** XEP-0359: Origin Id */
@property (nonatomic, readonly, nullable) NSString *originId;
/** XEP-0359: Stanza Id By */
@property (nonatomic, readonly, nullable) XMPPJID *stanzaIdBy;

@end


NS_ASSUME_NONNULL_END
