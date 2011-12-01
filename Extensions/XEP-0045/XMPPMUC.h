#import <Foundation/Foundation.h>
#import "XMPP.h"

#define _XMPP_MUC_H


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
