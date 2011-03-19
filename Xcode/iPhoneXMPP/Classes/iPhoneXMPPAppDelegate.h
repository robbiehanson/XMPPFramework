#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@class SettingsViewController;
@class XMPPStream;
@class XMPPRoster;
@class XMPPRosterCoreDataStorage;
@class XMPPvCardAvatarModule;
@class XMPPvCardTempModule;


@interface iPhoneXMPPAppDelegate : NSObject <UIApplicationDelegate>
{
	XMPPStream *xmppStream;
	XMPPRoster *xmppRoster;
	XMPPRosterCoreDataStorage *xmppRosterStorage;
  XMPPvCardAvatarModule *_xmppvCardAvatarModule;
  XMPPvCardTempModule *_xmppvCardTempModule;
	
	NSString *password;
	
	BOOL allowSelfSignedCertificates;
	BOOL allowSSLHostNameMismatch;
	
	BOOL isOpen;
	
	UIWindow *window;
	UINavigationController *navigationController;
  UIBarButtonItem *_loginButton;
  
  SettingsViewController *_loginViewController;
}

@property (nonatomic, readonly) XMPPStream *xmppStream;
@property (nonatomic, readonly) XMPPRoster *xmppRoster;
@property (nonatomic, readonly) XMPPRosterCoreDataStorage *xmppRosterStorage;
@property (nonatomic, readonly) XMPPvCardAvatarModule *xmppvCardAvatarModule;
@property (nonatomic, readonly) XMPPvCardTempModule *xmppvCardTempModule;

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UINavigationController *navigationController;

@property (nonatomic, retain) IBOutlet UIBarButtonItem *loginButton;
@property (nonatomic, retain) IBOutlet SettingsViewController *settingsViewController;

- (BOOL)connect;
- (void)disconnect;

- (void)goOnline;
- (void)goOffline;

- (void)setupStream;
@end
