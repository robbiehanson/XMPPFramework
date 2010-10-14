//
//  XMPPStreamFacebook.h
//
//  Created by Eric Chamberlain on 10/13/10.
//  Copyright 2010 RF.com. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "FBConnect.h"
#import "XMPPStream.h"

@interface XMPPStreamFacebook : XMPPStream <FBRequestDelegate> {
    Facebook *facebook;
}

@property (nonatomic, readwrite, retain) Facebook *facebook;

/**
 * returns the correct permissions for xmpp
**/
+ (NSArray *)permissions;

- (BOOL)supportsXFacebookPlatform;
- (BOOL)authenticateWithAccessToken:(NSString *)accessToken error:(NSError **)errPtr;
- (BOOL)authenticateWithAccessToken:(NSString *)accessToken expirationDate:(NSDate *)expirationDate error:(NSError **)errPtr;

@end
