//
//  XMPPStream+XMPPTBRAuthentication.h
//  XMPPFramework
//
//  Created by Andres Canal on 7/6/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

#import "XMPPFramework.h"
#import "XMPPStream.h"

@interface XMPPStream (XMPPTBRAuthentication)

- (BOOL)authenticateWithTBR:(NSString *)authToken error:(NSError **)errPtr;
- (BOOL)supportsTBRAuthentication;

@end
