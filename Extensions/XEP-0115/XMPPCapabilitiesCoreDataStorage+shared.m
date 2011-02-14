//
//  XMPPCapabilitiesCoreDataStorage+shared.m
//  talk
//
//  Created by Eric Chamberlain on 10/2/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "XMPPCapabilitiesCoreDataStorage+shared.h"


@implementation XMPPCapabilitiesCoreDataStorage(shared)

+ (XMPPCapabilitiesCoreDataStorage *)sharedXMPPCapabilitiesCoreDataStorage {
    static XMPPCapabilitiesCoreDataStorage *_sharedXMPPCapabilitiesCoreDataStorage = nil;
    
    if (_sharedXMPPCapabilitiesCoreDataStorage == nil) {
        _sharedXMPPCapabilitiesCoreDataStorage = [[XMPPCapabilitiesCoreDataStorage alloc] init];
    }
    return _sharedXMPPCapabilitiesCoreDataStorage;
    
}

@end
