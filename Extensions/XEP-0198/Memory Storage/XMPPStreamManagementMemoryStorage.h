#import <Foundation/Foundation.h>
#import "XMPPStreamManagement.h"

/**
 * This class provides an in-memory only storage system for XMPPStreamManagement.
 * As such, it will only support stream resumption so long as the application doesn't terminate.
 *
 * This class should be considered primarily for testing.
 * An application making use of stream management should likely transition
 * to a persistent storage layer before distribution.
**/
@interface XMPPStreamManagementMemoryStorage : NSObject <XMPPStreamManagementStorage>

@end
