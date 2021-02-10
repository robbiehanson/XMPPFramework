//
//  XMPPPresence+XEP_0153.h
//
//  Created by Indragie Karunaratne on 2013-01-08.
//  Copyright (c) 2013 Indragie Karunaratne. All rights reserved.
//

#import "XMPPPresence.h"

@interface XMPPPresence (XEP_0153)
// SHA1 hash of the photo data for the handle that sent this presence
// This can be used to selectively fetch vCards only if the photo
// hash has been updated
@property (nonatomic, retain) NSString *photoHash;
@end
