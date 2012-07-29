#import "XMPPRoomMemoryStorage.h"
#import "XMPPRoomPrivate.h"
#import "XMPP.h"
#import "XMPPElement+Delay.h"
#import "XMPPLogging.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

/**
 * Does ARC support support GCD objects?
 * It does if the minimum deployment target is iOS 6+ or Mac OS X 10.8+
**/
#if TARGET_OS_IPHONE

  // Compiling for iOS

  #if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000 // iOS 6.0 or later
    #define NEEDS_DISPATCH_RETAIN_RELEASE 0
  #else                                         // iOS 5.X or earlier
    #define NEEDS_DISPATCH_RETAIN_RELEASE 1
  #endif

#else

  // Compiling for Mac OS X

  #if MAC_OS_X_VERSION_MIN_REQUIRED >= 1080     // Mac OS X 10.8 or later
    #define NEEDS_DISPATCH_RETAIN_RELEASE 0
  #else
    #define NEEDS_DISPATCH_RETAIN_RELEASE 1     // Mac OS X 10.7 or earlier
  #endif

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
  #if __has_feature(objc_arc_weak)
	__weak XMPPRoom *parent;
  #else
	__unsafe_unretained XMPPRoom *parent;
  #endif
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
		
		messageClass = [XMPPRoomMessageMemoryStorageObject class];
		occupantClass = [XMPPRoomOccupantMemoryStorageObject class];
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
			
			#if NEEDS_DISPATCH_RETAIN_RELEASE
			dispatch_retain(parentQueue);
			#endif
			
			result = YES;
		}
	}
	
	return result;
}

- (GCDMulticastDelegate <XMPPRoomMemoryStorageDelegate> *)multicastDelegate
{
	return (GCDMulticastDelegate <XMPPRoomMemoryStorageDelegate> *)[parent multicastDelegate];
}

- (void)dealloc
{
	#if NEEDS_DISPATCH_RETAIN_RELEASE
	if (parentQueue)
		dispatch_release(parentQueue);
	#endif
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

- (BOOL)existsMessage:(XMPPMessage *)message
{
	NSDate *remoteTimestamp = [message delayedDeliveryDate];
	
	if (remoteTimestamp == nil)
	{
		// When the xmpp server sends us a room message, it will always timestamp delayed messages.
		// For example, when retrieving the discussion history, all messages will include the original timestamp.
		// If a message doesn't include such timestamp, then we know we're getting it in "real time".
		
		return NO;
	}
	
	if ([messages count] == 0)
	{
		// Safety net for binary search algorithm used below
		
		return NO;
	}
	
	
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
	
	NSDate *minLocalTimestamp = [remoteTimestamp dateByAddingTimeInterval:-60];
	NSDate *maxLocalTimestamp = [remoteTimestamp dateByAddingTimeInterval: 60];
	
	// Use binary search to locate first message with localTimestamp >= minLocalTimestamp.
	
	NSInteger mid;
	NSInteger min = 0;
	NSInteger max = [messages count] - 1;
	
	while (YES)
	{
		mid = (min + max) / 2;
		XMPPRoomMessageMemoryStorageObject *currentMessage = [messages objectAtIndex:mid];
		
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
	// We're going to start looking for matching messages here,
	// and break if we find a message with localTimestamp <= maxLocalTimestamp.
	
	XMPPJID *messageJid = [message from];
	NSString *messageBody = [[message elementForName:@"body"] stringValue];
	
	NSInteger index;
	for (index = mid; index < [messages count]; index++)
	{
		XMPPRoomMessageMemoryStorageObject *currentMessage = [messages objectAtIndex:index];
		
		NSComparisonResult cmp = [maxLocalTimestamp compare:[currentMessage localTimestamp]];
		if (cmp != NSOrderedAscending)
		{
			// maxLocalTimestamp >= currentMessage.localTimestamp
			break;
		}
		
		if ([currentMessage.jid isEqualToJID:messageJid])
		{
			if ([currentMessage.body isEqualToString:messageBody])
			{
				if (currentMessage.remoteTimestamp)
				{
					if ([currentMessage.remoteTimestamp isEqualToDate:remoteTimestamp])
					{
						// 1. jid matches
						// 2. body matches
						// 3. remoteTimestamp matches
						// 
						// => Incoming message already exists in the array.
						
						return YES;
					}
				}
				else
				{
					// 1. jid matches
					// 2. body matches
					// 3. existing message in array doesn't have set remoteTimestamp
					// 4. existing message has approximately the same localTimestamp
					// 
					// => Incoming message already exists in the array.
					
					return YES;
				}
			}
		}
	}

	return NO;
}

- (NSUInteger)insertMessage:(XMPPRoomMessageMemoryStorageObject *)message
{
	NSUInteger count = [messages count];
	
	if (count == 0)
	{
		[messages addObject:message];
		return 0;
	}
	
	// Shortcut - Most (if not all) messages are inserted at the end
	
	XMPPRoomMessageMemoryStorageObject *lastMessage = [messages objectAtIndex:(count - 1)];
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
		XMPPRoomMessageMemoryStorageObject *currentMessage = [messages objectAtIndex:mid];
		
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

- (void)addMessage:(XMPPRoomMessageMemoryStorageObject *)roomMsg
{
	NSUInteger index = [self insertMessage:roomMsg];
	
	XMPPRoomOccupantMemoryStorageObject *occupant = [occupantsDict objectForKey:[roomMsg jid]];
	
	XMPPRoomMessageMemoryStorageObject *roomMsgCopy = [roomMsg copy];
	XMPPRoomOccupantMemoryStorageObject *occupantCopy = [occupant copy];
	NSArray *messagesCopy = [[NSArray alloc] initWithArray:messages copyItems:YES];
	
	[[self multicastDelegate] xmppRoomMemoryStorage:self
	                              didReceiveMessage:roomMsgCopy
	                                   fromOccupant:occupantCopy
	                                        atIndex:index
	                                        inArray:messagesCopy];
}

- (NSUInteger)insertOccupant:(XMPPRoomOccupantMemoryStorageObject *)occupant
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
		XMPPRoomOccupantMemoryStorageObject *currentOccupant = [occupantsArray objectAtIndex:mid];
		
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

- (XMPPRoomOccupantMemoryStorageObject *)occupantForJID:(XMPPJID *)jid
{
	XMPPLogTrace();
	
	if (self.parentQueue == NULL)
	{
		// Haven't been attached to parent yet
		return nil;
	}
	
	if (dispatch_get_current_queue() == parentQueue)
	{
		return [occupantsDict objectForKey:jid];
	}
	else
	{
		__block XMPPRoomOccupantMemoryStorageObject *occupant = nil;
		
		dispatch_sync(parentQueue, ^{ @autoreleasepool {
			
			occupant = [[occupantsDict objectForKey:jid] copy];
		}});
		
		return occupant;
	}
}

- (NSArray *)messages
{
	XMPPLogTrace();
	
	if (self.parentQueue == NULL)
	{
		// Haven't been attached to parent yet
		return nil;
	}
	
	if (dispatch_get_current_queue() == parentQueue)
	{
		return messages;
	}
	else
	{
		__block NSArray *result = nil;
		
		dispatch_sync(parentQueue, ^{ @autoreleasepool {
			
			result = [[NSArray alloc] initWithArray:messages copyItems:YES];
		}});
		
		return result;
	}
}

- (NSArray *)occupants
{
	XMPPLogTrace();
	
	if (self.parentQueue == NULL)
	{
		// Haven't been attached to parent yet
		return nil;
	}
	
	if (dispatch_get_current_queue() == parentQueue)
	{
		return occupantsArray;
	}
	else
	{
		__block NSArray *result = nil;
		
		dispatch_sync(parentQueue, ^{ @autoreleasepool {
			
			result = [[NSArray alloc] initWithArray:occupantsArray copyItems:YES];
		}});
		
		return result;
	}
}

- (NSArray *)resortMessages
{
	XMPPLogTrace();
	
	if (self.parentQueue == NULL)
	{
		// Haven't been attached to parent yet
		return nil;
	}
	
	if (dispatch_get_current_queue() == parentQueue)
	{
		[messages sortUsingSelector:@selector(compare:)];
		return messages;
	}
	else
	{
		__block NSArray *result = nil;
		
		dispatch_sync(parentQueue, ^{ @autoreleasepool {
			
			[messages sortUsingSelector:@selector(compare:)];
			result = [[NSArray alloc] initWithArray:messages copyItems:YES];
		}});
		
		return result;
	}
}

- (NSArray *)resortOccupants
{
	XMPPLogTrace();
	
	if (self.parentQueue == NULL)
	{
		// Haven't been attached to parent yet
		return nil;
	}
	
	if (dispatch_get_current_queue() == parentQueue)
	{
		[occupantsArray sortUsingSelector:@selector(compare:)];
		return occupantsArray;
	}
	else
	{
		__block NSArray *result = nil;
		
		dispatch_sync(parentQueue, ^{ @autoreleasepool {
			
			[occupantsArray sortUsingSelector:@selector(compare:)];
			result = [[NSArray alloc] initWithArray:occupantsArray copyItems:YES];
		}});
		
		return result;
	}
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
		XMPPRoomOccupantMemoryStorageObject *occupant = [occupantsDict objectForKey:from];
		if (occupant)
		{
			// Occupant did leave - remove
			
			NSUInteger index = [occupantsArray indexOfObjectIdenticalTo:occupant];
			
			[occupantsArray removeObjectAtIndex:index];
			[occupantsDict removeObjectForKey:from];
			
			// Notify delegate(s)
			
			XMPPRoomOccupantMemoryStorageObject *occupantCopy = [occupant copy];
			NSArray *occupantsCopy = [[NSArray alloc] initWithArray:occupantsArray copyItems:YES];
			
			[[self multicastDelegate] xmppRoomMemoryStorage:self
			                               occupantDidLeave:occupantCopy
			                                        atIndex:index
			                                      fromArray:occupantsCopy];
		}
	}
	else
	{
		XMPPRoomOccupantMemoryStorageObject *occupant = [occupantsDict objectForKey:from];
		if (occupant == nil)
		{
			// Occupant did join - add
			
			occupant = [[self.occupantClass alloc] initWithPresence:presence];
			
			NSUInteger index = [self insertOccupant:occupant];
			[occupantsDict setObject:occupant forKey:from];
			
			// Notify delegate(s)
			
			XMPPRoomOccupantMemoryStorageObject *occupantCopy = [occupant copy];
			NSArray *occupantsCopy = [[NSArray alloc] initWithArray:occupantsArray copyItems:YES];
			
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
			
			XMPPRoomOccupantMemoryStorageObject *occupantCopy = [occupant copy];
			NSArray *occupantsCopy = [[NSArray alloc] initWithArray:occupantsArray copyItems:YES];
			
			[[self multicastDelegate] xmppRoomMemoryStorage:self
			                              occupantDidUpdate:occupantCopy
			                                      fromIndex:oldIndex
			                                        toIndex:newIndex
			                                        inArray:occupantsCopy];
		}
	}
}

- (void)handleOutgoingMessage:(XMPPMessage *)message room:(XMPPRoom *)room
{
	XMPPLogTrace();
	AssertParentQueue();
	
	XMPPJID *msgJID = room.myRoomJID;
	
	XMPPRoomMessageMemoryStorageObject *roomMsg;
	roomMsg = [[self.messageClass alloc] initWithOutgoingMessage:message jid:msgJID];
	
	[self addMessage:roomMsg];
}

- (void)handleIncomingMessage:(XMPPMessage *)message room:(XMPPRoom *)room
{
	XMPPLogTrace();
	AssertParentQueue();
	
	XMPPJID *msgJID = [message from];
	
	if ([room.myRoomJID isEqualToJID:msgJID])
	{
		if (![message wasDelayed])
		{
			// Ignore - we already stored message in handleOutgoingMessage:room:
			return;
		}
	}
	
	if ([self existsMessage:message])
	{
		XMPPLogVerbose(@"%@: %@ - Duplicate message", THIS_FILE, THIS_METHOD);
	}
	else
	{
		XMPPRoomMessageMemoryStorageObject *roomMessage = [[self.messageClass alloc] initWithIncomingMessage:message];
		[self addMessage:roomMessage];
	}
}

- (void)handleDidLeaveRoom:(XMPPRoom *)room
{
	XMPPLogTrace();
	AssertParentQueue();
	
	[occupantsDict removeAllObjects];
	[occupantsArray removeAllObjects];
}

@end
