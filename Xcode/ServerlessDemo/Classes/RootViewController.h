#import <UIKit/UIKit.h>


@interface RootViewController : UITableViewController <NSFetchedResultsControllerDelegate>
{
	NSFetchedResultsController *fetchedResultsController;
	NSManagedObjectContext *managedObjectContext;
}

@property (nonatomic) NSManagedObjectContext *managedObjectContext;

@end
