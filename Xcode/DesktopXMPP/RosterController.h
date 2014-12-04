#import <Cocoa/Cocoa.h>


@interface RosterController : NSObject <NSTableViewDelegate>
{
	BOOL useSSL;
	BOOL customCertEvaluation;
	
	BOOL isOpen;
	BOOL isRegistering;
	BOOL isAuthenticating;
	
	NSArray *roster;
    
	// Sign-In Sheet
	
	IBOutlet NSPanel     * signInSheet;
	IBOutlet NSTextField * serverField;
	IBOutlet NSTextField * portField;
	IBOutlet NSButton    * sslButton;
	IBOutlet NSButton    * customCertEvalButton;
	IBOutlet NSTextField * jidField;
    IBOutlet NSTextField * passwordField;
	IBOutlet NSButton    * rememberPasswordCheckbox;
    IBOutlet NSTextField * resourceField;
	IBOutlet NSTextField * messageField;
	IBOutlet NSButton    * registerButton;
    IBOutlet NSButton    * signInButton;
	
	// MUC Sheet
	
	IBOutlet NSPanel     * mucSheet;
	IBOutlet NSTextField * mucRoomField;
	
	// Roster Window
	
	IBOutlet NSWindow    * window;
    IBOutlet NSTableView * rosterTable;
	IBOutlet NSTextField * buddyField;
}

// Sign-In Sheet

- (void)displaySignInSheet;

- (IBAction)jidDidChange:(id)sender;
- (IBAction)createAccount:(id)sender;
- (IBAction)signIn:(id)sender;

// MUC Sheet

- (IBAction)mucCancel:(id)sender;
- (IBAction)mucJoin:(id)sender;

// Roster Window

- (IBAction)changePresence:(id)sender;
- (IBAction)muc:(id)sender;
- (IBAction)connectViaXEP65:(id)sender;
- (IBAction)chat:(id)sender;
- (IBAction)addBuddy:(id)sender;
- (IBAction)removeBuddy:(id)sender;


@end
