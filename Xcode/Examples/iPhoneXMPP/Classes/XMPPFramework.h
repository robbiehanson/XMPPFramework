//
//  This file is designed to be customized by YOU.
//  
//  As you pick and choose which parts of the framework you need for your application, add them to this header file.
//  
//  Various modules available within the framework optionally interact with each other.
//  E.g. The XMPPPing module will utilize the XMPPCapabilities module (if available) to advertise support XEP-0199.
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
//  
//  THIS HEADER FILE SHOULD BE TAILORED TO MATCH YOUR APPLICATION.


#import <XMPPFramework/XMPP.h>

// List the modules you're using here.

#import <XMPPFramework/XMPPReconnect.h>

#import <XMPPFramework/XMPPRoster.h>
#import <XMPPFramework/XMPPRosterCoreDataStorage.h>

#import <XMPPFramework/XMPPvCardTempModule.h>
#import <XMPPFramework/XMPPvCardAvatarModule.h>
#import <XMPPFramework/XMPPvCardCoreDataStorage.h>

#import <XMPPFramework/XMPPCapabilities.h>
#import <XMPPFramework/XMPPCapabilitiesCoreDataStorage.h>

#import <XMPPFramework/XMPPMUC.h>
#import <XMPPFramework/XMPPRoomCoreDataStorage.h>
