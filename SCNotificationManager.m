/*
 * Written by Theo Hultberg (theo@iconara.net) 2004-03-09 with help from Boaz Stuller.
 * This code is in the public domain, provided that this notice remains.
 */

#import "SCNotificationManager.h"


void _SCNotificationCallback(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSEnumerator *keysE = [(NSArray *)changedKeys objectEnumerator];
	NSString *key = nil;
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	
	while((key = [keysE nextObject]))
	{		
		[nc postNotificationName:key 
						  object:(id)info 
		                userInfo:[(NSDictionary *)SCDynamicStoreCopyValue(store, (CFStringRef) key) autorelease]];
	}
	
	[pool release];
}


@implementation SCNotificationManager

- (id)init
{
	if((self = [super init]))
	{
		SCDynamicStoreContext context = { 0, (void *)self, NULL, NULL, NULL };
		
		dynStore = SCDynamicStoreCreate(
			NULL, 
			(CFStringRef) [[NSBundle mainBundle] bundleIdentifier],
			_SCNotificationCallback,
			&context
		);
		
		// Add to runloop to receive automatic callbacks to our SCNotificationCallback method
		rlSrc = SCDynamicStoreCreateRunLoopSource(NULL, dynStore, 0);
		CFRunLoopAddSource([[NSRunLoop currentRunLoop] getCFRunLoop], rlSrc, kCFRunLoopCommonModes);
		
		SCDynamicStoreSetNotificationKeys(
			dynStore, 
			(CFArrayRef) [(NSArray *)SCDynamicStoreCopyKeyList(dynStore, CFSTR(".*")) autorelease], 
			NULL
		);
	}
	return self;
}

- (void)dealloc
{
	CFRunLoopRemoveSource([[NSRunLoop currentRunLoop] getCFRunLoop], rlSrc, kCFRunLoopCommonModes);

	if(rlSrc) CFRelease(rlSrc);
	if(dynStore) CFRelease(dynStore);

	[super dealloc];
}

@end
