//
//  XMPPvCardCoreDataStorage.h
//  XEP-0054 vCard-temp
//
//  Originally created by Eric Chamberlain on 3/18/11.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "XMPPCoreDataStorage.h"
#import "XMPPvCardTempModule.h"
#import "XMPPvCardAvatarModule.h"

/**
 * This class is an example implementation of XMPPCapabilitiesStorage using core data.
 * You are free to substitute your own storage class.
 **/

@interface XMPPvCardCoreDataStorage : XMPPCoreDataStorage <
XMPPvCardAvatarStorage,
XMPPvCardTempModuleStorage
> {
	// Inherits protected variables from XMPPCoreDataStorage
}

/**
 * XEP-0054 provides a mechanism for transmitting vCards via XMPP.
 * Because the JID doesn't change very often and can be large with image data, 
 * it is safe to persistently store the JID and wait for a user to explicity ask for an update, 
 * or use XEP-0153 to monitor for JID changes.
 * 
 * For this reason, it is recommended you use this sharedInstance across all your xmppStreams.
 * This way all streams can shared a knowledgebase concerning known JIDs and Avatar photos.
 * 
 * All other aspects of vCard handling (such as lookup failures, etc) are kept separate between streams.
**/
+ (XMPPvCardCoreDataStorage *)sharedInstance;

// 
// This class inherits from XMPPCoreDataStorage.
// 
// Please see the XMPPCoreDataStorage header file for more information.
// 


@end
