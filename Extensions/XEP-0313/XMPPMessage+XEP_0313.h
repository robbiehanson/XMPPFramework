//
//  XMPPMessage+XEP_0313.h
//  XMPPFramework
//
//  Created by Chris Ballinger on 10/23/17.
//  Copyright © 2017 Chris Ballinger. All rights reserved.
//

#import "XMPPMessage.h"

NS_ASSUME_NONNULL_BEGIN
@interface XMPPMessage (XEP_0313)
/** XEP-0313: MAM <result> element */
@property (nonatomic, nullable, readonly) NSXMLElement *mamResult;
@end
NS_ASSUME_NONNULL_END
