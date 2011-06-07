#import <Foundation/Foundation.h>
#import "XMPPRoster.h"

@interface XMPPRoster (PrivateInternalAPI)

/**
 * The XMPPRosterStorage classes use the same delegate(s) as their parent XMPPRoster.
 * This method allows these classes to access the delegate(s).
 * 
 * Note: If the storage class operates on a different queue than its parent,
 *       it MUST dispatch all calls to the multicastDelegate onto its parent's queue.
 *       The parent's dispatch queue is passed in the configureWithParent:queue: method.
**/
- (GCDMulticastDelegate *)multicastDelegate;

@end
