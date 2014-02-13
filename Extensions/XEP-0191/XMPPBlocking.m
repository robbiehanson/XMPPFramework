#import "XMPP.h"
#import "XMPPLogging.h"
#import "XMPPBlocking.h"
#import "NSNumber+XMPP.h"

// Log levels: off, error, warn, info, verbose
// Log flags: trace
#ifdef DEBUG
static const int xmppLogLevel = XMPP_LOG_LEVEL_VERBOSE; // | XMPP_LOG_FLAG_TRACE;
#else
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

#define QUERY_TIMEOUT 30.0 // NSTimeInterval (double) = seconds

NSString *const XMPPBlockingErrorDomain = @"XMPPBlockingErrorDomain";

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

typedef enum XMPPBlockingQueryInfoType {
    FetchBlockingList,
	BlockUser,
    UnblockUser,
    UnblockAll,
	
} XMPPBlockingQueryInfoType;

@interface XMPPBlockingQueryInfo : NSObject
{
	XMPPBlockingQueryInfoType type;
    XMPPJID *blockingXMPPJID;
	NSArray *blockingListItems;
	
	dispatch_source_t timer;
}

@property (nonatomic, readonly) XMPPBlockingQueryInfoType type;
@property (nonatomic, readonly) NSArray *blockingListItems;

@property (nonatomic, readwrite) XMPPJID *blockingXMPPJID;
@property (nonatomic, readwrite) dispatch_source_t timer;

- (void)cancel;

+ (XMPPBlockingQueryInfo *)queryInfoWithType:(XMPPBlockingQueryInfoType)type;
+ (XMPPBlockingQueryInfo *)queryInfoWithType:(XMPPBlockingQueryInfoType)type jid:(XMPPJID *)jid;
+ (XMPPBlockingQueryInfo *)queryInfoWithType:(XMPPBlockingQueryInfoType)type jid:(XMPPJID *)jid items:(NSArray *)items;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface XMPPBlocking (/* Must be nameless for properties */)

- (void)addQueryInfo:(XMPPBlockingQueryInfo *)qi withKey:(NSString *)uuid;
- (void)queryTimeout:(NSString *)uuid;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPBlocking

@synthesize blockingDict = _blockingDict;

- (id)init
{
	return [self initWithDispatchQueue:NULL];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	if ((self = [super initWithDispatchQueue:queue]))
	{
		autoRetrieveBlockingListItems = YES;
		autoClearBlockingListInfo     = YES;
		
		blockingDict = [[NSMutableDictionary alloc] init];
		
		pendingQueries = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (BOOL)activate:(XMPPStream *)aXmppStream
{
	if ([super activate:aXmppStream])
	{
		// Reserved for possible future use.
		
		return YES;
	}
	
	return NO;
}

- (void)deactivate
{
	// Reserved for possible future use.
	
	[super deactivate];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)autoRetrieveBlockingListItems
{
	if (dispatch_get_specific(moduleQueueTag))
	{
		return autoRetrieveBlockingListItems;
	}
	else
	{
		__block BOOL result;
		
		dispatch_sync(moduleQueue, ^{
			result = autoRetrieveBlockingListItems;
		});
		
		return result;
	}
}

- (void)setAutoRetrieveBlockingListItems:(BOOL)flag
{
	dispatch_block_t block = ^{
		
		autoRetrieveBlockingListItems = flag;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (BOOL)autoClearBlockingListInfo
{
	if (dispatch_get_specific(moduleQueueTag))
	{
		return autoClearBlockingListInfo;
	}
	else
	{
		__block BOOL result;
		
		dispatch_sync(moduleQueue, ^{
			result = autoClearBlockingListInfo;
		});
		
		return result;
	}
}

- (void)setAutoClearBlockingListInfo:(BOOL)flag
{
	dispatch_block_t block = ^{
		
		autoClearBlockingListInfo = flag;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Public API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)retrieveBlockingListItems
{
    XMPPLogTrace();
	
    // <iq type='get' id='blocklist1'>
    // <blocklist xmlns='urn:xmpp:blocking'/>
    // </iq>

    NSXMLElement *block = [NSXMLElement elementWithName:@"blocklist" xmlns:@"urn:xmpp:blocking"];

    NSString *uuid = [xmppStream generateUUID];
    XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:nil elementID:uuid child:block];
    
    [xmppStream sendElement:iq];
    
    XMPPBlockingQueryInfo *qi = [XMPPBlockingQueryInfo queryInfoWithType:FetchBlockingList];
	[self addQueryInfo:qi withKey:uuid];
}

- (void)clearBlockingListInfo
{
	XMPPLogTrace();
	
	if (dispatch_get_specific(moduleQueueTag))
	{
		[blockingDict removeAllObjects];
	}
	else
	{
		dispatch_async(moduleQueue, ^{ @autoreleasepool {
			
			[blockingDict removeAllObjects];
		}});
	}
}

- (NSArray*)blockingList
{
	if (dispatch_get_specific(moduleQueueTag))
	{
		return [blockingDict allKeys];
	}
	else
	{
		__block NSArray *result;
		
		dispatch_sync(moduleQueue, ^{ @autoreleasepool {
			
			result = [[blockingDict allKeys] copy];
		}});
		
		return result;
	}
}

- (void)blockJID:(XMPPJID*)xmppJID
{
    XMPPLogTrace();
    
    id value = [blockingDict objectForKey:[xmppJID full]];
    if (value == nil)
    {
        [blockingDict setObject:[NSNull null] forKey:[xmppJID full]];
    }
    
    // <iq from='juliet@capulet.com/chamber' type='set' id='block1'>
    // <block xmlns='urn:xmpp:blocking'>
    // <item jid='romeo@montague.net'/>
    // </block>
    // </iq>
    
    NSXMLElement *block = [NSXMLElement elementWithName:@"block" xmlns:@"urn:xmpp:blocking"];
    NSXMLElement *item = [NSXMLElement elementWithName:@"item"];
    [item addAttributeWithName:@"jid" stringValue:[xmppJID full]];
    [block addChild:item];
    
    NSString *uuid = [xmppStream generateUUID];
    XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:nil elementID:uuid child:block];
    [iq addAttributeWithName:@"from" stringValue:xmppStream.myJID.bare];
    
    [xmppStream sendElement:iq];
    
    XMPPBlockingQueryInfo *qi = [XMPPBlockingQueryInfo queryInfoWithType:BlockUser];
    qi.blockingXMPPJID = xmppJID;
    [self addQueryInfo:qi withKey:uuid];
}

- (void)unblockJID:(XMPPJID*)xmppJID
{
    XMPPLogTrace();
    
    id value = [blockingDict objectForKey:[xmppJID full]];
    if (value != nil)
    {
        [blockingDict removeObjectForKey:[xmppJID full]];
    }
    
    // <iq type='set' id='unblock1'>
    // <unblock xmlns='urn:xmpp:blocking'>
    // <item jid='romeo@montague.net'/>
    // </unblock>
    // </iq>
    
    NSXMLElement *block = [NSXMLElement elementWithName:@"unblock" xmlns:@"urn:xmpp:blocking"];
    NSXMLElement *item = [NSXMLElement elementWithName:@"item"];
    [item addAttributeWithName:@"jid" stringValue:[xmppJID full]];
    [block addChild:item];
    
    NSString *uuid = [xmppStream generateUUID];
    XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:nil elementID:uuid child:block];
    
    [xmppStream sendElement:iq];
    
    XMPPBlockingQueryInfo *qi = [XMPPBlockingQueryInfo queryInfoWithType:UnblockUser];
    qi.blockingXMPPJID = xmppJID;
	[self addQueryInfo:qi withKey:uuid];
}

- (BOOL)containsJID:(XMPPJID*)xmppJID
{
    if ([blockingDict objectForKey:[xmppJID full]])
    {
        return true;
    }
    return false;
}

/**
 * Unblock all.
 */
- (void)unblockAll
{
    XMPPLogTrace();
    
    // <iq type='set' id='unblock2'>
    // <unblock xmlns='urn:xmpp:blocking'/>
    // </iq>

     NSXMLElement *block = [NSXMLElement elementWithName:@"unblock" xmlns:@"urn:xmpp:blocking"];
    
    NSString *uuid = [xmppStream generateUUID];
    XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:nil elementID:uuid child:block];
    
    [xmppStream sendElement:iq];
    
    XMPPBlockingQueryInfo *qi = [XMPPBlockingQueryInfo queryInfoWithType:UnblockAll];
	[self addQueryInfo:qi withKey:uuid];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Query Processing
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)addQueryInfo:(XMPPBlockingQueryInfo *)queryInfo withKey:(NSString *)uuid
{
	// Setup timer
	
	dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, moduleQueue);
	
	dispatch_source_set_event_handler(timer, ^{ @autoreleasepool {
		
		[self queryTimeout:uuid];
	}});
	
	dispatch_time_t fireTime = dispatch_time(DISPATCH_TIME_NOW, (QUERY_TIMEOUT * NSEC_PER_SEC));
	
	dispatch_source_set_timer(timer, fireTime, DISPATCH_TIME_FOREVER, 1.0);
	dispatch_resume(timer);
	
	queryInfo.timer = timer;
	
	// Add to dictionary
	[pendingQueries setObject:queryInfo forKey:uuid];
}

- (void)removeQueryInfo:(XMPPBlockingQueryInfo *)queryInfo withKey:(NSString *)uuid
{
	// Invalidate timer
	[queryInfo cancel];
	
	// Remove from dictionary
	[pendingQueries removeObjectForKey:uuid];
}

- (void)processQuery:(XMPPBlockingQueryInfo *)queryInfo withFailureCode:(XMPPBlockingErrorCode)errorCode
{
	NSError *error = [NSError errorWithDomain:XMPPBlockingErrorDomain code:errorCode userInfo:nil];
    
	if (queryInfo.type == FetchBlockingList)
	{
		[multicastDelegate xmppBlocking:self didNotReceivedBlockingListDueToError:error];
	}
	else if (queryInfo.type == BlockUser)
	{
		[multicastDelegate xmppBlocking:self didNotBlockJID:queryInfo.blockingXMPPJID error:error];
	}
	else if (queryInfo.type == UnblockUser)
	{
		[multicastDelegate xmppBlocking:self didNotUnblockJID:queryInfo.blockingXMPPJID error:error];
	}
    else if (queryInfo.type == UnblockAll)
    {
        [multicastDelegate xmppBlocking:self didNotUnblockAllDueToError:error];
    }
}

- (void)queryTimeout:(NSString *)uuid
{
	XMPPBlockingQueryInfo *queryInfo = [pendingQueries objectForKey:uuid];
	if (queryInfo)
	{
		[self processQuery:queryInfo withFailureCode:XMPPBlockingQueryTimeout];
		[self removeQueryInfo:queryInfo withKey:uuid];
	}
}

- (void)processQueryResponse:(XMPPIQ *)iq withInfo:(XMPPBlockingQueryInfo *)queryInfo
{
	if (queryInfo.type == FetchBlockingList)
	{
        // Blocking List Query Response:
        //
        // <iq type='result' id='blocklist1'>
        // <blocklist xmlns='urn:xmpp:blocking'>
        // <item jid='romeo@montague.net'/>
        // <item jid='iago@shakespeare.lit'/>
        // </blocklist>
        // </iq>

		if ([[iq type] isEqualToString:@"result"])
		{
			NSXMLElement *blocklist = [iq elementForName:@"blocklist" xmlns:@"urn:xmpp:blocking"];
			if (blocklist == nil) return;

			NSArray *listItems = [blocklist elementsForName:@"item"];
			for (NSXMLElement *listItem in listItems)
			{
				NSString *name = [listItem attributeStringValueForName:@"jid"];
				if (name)
				{
					id value = [blockingDict objectForKey:name];
					if (value == nil)
					{
						[blockingDict setObject:[NSNull null] forKey:name];
					}
				}
			}

			[multicastDelegate xmppBlocking:self didReceivedBlockingList:[self blockingList]];
            [self removeQueryInfo:queryInfo withKey:[iq elementID]];
		}
		else
		{
			[multicastDelegate xmppBlocking:self didNotReceivedBlockingListDueToError:iq];
		}
	}
    else if (queryInfo.type == BlockUser)
    {
        // <iq type='result' id='block1'/>
    
        if ([[iq type] isEqualToString:@"result"])
		{
            [self removeQueryInfo:queryInfo withKey:[iq elementID]];
            [multicastDelegate xmppBlocking:self didBlockJID:queryInfo.blockingXMPPJID];
        }
        else
        {
            [blockingDict removeObjectForKey:[queryInfo.blockingXMPPJID full]];
            [multicastDelegate xmppBlocking:self didNotBlockJID:queryInfo.blockingXMPPJID error:iq];
        }
    }
    else if (queryInfo.type == UnblockUser)
    {
        // <iq type='result' id='unblock1'/>
        
        if ([[iq type] isEqualToString:@"result"])
		{
             [self removeQueryInfo:queryInfo withKey:[iq elementID]];
            [multicastDelegate xmppBlocking:self didUnblockJID:queryInfo.blockingXMPPJID];
        }
        else
        {
            XMPPBlockingQueryInfo *queryInfo = [pendingQueries objectForKey:[iq elementID]];
            
            id value = [blockingDict objectForKey:[queryInfo.blockingXMPPJID full]];
            if (value == nil)
            {
                [blockingDict setObject:[NSNull null] forKey:[queryInfo.blockingXMPPJID full]];
            }
            
            [multicastDelegate xmppBlocking:self didNotBlockJID:queryInfo.blockingXMPPJID error:iq];
        }
    }
    else if (queryInfo.type == UnblockAll)
    {
        // <iq type='result' id='unblock2'/>
        
        if ([[iq type] isEqualToString:@"result"])
		{
            [self removeQueryInfo:queryInfo withKey:[iq elementID]];
            [multicastDelegate xmppBlocking:self didUnblockAllWithError:nil];
        }
        else
        {
            XMPPBlockingQueryInfo *queryInfo = [pendingQueries objectForKey:[iq elementID]];
            
            id value = [blockingDict objectForKey:[queryInfo.blockingXMPPJID full]];
            if (value == nil)
            {
                [blockingDict setObject:[NSNull null] forKey:queryInfo.blockingXMPPJID];
            }
            
            [multicastDelegate xmppBlocking:self didNotUnblockAllDueToError:iq];
        }
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	if (self.autoRetrieveBlockingListItems)
	{
		[self retrieveBlockingListItems];
	}
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	NSString *type = [iq type];
	
	if ([type isEqualToString:@"set"])
	{
		NSXMLElement *block = [iq elementForName:@"block" xmlns:@"urn:xmpp:blocking"];
        NSXMLElement *unblock = [iq elementForName:@"unblock" xmlns:@"urn:xmpp:blocking"];

		if (block || unblock)
		{
            NSXMLElement *list = [block elementForName:@"item"];
            
            if (!list)
            {
                list = [unblock elementForName:@"item"];
            }
            
            NSString *itemName = [list attributeStringValueForName:@"jid"];
			if (itemName == nil)
			{
				return NO;
			}
            
            [multicastDelegate xmppBlocking:self didReceivePushWithBlockingList:itemName];
			
			XMPPIQ *iqResponse = [XMPPIQ iqWithType:@"result" to:[iq from] elementID:[iq elementID]];
			[xmppStream sendElement:iqResponse];
			
			if (self.autoRetrieveBlockingListItems)
			{
				[self retrieveBlockingListItems];
			}
			
			return YES;
		}
	}
	else
	{
		// This may be a response to a query we sent
		
		XMPPBlockingQueryInfo *queryInfo = [pendingQueries objectForKey:[iq elementID]];

        
		if (queryInfo)
		{
			[self processQueryResponse:iq withInfo:queryInfo];

			return YES;
		}
	}
	
	return NO;
}

-(void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
	// If there are any pending queries,
	// they just failed due to the disconnection.
	
	for (NSString *uuid in pendingQueries)
	{
		XMPPBlockingQueryInfo *queryInfo = [pendingQueries objectForKey:uuid];
		
		[self processQuery:queryInfo withFailureCode:XMPPBlockingDisconnect];
	}
	
	// Clear the list of pending queries
	
	[pendingQueries removeAllObjects];
	
	// Maybe clear all stored blocking info
	
	if (self.autoClearBlockingListInfo)
	{
		[self clearBlockingListInfo];
	}
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPBlockingQueryInfo

@synthesize type;
@synthesize blockingXMPPJID;
@synthesize blockingListItems;
@synthesize timer;

- (id)initWithType:(XMPPBlockingQueryInfoType)aType jid:(XMPPJID *)jid items:(NSArray *)items
{
	if ((self = [super init]))
	{
		type = aType;
		blockingXMPPJID = [jid copy];
		blockingListItems = [items copy];
	}
	return self;
}

- (void)cancel
{
	if (timer)
	{
		dispatch_source_cancel(timer);
#if !OS_OBJECT_USE_OBJC
		dispatch_release(timer);
#endif
		timer = NULL;
	}
}

- (void)dealloc
{
	[self cancel];
}

+ (XMPPBlockingQueryInfo *)queryInfoWithType:(XMPPBlockingQueryInfoType)type
{
	return [self queryInfoWithType:type jid:nil items:nil];
}

+ (XMPPBlockingQueryInfo *)queryInfoWithType:(XMPPBlockingQueryInfoType)type jid:(XMPPJID *)jid
{
	return [self queryInfoWithType:type jid:jid items:nil];
}

+ (XMPPBlockingQueryInfo *)queryInfoWithType:(XMPPBlockingQueryInfoType)type jid:(XMPPJID *)jid items:(NSArray *)items
{
	return [[XMPPBlockingQueryInfo alloc] initWithType:type jid:jid items:items];
}

@end
