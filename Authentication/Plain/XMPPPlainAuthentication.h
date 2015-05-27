#import <Foundation/Foundation.h>
#import "XMPPSASLAuthentication.h"
#import "XMPPStream.h"


@interface XMPPPlainAuthentication : NSObject <XMPPSASLAuthentication>

// This class implements the XMPPSASLAuthentication protocol.
// 
// See XMPPSASLAuthentication.h for more information.

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface XMPPStream (XMPPPlainAuthentication)

- (BOOL)supportsPlainAuthentication;

@end
