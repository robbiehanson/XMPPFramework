#import "AppDelegate.h"
#import "DDList.h"


@implementation AppDelegate

@synthesize window = _window;

- (void)testZeroElements
{
	NSLog(@"%@: Start", NSStringFromSelector(_cmd));
	
	DDList *list = [[DDList alloc] init];
	
	int i = 0;
	for (NSString *string in list)
	{
		NSLog(@"list[%i] = %@", i++, string);
	}
	
	NSLog(@"%@: Done", NSStringFromSelector(_cmd));
}

- (void)testOneElement
{
	NSLog(@"%@: Start", NSStringFromSelector(_cmd));
	
	NSMutableArray *strings = [NSMutableArray arrayWithObjects:@"1", nil];
	DDList *list = [[DDList alloc] init];
	
	int i;
	
	i = 0;
	for (NSString *string in strings)
	{
		NSLog(@"array[%i] = %@", i++, string);
		[list add:(__bridge void *)string];
	}
	
	i = 0;
	for (NSString *string in list)
	{
		NSLog(@"list[%i] = %@", i++, string);
	}
	
	NSLog(@"%@: Done", NSStringFromSelector(_cmd));
}

- (void)testMultipleElements
{
	NSLog(@"%@: Start", NSStringFromSelector(_cmd));
	
	NSMutableArray *strings = [NSMutableArray arrayWithObjects:@"1", @"2", @"3", nil];
	DDList *list = [[DDList alloc] init];
	
	int i;
	
	i = 0;
	for (NSString *string in strings)
	{
		NSLog(@"array[%i] = %@", i++, string);
		
		[list add:(__bridge void *)string];
	}
	
	i = 0;
	for (NSString *string in list)
	{
		NSLog(@"list[%i] = %@", i++, string);
	}
	
	NSLog(@"%@: Done", NSStringFromSelector(_cmd));
}

- (void)testRemoveAllWithOneElement
{
	NSLog(@"%@: Start", NSStringFromSelector(_cmd));

	NSString *theElement = @"theElement";
	DDList *list = [[DDList alloc] init];

	[list add:(__bridge void *)theElement];

	[list removeAll:(__bridge void *)theElement];

	NSLog(@"%@: Done", NSStringFromSelector(_cmd));
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[self testZeroElements];
	[self testOneElement];
	[self testMultipleElements];
	[self testRemoveAllWithOneElement];
}

@end
