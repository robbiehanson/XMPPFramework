//
//  This file is designed to be customized by YOU.
//  
//  Copy this file and rename it to "XMPPFramework.h". Then add it to your project.
//  As you pick and choose which parts of the framework you need for your application, add them to this header file.
//  
//  Various modules available within the framework optionally interact with each other.
//  E.g. The XMPPPing module utilizes the XMPPCapabilities module to advertise support XEP-0199.
// 
//  However, the modules can only interact if they're both added to your xcode project.
//  E.g. If XMPPCapabilities isn't a part of your xcode project, then XMPPPing shouldn't attempt to reference it.
// 
//  So how do the individual modules know if other modules are available?
//  Via this header file.
// 
//  If you #import "XMPPCapabilities.h" in this file, then _XMPP_CAPABILITIES_H will be defined for other modules.
//  And they can automatically take advantage of it.
//

//  CUSTOMIZE ME !
//  THIS HEADER FILE SHOULD BE TAILORED TO MATCH YOUR APPLICATION.

//  The following is standard:

#import "XMPP.h"
 
// List the modules you're using here:
// (the following may not be a complete list)

//#import "XMPPBandwidthMonitor.h"
// 
//#import "XMPPCoreDataStorage.h"
//
//#import "XMPPReconnect.h"
//
//#import "XMPPRoster.h"
//#import "XMPPRosterMemoryStorage.h"
//#import "XMPPRosterCoreDataStorage.h"
//
//#import "XMPPJabberRPCModule.h"
//#import "XMPPIQ+JabberRPC.h"
//#import "XMPPIQ+JabberRPCResponse.h"
//
//#import "XMPPPrivacy.h"
//
//#import "XMPPMUC.h"
//#import "XMPPRoom.h"
//#import "XMPPRoomMemoryStorage.h"
//#import "XMPPRoomCoreDataStorage.h"
//#import "XMPPRoomHybridStorage.h"
//
//#import "XMPPvCardTempModule.h"
//#import "XMPPvCardCoreDataStorage.h"
//
//#import "XMPPPubSub.h"
//
//#import "TURNSocket.h"
//
//#import "XMPPDateTimeProfiles.h"
//#import "NSDate+XMPPDateTimeProfiles.h"
//
//#import "XMPPMessage+XEP_0085.h"
//
//#import "XMPPTransports.h"
//
//#import "XMPPCapabilities.h"
//#import "XMPPCapabilitiesCoreDataStorage.h"
//
//#import "XMPPvCardAvatarModule.h"
//
//#import "XMPPMessage+XEP_0184.h"
//
//#import "XMPPPing.h"
//#import "XMPPAutoPing.h"
//
//#import "XMPPTime.h"
//#import "XMPPAutoTime.h"
//
//#import "XMPPElement+Delay.h"
