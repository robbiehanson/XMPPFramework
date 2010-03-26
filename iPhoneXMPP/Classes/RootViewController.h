#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>


@interface RootViewController : UITableViewController <NSFetchedResultsControllerDelegate>
{
	NSFetchedResultsController *fetchedResultsController;
}

@end
