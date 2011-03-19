#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

#import "XMPPvCardTempModule.h"

@class iPhoneXMPPAppDelegate;


@interface RootViewController : UITableViewController <
NSFetchedResultsControllerDelegate,
XMPPvCardTempModuleDelegate>
{
	NSFetchedResultsController *fetchedResultsController;
}

@property(nonatomic,assign,readonly) iPhoneXMPPAppDelegate *appDelegate;

- (IBAction)settings:(id)sender;


@end
