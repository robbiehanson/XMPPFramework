#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@class SettingsViewController;
@class XMPPStream;
@class XMPPRoster;
@class XMPPRosterCoreDataStorage;


@interface iPhoneXMPPAppDelegate : NSObject <UIApplicationDelegate>
{
	XMPPStream *xmppStream;
	XMPPRoster *xmppRoster;
	XMPPRosterCoreDataStorage *xmppRosterStorage;
	
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
@property (nonatomic, readonly) XMPPRoster *xmppRoster;
@property (nonatomic, readonly) XMPPRosterCoreDataStorage *xmppRosterStorage;

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UINavigationController *navigationController;
@property (nonatomic, retain) IBOutlet SettingsViewController *settingsViewController;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *loginButton;

- (BOOL)connect;
- (void)disconnect;

@end
