#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

#import "XMPPvCardTempModule.h"

@class iPhoneXMPPAppDelegate;


@interface RootViewController : UITableViewController <
NSFetchedResultsControllerDelegate,
XMPPvCardTempModuleDelegate
> {
	NSManagedObjectContext *managedObjectContext;
	NSFetchedResultsController *fetchedResultsController;
}

- (IBAction)settings:(id)sender;

@end
