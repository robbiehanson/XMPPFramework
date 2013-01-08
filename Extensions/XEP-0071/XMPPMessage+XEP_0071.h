//
//  XMPPMessage+XEP_0071.h
//
//  Created by Indragie Karunaratne on 2013-01-08.
//  Copyright (c) 2013 Indragie Karunaratne. All rights reserved.
//

#import "XMPPMessage.h"
#import "NSXMLElement+XMPP.h"

/* Simple implementatio of the XEP-0071 extension to implement support
 for lightweight text attributes. This implementation generates HTML
 that uses a style attribute to style the text. Not all elements supported
 by XEP-0071 are supported. The following style properties are supported:
 
- background-color
- color
- font-family
- font-size
- font-style
- font-weight
- text-align
- text-decoration
*/

@interface XMPPMessage (XEP_0071)
@property (nonatomic, strong) NSAttributedString *attributedBody;
@end
