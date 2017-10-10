//
//  XMPPXOAuth2Google.h
//  Off the Record
//
//  Created by David Chiles on 9/13/13.
//  Copyright (c) 2013 Chris Ballinger. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XMPPSASLAuthentication.h"
#import "XMPPStream.h"

NS_ASSUME_NONNULL_BEGIN
@interface XMPPXOAuth2Google : NSObject <XMPPSASLAuthentication>

-(instancetype)initWithStream:(XMPPStream *)stream
                  accessToken:(NSString *)accessToken;

@end



@interface XMPPStream (XMPPXOAuth2Google)


@property (nonatomic, readonly) BOOL supportsXOAuth2GoogleAuthentication;

- (BOOL)authenticateWithGoogleAccessToken:(NSString *)accessToken error:(NSError **)errPtr;

@end
NS_ASSUME_NONNULL_END
