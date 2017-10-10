#import <Foundation/Foundation.h>
#import "XMPPSASLAuthentication.h"
#import "XMPPStream.h"

NS_ASSUME_NONNULL_BEGIN
@interface XMPPDeprecatedPlainAuthentication : NSObject <XMPPSASLAuthentication>

// This class implements the XMPPSASLAuthentication protocol.
// 
// See XMPPSASLAuthentication.h for more information.

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface XMPPStream (XMPPDeprecatedPlainAuthentication)

@property (nonatomic, readonly) BOOL supportsDeprecatedPlainAuthentication;

@end
NS_ASSUME_NONNULL_END
