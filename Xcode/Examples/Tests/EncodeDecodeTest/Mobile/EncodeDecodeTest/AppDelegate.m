#import "AppDelegate.h"
#import "ViewController.h"
#import "XMPPJID.h"
#import "XMPPElement.h"
#import "XMPPIQ.h"
#import "XMPPMessage.h"
#import "XMPPPresence.h"


@implementation AppDelegate

@synthesize window = _window;
@synthesize viewController = _viewController;

- (void)testCopy
{
	XMPPJID *jid1 = [XMPPJID jidWithString:@"user@domain.com/resource"];
	XMPPJID *jid2 = [jid1 copy];
	
	NSAssert([jid1 isKindOfClass:[XMPPJID class]], @"A1");
	NSAssert([jid2 isKindOfClass:[XMPPJID class]], @"A2");
	
	XMPPIQ *iq1 = [XMPPIQ iqWithType:@"get" to:jid1 elementID:@"abc123"];
	XMPPIQ *iq2 = [iq1 copy];
	
	NSAssert([iq1 isKindOfClass:[XMPPIQ class]], @"B1 - %@", NSStringFromClass([iq1 class]));
	NSAssert([iq2 isKindOfClass:[XMPPIQ class]], @"B2 - %@", NSStringFromClass([iq2 class]));
	
	XMPPMessage *message1 = [XMPPMessage messageWithType:@"chat" to:jid1];
	XMPPMessage *message2 = [message1 copy];
	
	NSAssert([message1 isKindOfClass:[XMPPMessage class]], @"C1");
	NSAssert([message2 isKindOfClass:[XMPPMessage class]], @"C2");
	
	XMPPPresence *presence1 = [XMPPPresence presenceWithType:@"subscribe" to:jid1];
	XMPPPresence *presence2 = [presence1 copy];
	
	NSAssert([presence1 isKindOfClass:[XMPPPresence class]], @"D1");
	NSAssert([presence2 isKindOfClass:[XMPPPresence class]], @"D2");
}

- (void)testArchive
{
	NSMutableDictionary *dict1 = [NSMutableDictionary dictionaryWithCapacity:4];
	
	XMPPJID *jid1 = [XMPPJID jidWithString:@"user@domain.com/resource"];
	[dict1 setObject:jid1 forKey:@"jid"];
	
	XMPPIQ *iq1 = [XMPPIQ iqWithType:@"get" to:jid1 elementID:@"abc123"];
	[dict1 setObject:iq1 forKey:@"iq"];
	
	XMPPMessage *message1 = [XMPPMessage messageWithType:@"chat" to:jid1];
	[dict1 setObject:message1 forKey:@"message"];
	
	XMPPPresence *presence1 = [XMPPPresence presenceWithType:@"subscribe" to:jid1];
	[dict1 setObject:presence1 forKey:@"presence"];
	
	NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:dict1];
	
	NSDictionary *dict2 = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
	
	XMPPJID *jid2 = [dict2 objectForKey:@"jid"];
	
	NSAssert([jid1 isKindOfClass:[XMPPJID class]], @"A1");
	NSAssert([jid2 isKindOfClass:[XMPPJID class]], @"A2");
	
	XMPPIQ *iq2 = [dict2 objectForKey:@"iq"];
	
	NSAssert([iq1 isKindOfClass:[XMPPIQ class]], @"B1");
	NSAssert([iq2 isKindOfClass:[XMPPIQ class]], @"B2");
	
	XMPPMessage *message2 = [dict2 objectForKey:@"message"];
	
	NSAssert([message1 isKindOfClass:[XMPPMessage class]], @"C1");
	NSAssert([message2 isKindOfClass:[XMPPMessage class]], @"C2");
	
	XMPPPresence *presence2 = [dict2 objectForKey:@"presence"];
	
	NSAssert([presence1 isKindOfClass:[XMPPPresence class]], @"D1");
	NSAssert([presence2 isKindOfClass:[XMPPPresence class]], @"D2");
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	[self testCopy];
	[self testArchive];
	
	NSLog(@"Congratulations");
	
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	self.viewController = [[ViewController alloc] initWithNibName:@"ViewController" bundle:nil];
	self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    return YES;
}

@end
