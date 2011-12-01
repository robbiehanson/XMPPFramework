#import "XMPPRoomMemoryStorage.h"
#import "XMPPRoomPrivate.h"
#import "XMPP.h"
#import "XMPPLogging.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

#define AssertPrivateQueue() \
        NSAssert(dispatch_get_current_queue() == parentQueue, @"Private method: MUST run on parentQueue");

#define AssertParentQueue() \
        NSAssert(dispatch_get_current_queue() == parentQueue, @"Private protocol method: MUST run on parentQueue");

@interface XMPPRoomMemoryStorage ()
{
	__unsafe_unretained XMPPRoom *parent;
	dispatch_queue_t parentQueue;
	
	NSMutableArray * messages;
	NSMutableArray * occupantsArray;
	NSMutableDictionary * occupantsDict;
	
	Class messageClass;
	Class occupantClass;
}

@property (readonly) dispatch_queue_t parentQueue;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPRoomMemoryStorage

- (id)init
{
	if ((self = [super init]))
	{
		messages  = [[NSMutableArray alloc] init];
		occupantsArray = [[NSMutableArray alloc] init];
		occupantsDict  = [[NSMutableDictionary alloc] init];
		
		messageClass = [XMPPRoomMessageMemoryStorage class];
		occupantClass = [XMPPRoomOccupantMemoryStorage class];
		
		
	}
	return self;
}

- (BOOL)configureWithParent:(XMPPRoom *)aParent queue:(dispatch_queue_t)queue
{
	NSParameterAssert(aParent != nil);
	NSParameterAssert(queue != NULL);
	
	BOOL result = NO;
	
	@synchronized(self)
	{
		if ((parent == nil) && (parentQueue == NULL))
		{
			parent = aParent;
			parentQueue = queue;
			
			dispatch_retain(parentQueue);
			
			result = YES;
		}
	}
	
	return result;
}

- (void)dealloc
{
	if (parentQueue)
		dispatch_release(parentQueue);
	
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@synthesize messageClass;
@synthesize occupantClass;

- (XMPPRoom *)parent
{
	XMPPRoom *result = nil;
	
	@synchronized(self) // synchronized with configureWithParent:queue:
	{
		result = parent;
	}
	
	return result;
}

- (dispatch_queue_t)parentQueue
{
	dispatch_queue_t result = NULL;
	
	@synchronized(self) // synchronized with configureWithParent:queue:
	{
		result = parentQueue;
	}
	
	return result;
}

- (void)setMessageSortSelector:(SEL)messageSortSel
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		
	}};
	
	dispatch_queue_t pq = self.parentQueue;
	
	if (pq == NULL || dispatch_get_current_queue() == pq)
		block();
	else
		dispatch_async(pq, block);
}

- (void)setOccupantSortSelector:(SEL)occupantSortSel
{
	
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Internal API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (GCDMulticastDelegate <XMPPRoomMemoryStorageDelegate> *)multicastDelegate
{
	return (GCDMulticastDelegate <XMPPRoomMemoryStorageDelegate> *)[parent multicastDelegate];
}

- (NSUInteger)insertMessage:(XMPPRoomMessageMemoryStorage *)message
{
	NSUInteger count = [messages count];
	
	if (count == 0)
	{
		[messages addObject:message];
		return 0;
	}
	
	// Shortcut - Most (if not all) messages are inserted at the end
	
	XMPPRoomMessageMemoryStorage *lastMessage = [messages objectAtIndex:(count - 1)];
	if ([message compare:lastMessage] != NSOrderedAscending)
	{
		[messages addObject:message];
		return count;
	}
	
	// Shortcut didn't work.
	// Find location using binary search algorithm.
	
	NSInteger mid;
	NSInteger min = 0;
	NSInteger max = count - 1;
	
	while (YES)
	{
		mid = (min + max) / 2;
		XMPPRoomMessageMemoryStorage *currentMessage = [messages objectAtIndex:mid];
		
		NSComparisonResult cmp = [message compare:currentMessage];
		if (cmp == NSOrderedAscending)
		{
			if (mid == min)
				break;
			else
				max = mid - 1;
		}
		else // Descending || Same
		{
			if (mid == max) {
				mid++;
				break;
			}
			else {
				min = mid + 1;
			}
		}
	}
	
	// Algorithm check:
	// 
	// Insert in array[length] at index (index)
	// : min, mid, max (cmp_result)
	// 
	// 
	// Insert in array[3] at index (0)
	// : 0, 1, 2 (asc)
	// : 0, 0, 0 (asc) break
	// 
	// Insert in array[3] at index (1)
	// : 0, 1, 2 (asc)
	// : 0, 0, 0 (dsc) mid++, break
	// 
	// Insert in array[3] at index (2)
	// : 0, 1, 2 (dsc)
	// : 2, 2, 2 (asc) break
	// 
	// Insert in array[3] at index (3)
	// : 0, 1, 2 (dsc)
	// : 2, 2, 2 (dsc) mid++, break
	
	[messages insertObject:message atIndex:mid];
	return (NSUInteger)mid;
}

- (NSUInteger)insertOccupant:(XMPPRoomOccupantMemoryStorage *)occupant
{
	NSUInteger count = [occupantsArray count];
	
	if (count == 0)
	{
		[occupantsArray addObject:occupant];
		return 0;
	}
	
	// Find location using binary search algorithm.
	
	NSInteger mid;
	NSInteger min = 0;
	NSInteger max = count - 1;
	
	while (YES)
	{
		mid = (min + max) / 2;
		XMPPRoomOccupantMemoryStorage *currentOccupant = [occupantsArray objectAtIndex:mid];
		
		NSComparisonResult cmp = [occupant compare:currentOccupant];
		if (cmp == NSOrderedAscending)
		{
			if (mid == min)
				break;
			else
				max = mid - 1;
		}
		else // Descending || Same
		{
			if (mid == max) {
				mid++;
				break;
			}
			else {
				min = mid + 1;
			}
		}
	}
	
	[occupantsArray insertObject:occupant atIndex:mid];
	return (NSUInteger)mid;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Public API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (XMPPRoomOccupantMemoryStorage *)occupantForJID:(XMPPJID *)jid
{
	XMPPLogTrace();
	
	if (self.parentQueue == NULL)
	{
		// Haven't been attached to parent yet
		return nil;
	}
	
	__block XMPPRoomOccupantMemoryStorage *occupant = nil;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		occupant = [occupantsDict objectForKey:jid];
	}};
	
	if (dispatch_get_current_queue() == parentQueue)
		block();
	else
		dispatch_sync(parentQueue, block);
	
	return occupant;
}

- (NSArray *)messages
{
	XMPPLogTrace();
	
	if (self.parentQueue == NULL)
	{
		// Haven't been attached to parent yet
		return nil;
	}
	
	__block NSArray *result = nil;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		result = [messages copy];
	}};
	
	if (dispatch_get_current_queue() == parentQueue)
		block();
	else
		dispatch_sync(parentQueue, block);
	
	return result;
}

- (NSArray *)occupants
{
	XMPPLogTrace();
	
	if (self.parentQueue == NULL)
	{
		// Haven't been attached to parent yet
		return nil;
	}
	
	__block NSArray *result = nil;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		result = [occupantsArray copy];
	}};
	
	if (dispatch_get_current_queue() == parentQueue)
		block();
	else
		dispatch_sync(parentQueue, block);
	
	return result;
}

- (NSArray *)resortMessages
{
	XMPPLogTrace();
	
	if (self.parentQueue == NULL)
	{
		// Haven't been attached to parent yet
		return nil;
	}
	
	__block NSArray *result = nil;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		[messages sortUsingSelector:@selector(compare:)];
		result = [messages copy];
	}};
	
	if (dispatch_get_current_queue() == parentQueue)
		block();
	else
		dispatch_sync(parentQueue, block);
	
	return result;
}

- (NSArray *)resortOccupants
{
	XMPPLogTrace();
	
	if (self.parentQueue == NULL)
	{
		// Haven't been attached to parent yet
		return nil;
	}
	
	__block NSArray *result = nil;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		[occupantsArray sortUsingSelector:@selector(compare:)];
		result = [occupantsArray copy];
	}};
	
	if (dispatch_get_current_queue() == parentQueue)
		block();
	else
		dispatch_sync(parentQueue, block);
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPRoomStorage Protocol
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)handlePresence:(XMPPPresence *)presence xmppStream:(XMPPStream *)xmppStream
{
	XMPPLogTrace();
	AssertParentQueue();
	
	XMPPJID *from = [presence from];
	
	if ([[presence type] isEqualToString:@"unavailable"])
	{
		XMPPRoomOccupantMemoryStorage *occupant = [occupantsDict objectForKey:from];
		if (occupant)
		{
			// Occupant did leave - remove
			
			NSUInteger index = [occupantsArray indexOfObjectIdenticalTo:occupant];
			
			[occupantsArray removeObjectAtIndex:index];
			[occupantsDict removeObjectForKey:from];
			
			// Notify delegate(s)
			
			XMPPRoomOccupantMemoryStorage *occupantCopy = [occupant copy];
			NSMutableArray *occupantsCopy = [occupantsArray copy];
			
			[[self multicastDelegate] xmppRoomMemoryStorage:self
			                               occupantDidLeave:occupantCopy
			                                        atIndex:index
			                                      fromArray:occupantsCopy];
		}
	}
	else
	{
		XMPPRoomOccupantMemoryStorage *occupant = [occupantsDict objectForKey:from];
		if (occupant == nil)
		{
			// Occupant did join - add
			
			occupant = [[self.occupantClass alloc] initWithPresence:presence];
			
			NSUInteger index = [self insertOccupant:occupant];
			[occupantsDict setObject:occupant forKey:from];
			
			// Notify delegate(s)
			
			XMPPRoomOccupantMemoryStorage *occupantCopy = [occupant copy];
			NSMutableArray *occupantsCopy = [occupantsArray copy];
			
			[[self multicastDelegate] xmppRoomMemoryStorage:self
			                                occupantDidJoin:occupantCopy
			                                        atIndex:index
			                                        inArray:occupantsCopy];
		}
		else
		{
			// Occupant did update - move
			
			[occupant updateWithPresence:presence];
			
			NSUInteger oldIndex = [occupantsArray indexOfObjectIdenticalTo:occupant];
			[occupantsArray removeObjectAtIndex:oldIndex];
			NSUInteger newIndex = [self insertOccupant:occupant];
			
			// Notify delegate(s)
			
			XMPPRoomOccupantMemoryStorage *occupantCopy = [occupant copy];
			NSMutableArray *occupantsCopy = [occupantsArray copy];
			
			[[self multicastDelegate] xmppRoomMemoryStorage:self
			                              occupantDidUpdate:occupantCopy
			                                      fromIndex:oldIndex
			                                        toIndex:newIndex
			                                        inArray:occupantsCopy];
		}
	}
}

- (void)handleMessage:(XMPPMessage *)message xmppStream:(XMPPStream *)xmppStream
{
	XMPPRoomMessageMemoryStorage *roomMessage = [[self.messageClass alloc] initWithMessage:message];
	NSUInteger index = [self insertMessage:roomMessage];
	
	XMPPRoomOccupantMemoryStorage *occupant = [occupantsDict objectForKey:[message from]];
	
	XMPPRoomMessageMemoryStorage *roomMessageCopy = [roomMessage copy];
	XMPPRoomOccupantMemoryStorage *occupantCopy = [occupant copy];
	NSArray *messagesCopy = [messages copy];
	
	[[self multicastDelegate] xmppRoomMemoryStorage:self
	                              didReceiveMessage:roomMessageCopy
	                                   fromOccupant:occupantCopy
	                                        atIndex:index
	                                        inArray:messagesCopy];
}

- (void)handleOutgoingMessage:(XMPPMessage *)message xmppStream:(XMPPStream *)xmppStream
{
	XMPPLogTrace();
	AssertParentQueue();
	
	[self handleMessage:message xmppStream:xmppStream];
}

- (void)handleIncomingMessage:(XMPPMessage *)message xmppStream:(XMPPStream *)xmppStream
{
	XMPPLogTrace();
	AssertParentQueue();
	
	if ([parent.myRoomJID isEqualToJID:[message from]])
	{
		// Ignore - we already stored message in handleOutgoingMessage:xmppStream:
		return;
	}
	
	[self handleMessage:message xmppStream:xmppStream];
}

@end
