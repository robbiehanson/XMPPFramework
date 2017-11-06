//
//  NSXMLElement+XEP_0359.h
//  XMPPFramework
//
//  Created by Chris Ballinger on 10/10/17.
//  Copyright © 2017 robbiehanson. All rights reserved.
//

#import "XMPPElement.h"
#import "XMPPJID.h"

NS_ASSUME_NONNULL_BEGIN

/** 'urn:xmpp:sid:0' */
extern NSString *const XMPPStanzaIdXmlns;
/** 'stanza-id' */
extern NSString *const XMPPStanzaIdElementName;
/** 'origin-id' */
extern NSString *const XMPPOriginIdElementName;


@interface NSXMLElement (XEP_0359)

/**
 * Some use cases require the originating entity, e.g. a client, to generate the stanza ID. In this case, the client MUST use the <origin-id/> element extension element qualified by the 'urn:xmpp:sid:0' namespace. Note that originating entities often want to conceal their XMPP address and therefore the <origin-id/> element has no 'by' attribute.
 *
 *   Ex: <origin-id xmlns='urn:xmpp:sid:0' id='de305d54-75b4-431b-adb2-eb6b9e546013'/>
 *
 * @note This method will generate a NSUUID.uuidString for the 'id' attribute.
 */
+ (instancetype) originIdElement;
/** @note If nil is passed for uniqueId, this method will generate a NSUUID.uuidString for the 'id' attribute. */
+ (instancetype) originIdElementWithUniqueId:(nullable NSString*)uniqueId;

@end
NS_ASSUME_NONNULL_END
