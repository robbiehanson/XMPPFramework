#import <Foundation/Foundation.h>
#import "XMPP.h"


@interface XMPPMUC : XMPPModule
{
	NSMutableSet *rooms;
}

- (BOOL)isMUCRoomPresence:(XMPPPresence *)presence;

@end
