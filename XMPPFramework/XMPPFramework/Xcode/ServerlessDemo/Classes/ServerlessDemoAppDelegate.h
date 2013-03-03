#import <UIKit/UIKit.h>

@class XMPPJID;


@interface ServerlessDemoAppDelegate : NSObject <UIApplicationDelegate>
{
	XMPPJID *myJID;
	
    NSManagedObjectModel *managedObjectModel;
	NSManagedObjectContext *managedObjectContext;
	NSPersistentStoreCoordinator *persistentStoreCoordinator;
	
	UIWindow *window;
	UINavigationController *navigationController;
}

@property (nonatomic, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (nonatomic) IBOutlet UIWindow *window;
@property (nonatomic) IBOutlet UINavigationController *navigationController;

@property (nonatomic) XMPPJID *myJID;

- (NSString *)applicationDocumentsDirectory;

- (NSData *)IPv4AddressFromAddresses:(NSArray *)addresses;
- (NSString *)stringFromAddress:(NSData *)address;

@end

