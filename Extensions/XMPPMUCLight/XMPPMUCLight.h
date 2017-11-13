//
//  XMPPMUCLight.h
//  Mangosta
//
//  Created by Andres on 5/30/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

#import "XMPPModule.h"
#import "XMPPJID.h"

/**
 * The XMPPMUCLight module, combined with XMPPRoomLight and associated storage classes,
 * provides an implementation of XEP-xxxx: Multi-User Chat Light a Proto XEP.
 * More info: https://github.com/fenek/xeps/blob/muc_light/inbox/muc-light.xml
 *
 * The bulk of the code resides in XMPPRoomLight, which handles the xmpp technical details
 * such as creating a room, leaving a room, adding users to a room, fetching the member list and
 * sending messages
 *
 * The XMPPMUCLight class provides general (but important) tasks relating to MUCLight:
 *  - It discovers rooms for a service.
 *  - It monitors active XMPPRoomLight instances on the xmppStream.
 *  - It listens for MUCLigh room affiliation changes sent from other users.
 *  - It allows to block/unblock users/rooms
 *  - It lists the list of blocked users/rooms
 *
 * Server suport:
 *  - MongooseIM 2.0.0+ (https://github.com/esl/MongooseIM/)
 *
 * MUC Light: It's more suitable for mobile devices, where your connection might
 * go up and down often, but you don't want that to affect the fact that you're "in"
 * the room.
 *
 * Hightlights:
 *  - Lack of presences: there is no need to rejoin every room on reconnection.
 *  - Room version allows cheap checks whether room member list/configuration has
 *    changes. To be implemented in XMPPRoom
 **/

@interface XMPPMUCLight : XMPPModule {
	XMPPIDTracker *xmppIDTracker;
}

- (nonnull NSSet<XMPPJID*>*)rooms;
- (BOOL)discoverRoomsForServiceNamed:(nonnull NSString *)serviceName;
- (BOOL)requestBlockingList:(nonnull NSString *)serviceName;
- (BOOL)performActionOnElements:(nonnull NSArray<__kindof NSXMLElement *> *)elements forServiceNamed:(nonnull NSString *)serviceName;
@end

@protocol XMPPMUCLightDelegate
@optional

- (void)xmppMUCLight:(nonnull XMPPMUCLight *)sender didDiscoverRooms:(nonnull NSArray<__kindof NSXMLElement*>*)rooms forServiceNamed:(nonnull NSString *)serviceName;
- (void)xmppMUCLight:(nonnull XMPPMUCLight *)sender failedToDiscoverRoomsForServiceNamed:(nonnull NSString *)serviceName withError:(nonnull NSError *)error;
- (void)xmppMUCLight:(nonnull XMPPMUCLight *)sender changedAffiliation:(nonnull NSString *)affiliation userJID:(nonnull XMPPJID *)userJID roomJID:(nonnull XMPPJID *)roomJID;

- (void)xmppMUCLight:(nonnull XMPPMUCLight *)sender didRequestBlockingList:(nonnull NSArray<NSXMLElement*>*)items forServiceNamed:(nonnull NSString *)serviceName;
- (void)xmppMUCLight:(nonnull XMPPMUCLight *)sender failedToRequestBlockingList:(nonnull NSString *)serviceName withError:(nonnull XMPPIQ *)iq;

- (void)xmppMUCLight:(nonnull XMPPMUCLight *)sender didPerformAction:(nonnull XMPPIQ *)serviceName;
- (void)xmppMUCLight:(nonnull XMPPMUCLight *)sender failedToPerformAction:(nonnull XMPPIQ *)iq;

@end
