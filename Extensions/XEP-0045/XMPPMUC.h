#import <Foundation/Foundation.h>
#import "XMPP.h"
#import "XMPPRoom.h"

#define _XMPP_MUC_H

@class XMPPIDTracker;

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
NS_ASSUME_NONNULL_BEGIN

/** jabber:x:conference */
extern NSString *const XMPPConferenceXmlns;

@interface XMPPMUC : XMPPModule
{
/*	Inherited from XMPPModule:
	 
	XMPPStream *xmppStream;
	
	dispatch_queue_t moduleQueue;
 */
	
    NSMutableSet<XMPPJID*> *rooms;

    XMPPIDTracker * _Nullable xmppIDTracker;
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

/**
* This method will attempt to discover existing services for the domain found in xmppStream.myJID.
*
* @see xmppMUC:didDiscoverServices:
* @see xmppMUCFailedToDiscoverServices:withError:
*/
- (void)discoverServices;

/**
* This method will attempt to discover existing rooms (that are not hidden) for a given service.
*
* @see xmppMUC:didDiscoverRooms:forServiceNamed:
* @see xmppMUC:failedToDiscoverRoomsForServiceNamed:withError:
*
* @param serviceName The name of the service for which to discover rooms. Normally in the form
*                    of "chat.shakespeare.lit".
*
* @return NO if a serviceName is not provided, otherwise YES
*/
- (BOOL)discoverRoomsForServiceNamed:(NSString *)serviceName;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPMUCDelegate
@optional

- (void)xmppMUC:(XMPPMUC *)sender roomJID:(XMPPJID *)roomJID didReceiveInvitation:(XMPPMessage *)message;
- (void)xmppMUC:(XMPPMUC *)sender roomJID:(XMPPJID *)roomJID didReceiveInvitationDecline:(XMPPMessage *)message;

/**
* Implement this method when calling [mucInstance discoverServices]. It will be invoked if the request
* for discovering services is successfully executed and receives a successful response.
*
* @param sender XMPPMUC object invoking this delegate method.
* @param services An array of NSXMLElements in the form shown below. You will need to extract the data you
*                 wish to use.
*
*                 <item jid='chat.shakespeare.lit' name='Chatroom Service'/>
*/
- (void)xmppMUC:(XMPPMUC *)sender didDiscoverServices:(NSArray<NSXMLElement*> *)services;

/**
* Implement this method when calling [mucInstanse discoverServices]. It will be invoked if the request
* for discovering services is unsuccessfully executed or receives an unsuccessful response.
*
* @param sender XMPPMUC object invoking this delegate method.
* @param error NSError containing more details of the failure.
*/
- (void)xmppMUCFailedToDiscoverServices:(XMPPMUC *)sender withError:(NSError *)error;

/**
* Implement this method when calling [mucInstance discoverRoomsForServiceNamed:]. It will be invoked if
* the request for discovering rooms is successfully executed and receives a successful response.
*
* @param sender XMPPMUC object invoking this delegate method.
* @param rooms An array of NSXMLElements in the form shown below. You will need to extract the data you
*              wish to use.
*
*              <item jid='forres@chat.shakespeare.lit' name='The Palace'/>
*
* @param serviceName The name of the service for which rooms were discovered.
*/
- (void)xmppMUC:(XMPPMUC *)sender didDiscoverRooms:(NSArray *)rooms forServiceNamed:(NSString *)serviceName;

/**
* Implement this method when calling [mucInstance discoverRoomsForServiceNamed:]. It will be invoked if
* the request for discovering rooms is unsuccessfully executed or receives an unsuccessful response.
*
* @param sender XMPPMUC object invoking this delegate method.
* @param serviceName The name of the service for which rooms were attempted to be discovered.
* @param error NSError containing more details of the failure.
*/
- (void)xmppMUC:(XMPPMUC *)sender failedToDiscoverRoomsForServiceNamed:(NSString *)serviceName withError:(NSError *)error;

@end
NS_ASSUME_NONNULL_END
