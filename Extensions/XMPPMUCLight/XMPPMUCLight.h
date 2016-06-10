//
//  XMPPMUCLight.h
//  Mangosta
//
//  Created by Andres on 5/30/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

#import <XMPPFramework/XMPPFramework.h>
#import "XMPPFramework/XMPPJID.h"

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
 *
 * Server suport:
 *    - MongooseIM 2.0.0+ (https://github.com/esl/MongooseIM/)
 *
 *
 *
 **/

@interface XMPPMUCLight : XMPPModule {
	XMPPIDTracker *xmppIDTracker;
}

@property(nonatomic, strong, readonly, nonnull) NSMutableSet *rooms;
- (BOOL)discoverRoomsForServiceNamed:(nonnull NSString *)serviceName;

@end

@protocol XMPPMUCLightDelegate
@optional

- (void)xmppMUCLight:(nonnull XMPPMUCLight *)sender didDiscoverRooms:(nonnull NSArray<NSXMLElement*>*)rooms forServiceNamed:(nonnull NSString *)serviceName;
- (void)xmppMUCLight:(nonnull XMPPMUCLight *)sender failedToDiscoverRoomsForServiceNamed:(nonnull NSString *)serviceName withError:(nonnull NSError *)error;
- (void)xmppMUCLight:(nonnull XMPPMUCLight *)sender changedAffiliation:(nonnull NSString *)affiliation roomJID:(nonnull XMPPJID *)roomJID;

@end
