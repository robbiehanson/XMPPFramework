#import <Foundation/Foundation.h>
#import "XMPPSASLAuthentication.h"
#import "XMPPStream.h"


@interface XMPPPlainAuthentication : NSObject <XMPPSASLAuthentication>

// This class implements the XMPPSASLAuthentication protocol.
// 
// See XMPPSASLAuthentication.h for more information.

/**
 * Use this init method if the username used for authentication does not match the user part of the JID.
 * If inUsername is nil, the user part of the JID will be used. The standard init method will use the
 * user part of the JID as the username.
**/
- (id)initWithStream:(XMPPStream *)stream username:(NSString *)inUsername password:(NSString *)inPassword;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface XMPPStream (XMPPPlainAuthentication)

- (BOOL)supportsPlainAuthentication;

@end
