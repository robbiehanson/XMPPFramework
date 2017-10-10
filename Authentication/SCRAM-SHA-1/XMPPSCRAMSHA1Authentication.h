//
//  XMPPSCRAMSHA1Authentication.h
//  iPhoneXMPP
//
//  Created by David Chiles on 3/21/14.
//
//

#import <Foundation/Foundation.h>
#import "XMPPSASLAuthentication.h"
#import "XMPPStream.h"

NS_ASSUME_NONNULL_BEGIN
@interface XMPPSCRAMSHA1Authentication : NSObject <XMPPSASLAuthentication>

@end

@interface XMPPStream (XMPPSCRAMSHA1Authentication)

@property (nonatomic, readonly) BOOL supportsSCRAMSHA1Authentication;

@end
NS_ASSUME_NONNULL_END
