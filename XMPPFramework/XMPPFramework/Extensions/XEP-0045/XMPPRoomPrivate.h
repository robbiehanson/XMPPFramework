#import "XMPPRoom.h"


@interface XMPPRoom (PrivateInternalAPI)

/**
 * XMPPRoomStorage classes may optionally use the same delegate(s) as their parent XMPPRoom.
 * This method allows such storage classes to access the delegate(s).
 * 
 * Note: If the storage class operates on a different queue than its parent,
 *       it MUST dispatch all calls to the multicastDelegate onto its parent's queue.
 *       The parent's dispatch queue is passed in the configureWithParent:queue: method,
 *       or may be obtained via the moduleQueue method below.
**/
- (GCDMulticastDelegate *)multicastDelegate;

- (dispatch_queue_t)moduleQueue;

@end
