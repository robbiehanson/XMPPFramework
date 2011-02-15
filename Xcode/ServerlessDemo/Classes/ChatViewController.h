#import <UIKit/UIKit.h>

@class Service;
@class XMPPStream;


@interface ChatViewController : UIViewController <UITableViewDelegate,
                                                  UITextFieldDelegate,
                                                  NSNetServiceDelegate,
                                                  NSFetchedResultsControllerDelegate>
{
	IBOutlet UITextField *textField;
	IBOutlet UITableView *tableView;
	
	Service *service;
	NSNetService *netService;
	XMPPStream *xmppStream;
	
	// Core data
	NSFetchedResultsController *fetchedResultsController;
	NSManagedObjectContext *managedObjectContext;
}

@property (nonatomic, retain) Service *service;
@property (nonatomic, retain) NSManagedObjectContext *managedObjectContext;

- (void)sendMessage:(id)sender;

@end
