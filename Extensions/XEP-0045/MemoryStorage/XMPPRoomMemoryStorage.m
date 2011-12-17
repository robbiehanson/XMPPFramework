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
			// message < currentMessage
			
			if (mid == min)
				break;
			else
				max = mid - 1;
		}
		else // Descending || Same
		{
			// message >= currentMessage
			
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
			// occupant < currentOccupant
			
			if (mid == min)
				break;
			else
				max = mid - 1;
		}
		else // Descending || Same
		{
			// occupant >= currentOccupant
			
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

- (void)handlePresence:(XMPPPresence *)presence room:(XMPPRoom *)room
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

- (void)addMessage:(XMPPRoomMessageMemoryStorage *)roomMsg
{
	NSUInteger index = [self insertMessage:roomMsg];
	
	XMPPRoomOccupantMemoryStorage *occupant = [occupantsDict objectForKey:[roomMsg jid]];
	
	XMPPRoomMessageMemoryStorage *roomMsgCopy = [roomMsg copy];
	XMPPRoomOccupantMemoryStorage *occupantCopy = [occupant copy];
	NSArray *messagesCopy = [messages copy];
	
	[[self multicastDelegate] xmppRoomMemoryStorage:self
	                              didReceiveMessage:roomMsgCopy
	                                   fromOccupant:occupantCopy
	                                        atIndex:index
	                                        inArray:messagesCopy];
}

- (void)handleIncomingMessage:(XMPPMessage *)message room:(XMPPRoom *)room
{
	XMPPLogTrace();
	AssertParentQueue();
	
	XMPPJID *msgJID = [message from];
	
	if ([room.myRoomJID isEqualToJID:msgJID])
	{
		// Ignore - we already stored message in handleOutgoingMessage:room:
		return;
	}
	
	XMPPRoomMessageMemoryStorage *roomMessage = [[self.messageClass alloc] initWithIncomingMessage:message];
	
	if (roomMessage.remoteTimestamp && ([messages count] > 0))
	{
		// Does this message already exist in the messages array?
		// How can we tell if two XMPPRoomMessages are the same?
		// 
		// 1. Same jid
		// 2. Same text
		// 3. Same remoteTimestamp
		// 4. Approximately the same localTimestamps (if existing message doesn't have set remoteTimestamp)
		// 
		// This is actually a rather difficult question.
		// What if the same user sends the exact same message multiple times?
		// 
		// If we first received the message while already in the room, it won't contain a remoteTimestamp.
		// Returning to the room later and downloading the discussion history will return the same message,
		// this time with a remote timestamp.
		// 
		// So if the message doesn't have a remoteTimestamp,
		// but it's localTimestamp is approximately the same as the remoteTimestamp,
		// then this is enough evidence to consider the messages the same.
		
		// Algorithm overview:
		// 
		// Since the clock of the client and server may be out of sync,
		// a localTimestamp and remoteTimestamp may be off by several seconds.
		// So we're going to search a range of messages, bounded by a min and max localTimestamp.
		// 
		// We find the first message that has a localTimestamp >= minLocalTimestamp.
		// We then search from there to the first message that has a localTimestamp > maxLocalTimestamp.
		// 
		// This represents our range of messages to search.
		// Then we can simply iterate over these messages to see if any have the same jid and text.
		
		NSDate *minLocalTimestamp = [roomMessage.remoteTimestamp dateByAddingTimeInterval:-60];
		NSDate *maxLocalTimestamp = [roomMessage.remoteTimestamp dateByAddingTimeInterval: 60];
		
		// Use binary search to locate first message with localTimestamp >= minLocalTimestamp.
		
		NSInteger mid;
		NSInteger min = 0;
		NSInteger max = [messages count] - 1;
		
		while (YES)
		{
			mid = (min + max) / 2;
			XMPPRoomMessageMemoryStorage *currentMessage = [messages objectAtIndex:mid];
			
			NSComparisonResult cmp = [minLocalTimestamp compare:[currentMessage localTimestamp]];
			if (cmp == NSOrderedAscending)
			{
				// minLocalTimestamp < currentMessage.localTimestamp
				
				if (mid == min)
					break;
				else
					max = mid - 1;
			}
			else // Descending || Same
			{
				// minLocalTimestamp >= currentMessage.localTimestamp
				
				if (mid == max) {
					mid++;
					break;
				}
				else {
					min = mid + 1;
				}
			}
		}
		
		// The 'mid' variable now points to the index of the first message in the sorted messages array
		// that has a localTimestamp >= minLocalTimestamp.
		// 
		// Now we're going to find the first message in the sorted messages array
		// that has a localTimestamp <= maxLocalTimestamp.
		
		NSRange range = (NSRange){ .location = mid, .length = 0 };
		
		NSInteger index;
		for (index = range.location; index < [messages count]; index++)
		{
			XMPPRoomMessageMemoryStorage *currentMessage = [messages objectAtIndex:index];
			
			NSComparisonResult cmp = [maxLocalTimestamp compare:[currentMessage localTimestamp]];
			if (cmp == NSOrderedAscending)
			{
				// maxLocalTimestamp < currentMessage.localTimestamp
				range.length++;
			}
			else
			{
				// maxLocalTimestamp >= currentMessage.localTimestamp
				break;
			}
		}
		
		// Now search our range to see if the message already exists
		
		for (index = range.location; index < range.length; index++)
		{
			XMPPRoomMessageMemoryStorage *currentMessage = [messages objectAtIndex:mid];
			
			if ([currentMessage.jid isEqualToJID:roomMessage.jid])
			{
				if ([currentMessage.body isEqualToString:roomMessage.body])
				{
					if (currentMessage.remoteTimestamp)
					{
						if ([currentMessage.remoteTimestamp isEqualToDate:roomMessage.remoteTimestamp])
						{
							// 1. jid matches
							// 2. body matches
							// 3. remoteTimestamp matches
							// 
							// Incoming message already exists in the array.
							
							return;
						}
					}
					else
					{
						// 1. jid matches
						// 2. body matches
						// 3. existing message in array doesn't have set remoteTimestamp
						// 4. existing message has approximately the same localTimestamp
						// 
						// Incoming message already exists in the array.
						
						return;
					}
				}
			}
		}
	}
	
	[self addMessage:roomMessage];
}

- (void)handleOutgoingMessage:(XMPPMessage *)message room:(XMPPRoom *)room
{
	XMPPLogTrace();
	AssertParentQueue();
	
	XMPPJID *msgJID = room.myRoomJID;
	
	XMPPRoomMessageMemoryStorage *roomMsg = [[self.messageClass alloc] initWithOutgoingMessage:message jid:msgJID];
	[self addMessage:roomMsg];
}

@end
