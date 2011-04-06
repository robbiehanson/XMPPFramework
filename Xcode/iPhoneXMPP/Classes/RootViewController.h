#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>


@class iPhoneXMPPAppDelegate;


@interface RootViewController : UITableViewController <NSFetchedResultsControllerDelegate>
{
	NSManagedObjectContext *managedObjectContext;
	NSFetchedResultsController *fetchedResultsController;
}

- (IBAction)settings:(id)sender;

@end
