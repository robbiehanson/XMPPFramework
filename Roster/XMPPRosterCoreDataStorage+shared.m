//
//  XMPPRosterCoreDataStorage+shared.m
//  talk
//
//  Created by Eric Chamberlain on 10/2/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "XMPPRosterCoreDataStorage+shared.h"


@implementation XMPPRosterCoreDataStorage(shared)

+ (XMPPRosterCoreDataStorage *)sharedXMPPRosterCoreDataStorage {
    static XMPPRosterCoreDataStorage *_sharedXMPPRosterCoreDataStorage = nil;
    
    if (_sharedXMPPRosterCoreDataStorage == nil) {
        _sharedXMPPRosterCoreDataStorage = [[XMPPRosterCoreDataStorage alloc] init];
    }
    return _sharedXMPPRosterCoreDataStorage;
}

@end
