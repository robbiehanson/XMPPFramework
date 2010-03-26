#import <Foundation/Foundation.h>
#import "XMPPRoster.h"

@interface XMPPRoster (PrivateInternalAPI)

/**
 * The XMPPRosterStorage classes use the same delegate(s) as their parent XMPPRoster.
 * This method allows these classes to access the delegate(s).
**/
- (MulticastDelegate *)multicastDelegate;

@end
