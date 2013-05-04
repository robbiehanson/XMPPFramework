#import <Foundation/Foundation.h>
#import "XMPP.h"
#import "XMPPRoom.h"

#define _XMPP_MUC_H

/**
 * The XMPPMUC module, combined with XMPPRoom and associated storage classes,
 * provides an implementation of XEP-0045 Multi-User Chat.
 * 
 * The bulk of the code resides in XMPPRoom, which handles the xmpp technical details
 * such as surrounding joining/leaving a room, sending/receiving messages, etc.
 * 
 * The XMPPMUC class provides general (but important) tasks relating to MUC:
 *  - It integrates with XMPPCapabilities (if available) to properly advertise support for MUC.
 *  - It monitors active XMPPRoom instances on the xmppStream,
 *    and provides an efficient query to see if a presence or message element is targeted at a room.
 *  - It listens for MUC room invitations sent from other users.
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPMUCDelegate
@optional

- (void)xmppMUC:(XMPPMUC *)sender roomJID:(XMPPJID *) roomJID didReceiveInvitation:(XMPPMessage *)message;
- (void)xmppMUC:(XMPPMUC *)sender roomJID:(XMPPJID *) roomJID didReceiveInvitationDecline:(XMPPMessage *)message;

@end
