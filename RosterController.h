#import <Cocoa/Cocoa.h>
@class  XMPPClient;


@interface RosterController : NSObject
{
	BOOL isRegistering;
	BOOL isAuthenticating;
	
	NSArray *roster;
	
	IBOutlet id buddyField;
    IBOutlet id jidField;
    IBOutlet id messageField;
	IBOutlet id mismatchButton;
    IBOutlet id passwordField;
    IBOutlet id portField;
    IBOutlet id registerButton;
    IBOutlet id resourceField;
    IBOutlet id rosterTable;
    IBOutlet id selfSignedButton;
    IBOutlet id serverField;
    IBOutlet id signInButton;
    IBOutlet id signInSheet;
    IBOutlet id sslButton;
    IBOutlet id window;
	
	IBOutlet XMPPClient *xmppClient;
}

- (void)displaySignInSheet;

- (IBAction)jidDidChange:(id)sender;
- (IBAction)createAccount:(id)sender;
- (IBAction)signIn:(id)sender;

- (IBAction)changePresence:(id)sender;
- (IBAction)chat:(id)sender;
- (IBAction)addBuddy:(id)sender;
- (IBAction)removeBuddy:(id)sender;

- (IBAction)connectViaXEP65:(id)sender;

@end
