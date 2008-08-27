/*
 * Written by Theo Hultberg (theo@iconara.net) 2004-03-09 with help from Boaz Stuller.
 * This code is in the public domain, provided that this notice remains.
 */

#import "SCNotificationManager.h"


void _SCNotificationCallback( SCDynamicStoreRef store, CFArrayRef changedKeys, void *info )
{
	NSEnumerator *keysE = [(NSArray *)changedKeys objectEnumerator];
	NSString *key = nil;
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	
	while ( key = [keysE nextObject] ) {		
		[nc postNotificationName:key 
						  object:(id)info 
		                userInfo:[(NSDictionary *)SCDynamicStoreCopyValue(store, (CFStringRef) key) autorelease]];
	}
}


@implementation SCNotificationManager

- (id)init
{
	if(self = [super init])
	{
		SCDynamicStoreContext context = { 0, (void *)self, NULL, NULL, NULL };
		
		dynStore = SCDynamicStoreCreate(
			NULL, 
			(CFStringRef) [[NSBundle mainBundle] bundleIdentifier],
			_SCNotificationCallback,
			&context
		);
		
		
		// I have no idea what this code does, or why it's needed
		// <magic>
		rlSrc = SCDynamicStoreCreateRunLoopSource(NULL,dynStore,0);
		CFRunLoopAddSource([[NSRunLoop currentRunLoop] getCFRunLoop], rlSrc, kCFRunLoopCommonModes);
		// </magic>

		SCDynamicStoreSetNotificationKeys(
			dynStore, 
			// more ugly hacks... unintelligible oneliners are cool
			(CFArrayRef) [(NSArray *)SCDynamicStoreCopyKeyList(dynStore, CFSTR(".*")) autorelease], 
			NULL
		);
	}
	return self;
}

- (void)dealloc
{
	CFRunLoopRemoveSource([[NSRunLoop currentRunLoop] getCFRunLoop], rlSrc, kCFRunLoopCommonModes);

	CFRelease(rlSrc);
	CFRelease(dynStore);

	[super dealloc];
}

@end
