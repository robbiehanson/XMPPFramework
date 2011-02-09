#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>


@interface RootViewController : UITableViewController <NSFetchedResultsControllerDelegate>
{
	NSManagedObjectContext *managedObjectContext;
	NSFetchedResultsController *fetchedResultsController;
}

@end
