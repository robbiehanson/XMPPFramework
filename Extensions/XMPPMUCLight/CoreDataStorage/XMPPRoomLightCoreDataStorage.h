//
//  XMPPRoomLightCoreDataStorage.h
//  Mangosta
//
//  Created by Andres Canal on 6/8/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

#import <XMPPFramework/XMPPFramework.h>
#import <XMPPFramework/XMPPCoreDataStorage.h>
#import "XMPPRoomLight.h"

@interface XMPPRoomLightCoreDataStorage : XMPPCoreDataStorage <XMPPRoomLightStorage>

- (void)handleIncomingMessage:(XMPPMessage *)message room:(XMPPRoomLight *)room;
- (void)handleOutgoingMessage:(XMPPMessage *)message room:(XMPPRoomLight *)room;

@end
