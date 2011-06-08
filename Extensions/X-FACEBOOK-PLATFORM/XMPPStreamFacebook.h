//
//  XMPPStreamFacebook.h
//
//  Created by Eric Chamberlain on 10/13/10.
//  Copyright 2010 RF.com. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "FBConnect.h"
#import "XMPPStream.h"

@interface XMPPStreamFacebook : XMPPStream <FBRequestDelegate>
{
    Facebook *facebook;
	FBRequest *facebookRequest;
}

@property (readwrite, retain) Facebook *facebook;

/**
 * returns the correct permissions for xmpp
**/
+ (NSArray *)permissions;

- (BOOL)supportsXFacebookPlatform;

- (BOOL)authenticateWithAppId:(NSString *)appId 
                  accessToken:(NSString *)accessToken 
                        error:(NSError **)errPtr;

- (BOOL)authenticateWithAppId:(NSString *)appId 
                  accessToken:(NSString *)accessToken 
               expirationDate:(NSDate *)expirationDate 
                        error:(NSError **)errPtr;

@end
