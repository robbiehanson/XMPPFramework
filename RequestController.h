#import <Cocoa/Cocoa.h>


@interface RequestController : NSObject
{
	NSMutableArray *jids;
	int jidIndex;
	
	IBOutlet id jidField;
    IBOutlet id window;
    IBOutlet id xofyField;
}

- (IBAction)accept:(id)sender;
- (IBAction)reject:(id)sender;

@end

