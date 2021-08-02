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
#import "XMPPCapabilities.h"

/**
 * This XEP introduces unique and stable IDs for messages, which are beneficial in various ways. For example, they can be used together with Message Archive Management (XEP-0313) [1] to uniquely identify a message within an archive. They are also useful in the context of Multi-User Chat (XEP-0045) [2] conferences, as they allow to identify a message reflected by a MUC service back to the originating entity.
 * https://xmpp.org/extensions/xep-0359.html
 */

NS_ASSUME_NONNULL_BEGIN
@class XMPPStanzaId;
@interface XMPPMessage (XEP_0359)

/**
 * XEP-0359: Origin Id
 *
 * Usually this will be the same as the XMPPElement elementID, if present.
 * It is intended to be a unique identifier, useful for deduplication for MAM and MUC.
 */
@property (nonatomic, readonly, nullable) NSString *originId;

/**
 * XEP-0359: Origin Id
 *
 * This usually should be the same as the XMPPElement elementID.
 * It must be a unique identifier (UUID), and is useful for deduplication for MAM and MUC.
 *
 * @note If nil is passed for uniqueId, this method will generate a NSUUID.uuidString for the 'id' attribute.
 */
- (void) addOriginId:(nullable NSString*)originId;

/**
 * XEP-0359: Stanza Ids
 *
 * Usually there will be just one stanzaId, if supported,
 * but in the case of message receipts there can be more.
 * It will be a unique identifier, useful for deduplication for MAM and MUC.
 *
 * @note key=by, value=id
 *
 * @warn ⚠️ Do not trust this value without first checking XMPPCapabilities hasValidStanzaId:
 */
@property (nonatomic, readonly) NSDictionary<XMPPJID*,NSString*> *stanzaIds;

@end

NS_ASSUME_NONNULL_END
