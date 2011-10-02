//
//  XMPPXFacebookPlatformAuthentication.h
//  iPhoneXMPP
//
//  Created by Eric Chamberlain on 10/1/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#import "DDXML.h"
#endif

#import "XMPPSASLAuthentication.h"

@interface XMPPXFacebookPlatformAuthentication : NSObject <XMPPSASLAuthentication>
{
  NSString *appId;
  NSString *authToken;
  NSString *nonce;
  NSString *method;
}

@property (nonatomic,copy) NSString *appId;
@property (nonatomic,copy) NSString *authToken;
@property (nonatomic,copy) NSString *nonce;
@property (nonatomic,copy) NSString *method;

- (id)initWithChallenge:(NSXMLElement *)challenge appId:(NSString *)appId authToken:(NSString *)authToken;

@end 
