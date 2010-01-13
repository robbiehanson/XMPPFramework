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

@property (nonatomic, retain, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, retain, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, retain, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UINavigationController *navigationController;

@property (nonatomic, retain) XMPPJID *myJID;

- (NSString *)applicationDocumentsDirectory;

- (NSData *)IPv4AddressFromAddresses:(NSArray *)addresses;
- (NSString *)stringFromAddress:(NSData *)address;

@end

