#import <Foundation/Foundation.h>
#import "XMPP.h"
#import "XMPPRoom.h"

#define _XMPP_MUC_H

/**
 * The XMPPMUC module, combined with XMPPRoom and associated storage classes,
 * provides an implementation of XEP-0045 Multi-User Chat.
 * 
 * The bulk of the code resides in XMPPRoom, which handles the xmpp technical details
 * such as surrounding joining/leaving a room, sending/receiveing messages, etc.
 * 
 * The XMPPMUC class provides 2 general (but important) tasks relating to MUC.
 * First, it integrates with XMPPCapabilities (if included) to properly advertise support for MUC.
 * Second, it monitors active XMPPRoom instances on the xmppStream,
 * and provides an efficient query to see if a presence or message element is targeted at a room.
**/

@interface XMPPMUC : XMPPModule
{
/*	Inherited from XMPPModule:
	 
	XMPPStream *xmppStream;
	
	dispatch_queue_t moduleQueue;
 */
	
	NSMutableSet *rooms;
}

/* Inherited from XMPPModule:
 
- (id)init;
- (id)initWithDispatchQueue:(dispatch_queue_t)queue;

- (BOOL)activate:(XMPPStream *)xmppStream;
- (void)deactivate;

@property (readonly) XMPPStream *xmppStream;
 
- (NSString *)moduleName;
 
*/

- (BOOL)isMUCRoomPresence:(XMPPPresence *)presence;
- (BOOL)isMUCRoomMessage:(XMPPMessage *)message;

@end
