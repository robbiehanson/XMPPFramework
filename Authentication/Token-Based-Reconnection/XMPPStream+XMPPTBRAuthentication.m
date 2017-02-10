//
//  XMPPStream+XMPPTBRAuthentication.m
//  XMPPFramework
//
//  Created by Andres Canal on 7/6/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

#import "XMPPStream+XMPPTBRAuthentication.h"
#import "XMPPTBRAuthentication.h"
#import "XMPPInternal.h"

@implementation XMPPStream (TBRAuthentication)

- (BOOL)supportsTBRAuthentication{
	return [self supportsAuthenticationMechanism:[XMPPTBRAuthentication mechanismName]];
}

- (BOOL)authenticateWithTBR:(nonnull NSString *)authToken error:(NSError **)errPtr {

	__block BOOL result = YES;
	__block NSError *err = nil;

	dispatch_block_t block = ^{ @autoreleasepool {

		if ([self supportsTBRAuthentication]) {

			XMPPTBRAuthentication *tbrAuthentication = [[XMPPTBRAuthentication alloc] initWithStream:self
																							   token:authToken];

			result = [self authenticate:tbrAuthentication error:&err];
		} else {
			NSString *errMsg = @"The server does not support Token-based reconnection.";
			NSDictionary *info = @{NSLocalizedDescriptionKey : errMsg};

			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamUnsupportedAction userInfo:info];

			result = NO;
		}
	}};

	if (dispatch_get_specific(self.xmppQueueTag))
		block();
	else
		dispatch_sync(self.xmppQueue, block);

	if (errPtr)
		*errPtr = err;

	return result;
}

@end
