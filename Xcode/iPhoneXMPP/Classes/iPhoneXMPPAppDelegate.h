#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

#import "XMPPRoster.h"

@class SettingsViewController;
@class XMPPStream;
@class XMPPCapabilities;
@class XMPPRosterCoreDataStorage;
@class XMPPvCardAvatarModule;
@class XMPPvCardTempModule;


@interface iPhoneXMPPAppDelegate : NSObject <
UIApplicationDelegate,
XMPPRosterDelegate
> {
	XMPPStream *xmppStream;
    XMPPCapabilities *xmppCapabilities;
	XMPPRoster *xmppRoster;
  
    XMPPvCardAvatarModule *xmppvCardAvatarModule;
    XMPPvCardTempModule *xmppvCardTempModule;
	
	NSString *password;
	
	BOOL allowSelfSignedCertificates;
	BOOL allowSSLHostNameMismatch;
	
	BOOL isOpen;
	
	UIWindow *window;
	UINavigationController *navigationController;
    SettingsViewController *loginViewController;
    UIBarButtonItem *loginButton;
}

@property (nonatomic, readonly) XMPPStream *xmppStream;
@property (nonatomic, readonly) XMPPCapabilities *xmppCapabilities;
@property (nonatomic, readonly) XMPPRoster *xmppRoster;
@property (nonatomic, readonly) XMPPvCardAvatarModule *xmppvCardAvatarModule;
@property (nonatomic, readonly) XMPPvCardTempModule *xmppvCardTempModule;

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UINavigationController *navigationController;
@property (nonatomic, retain) IBOutlet SettingsViewController *settingsViewController;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *loginButton;

- (BOOL)connect;
- (void)disconnect;

@end
