//
//  XMPPTBRAuthentication.h
//  XMPPFramework
//
//  Created by Andres Canal on 7/6/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XMPPSASLAuthentication.h"
#import "XMPPStream.h"

@interface XMPPTBRAuthentication : NSObject <XMPPSASLAuthentication>

- (nonnull instancetype)initWithStream:(nonnull XMPPStream *)stream token:(nonnull NSString *)aToken;

@end
