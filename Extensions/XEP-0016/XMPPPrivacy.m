#import "XMPP.h"
#import "XMPPLogging.h"
#import "XMPPPrivacy.h"
#import "NSNumber+XMPP.h"

// Log levels: off, error, warn, info, verbose
// Log flags: trace
#ifdef DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_VERBOSE; // | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

#define QUERY_TIMEOUT 30.0 // NSTimeInterval (double) = seconds

NSString *const XMPPPrivacyErrorDomain = @"XMPPPrivacyErrorDomain";

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

typedef enum XMPPPrivacyQueryInfoType {
	FetchList,
	FetchRules,
	EditList,
	SetActiveList,
	SetDefaultList
	
} XMPPPrivacyQueryInfoType;

@interface XMPPPrivacyQueryInfo : NSObject
{
	XMPPPrivacyQueryInfoType type;
	NSString *privacyListName;
	NSArray *privacyListItems;
	
	dispatch_source_t timer;
}

@property (nonatomic, readonly) XMPPPrivacyQueryInfoType type;
@property (nonatomic, readonly) NSString *privacyListName;
@property (nonatomic, readonly) NSArray *privacyListItems;

@property (nonatomic, readwrite) dispatch_source_t timer;

- (void)cancel;

+ (XMPPPrivacyQueryInfo *)queryInfoWithType:(XMPPPrivacyQueryInfoType)type;
+ (XMPPPrivacyQueryInfo *)queryInfoWithType:(XMPPPrivacyQueryInfoType)type name:(NSString *)name;
+ (XMPPPrivacyQueryInfo *)queryInfoWithType:(XMPPPrivacyQueryInfoType)type name:(NSString *)name items:(NSArray *)items;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface XMPPPrivacy (/* Must be nameless for properties */)

- (void)addQueryInfo:(XMPPPrivacyQueryInfo *)qi withKey:(NSString *)uuid;
- (void)queryTimeout:(NSString *)uuid;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPPrivacy

- (id)init
{
	return [self initWithDispatchQueue:NULL];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	if ((self = [super initWithDispatchQueue:queue]))
	{
		autoRetrievePrivacyListNames = YES;
		autoRetrievePrivacyListItems = YES;
		autoClearPrivacyListInfo     = YES;
		
		privacyDict = [[NSMutableDictionary alloc] init];
		activeListName = nil;
		defaultListName = nil;
		
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

- (BOOL)autoRetrievePrivacyListNames
{
	if (dispatch_get_specific(moduleQueueTag))
	{
		return autoRetrievePrivacyListNames;
	}
	else
	{
		__block BOOL result;
		
		dispatch_sync(moduleQueue, ^{
			result = autoRetrievePrivacyListNames;
		});
		
		return result;
	}
}

- (void)setAutoRetrievePrivacyListNames:(BOOL)flag
{
	dispatch_block_t block = ^{
		
		autoRetrievePrivacyListNames = flag;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (BOOL)autoRetrievePrivacyListItems
{
	if (dispatch_get_specific(moduleQueueTag))
	{
		return autoRetrievePrivacyListItems;
	}
	else
	{
		__block BOOL result;
		
		dispatch_sync(moduleQueue, ^{
			result = autoRetrievePrivacyListItems;
		});
		
		return result;
	}
}

- (void)setAutoRetrievePrivacyListItems:(BOOL)flag
{
	dispatch_block_t block = ^{
		
		autoRetrievePrivacyListItems = flag;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (BOOL)autoClearPrivacyListInfo
{
	if (dispatch_get_specific(moduleQueueTag))
	{
		return autoClearPrivacyListInfo;
	}
	else
	{
		__block BOOL result;
		
		dispatch_sync(moduleQueue, ^{
			result = autoClearPrivacyListInfo;
		});
		
		return result;
	}
}

- (void)setAutoClearPrivacyListInfo:(BOOL)flag
{
	dispatch_block_t block = ^{
		
		autoClearPrivacyListInfo = flag;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Public API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)retrieveListNames
{
	XMPPLogTrace();
	
	// <iq type='get' id='abc123'>
	//   <query xmlns='jabber:iq:privacy'/>
	// </iq>
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:privacy"];
	
	NSString *uuid = [xmppStream generateUUID];
	XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:nil elementID:uuid child:query];
	
	[xmppStream sendElement:iq];
	
	XMPPPrivacyQueryInfo *qi = [XMPPPrivacyQueryInfo queryInfoWithType:FetchList];
	[self addQueryInfo:qi withKey:uuid];
}

- (void)retrieveListWithName:(NSString *)privacyListName
{
	XMPPLogTrace();
	
	if (privacyListName == nil) return;
	
	// <iq type='get' id='abc123'>
	//   <query xmlns='jabber:iq:privacy'>
	//     <list name='public'/>
	//   </query>
	// </iq>
	
	NSXMLElement *list = [NSXMLElement elementWithName:@"list"];
	[list addAttributeWithName:@"name" stringValue:privacyListName];
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:privacy"];
	[query addChild:list];
	
	NSString *uuid = [xmppStream generateUUID];
	XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:nil elementID:uuid child:query];
	
	[xmppStream sendElement:iq];
	
	XMPPPrivacyQueryInfo *qi = [XMPPPrivacyQueryInfo queryInfoWithType:FetchRules name:privacyListName];
	[self addQueryInfo:qi withKey:uuid];
}

- (void)clearPrivacyListInfo
{
	XMPPLogTrace();
	
	if (dispatch_get_specific(moduleQueueTag))
	{
		[privacyDict removeAllObjects];
	}
	else
	{
		dispatch_async(moduleQueue, ^{ @autoreleasepool {
			
			[privacyDict removeAllObjects];
		}});
	}
}

- (NSArray *)listNames
{
	if (dispatch_get_specific(moduleQueueTag))
	{
		return [privacyDict allKeys];
	}
	else
	{
		__block NSArray *result;
		
		dispatch_sync(moduleQueue, ^{ @autoreleasepool {
			
			result = [[privacyDict allKeys] copy];
		}});
		
		return result;
	}
}

- (NSArray *)listWithName:(NSString *)privacyListName
{
	NSArray* (^block)() = ^ NSArray* () {
		
		id result = [privacyDict objectForKey:privacyListName];
		
		if (result == [NSNull null]) // Not fetched yet
			return nil;
		else
			return (NSArray *)result;
	};
	
	// ExecuteVoidBlock(moduleQueue, block);
	// ExecuteNonVoidBlock(moduleQueue, block, NSArray*)
	
	if (dispatch_get_specific(moduleQueueTag))
	{
		return block();
	}
	else
	{
		__block NSArray *result;
		
		dispatch_sync(moduleQueue, ^{ @autoreleasepool {
			
			result = block();
		}});
		
		return result;
	}
}

- (NSString *)activeListName
{
	return activeListName;
}

- (NSArray *)activeList
{
	return [self listWithName:activeListName];
}

- (void)setActiveListName:(NSString *)privacyListName
{
	// Setting active list:
	// 
	// <iq type='set' id='active1'>
	//   <query xmlns='jabber:iq:privacy'>
	//     <active name='special'/>
	//   </query>
	// </iq>
	// 
	// Decline the use of active lists:
	// 
	// <iq type='set' id='active3'>
	//   <query xmlns='jabber:iq:privacy'>
	//     <active/>
	//   </query>
	// </iq>
	
	NSXMLElement *active = [NSXMLElement elementWithName:@"active"];
	if (privacyListName)
	{
		[active addAttributeWithName:@"name" stringValue:privacyListName];
	}
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:privacy"];
	[query addChild:active];
	
	NSString *uuid = [xmppStream generateUUID];
	XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:nil elementID:uuid child:query];
	
	[xmppStream sendElement:iq];
	
	XMPPPrivacyQueryInfo *qi = [XMPPPrivacyQueryInfo queryInfoWithType:SetActiveList name:privacyListName];
	[self addQueryInfo:qi withKey:uuid];
}

- (NSString *)defaultListName
{
	return defaultListName;
}

- (NSArray *)defaultList
{
	return [self listWithName:defaultListName];
}

- (void)setDefaultListName:(NSString *)privacyListName
{
	// Setting default list:
	// 
	// <iq type='set' id='default1'>
	//   <query xmlns='jabber:iq:privacy'>
	//     <default name='special'/>
	//   </query>
	// </iq>
	// 
	// Decline the use of default list:
	// 
	// <iq type='set' id='default2'>
	//   <query xmlns='jabber:iq:privacy'>
	//     <default/>
	//   </query>
	// </iq>
	
	NSXMLElement *dfault = [NSXMLElement elementWithName:@"default"];
	if (privacyListName)
	{
		[dfault addAttributeWithName:@"name" stringValue:privacyListName];
	}
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:privacy"];
	[query addChild:dfault];
	
	NSString *uuid = [xmppStream generateUUID];
	XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:nil elementID:uuid child:query];
	
	[xmppStream sendElement:iq];
	
	XMPPPrivacyQueryInfo *qi = [XMPPPrivacyQueryInfo queryInfoWithType:SetDefaultList name:privacyListName];
	[self addQueryInfo:qi withKey:uuid];
}

- (void)setListWithName:(NSString *)privacyListName items:(NSArray *)items
{
	// Edit a privacy list:
	// 
	// <iq type='set' id='edit1'>
	//   <query xmlns='jabber:iq:privacy'>
	//     <list name='public'>
	//       <item type='jid' value='tybalt@example.com' action='deny' order='3'/>
	//       <item type='jid' value='paris@example.org' action='deny' order='5'/>
	//       <item action='allow' order='68'/>
	//     </list>
	//   </query>
	// </iq>
	// 
	// 
	// Remove a privacy list:
	// 
	// <iq type='set' id='remove1'>
	//   <query xmlns='jabber:iq:privacy'>
	//     <list name='private'/>
	//   </query>
	// </iq>
	
	NSXMLElement *list = [NSXMLElement elementWithName:@"list"];
	[list addAttributeWithName:@"name" stringValue:privacyListName];
	
	if (items && ([items count] > 0))
	{
		[list setChildren:items];
	}
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:privacy"];
	[query addChild:list];
	
	NSString *uuid = [xmppStream generateUUID];
	XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:nil elementID:uuid child:query];
	
	[xmppStream sendElement:iq];
	
	XMPPPrivacyQueryInfo *qi = [XMPPPrivacyQueryInfo queryInfoWithType:EditList name:privacyListName items:items];
	[self addQueryInfo:qi withKey:uuid];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Query Processing
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)addQueryInfo:(XMPPPrivacyQueryInfo *)queryInfo withKey:(NSString *)uuid
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

- (void)removeQueryInfo:(XMPPPrivacyQueryInfo *)queryInfo withKey:(NSString *)uuid
{
	// Invalidate timer
	[queryInfo cancel];
	
	// Remove from dictionary
	[pendingQueries removeObjectForKey:uuid];
}

- (void)processQuery:(XMPPPrivacyQueryInfo *)queryInfo withFailureCode:(XMPPPrivacyErrorCode)errorCode
{
	NSError *error = [NSError errorWithDomain:XMPPPrivacyErrorDomain code:errorCode userInfo:nil];
	
	if (queryInfo.type == FetchList)
	{
		[multicastDelegate xmppPrivacy:self didNotReceiveListNamesDueToError:error];
	}
	else if (queryInfo.type == FetchRules)
	{
		[multicastDelegate xmppPrivacy:self didNotReceiveListWithName:queryInfo.privacyListName error:error];
	}
	else if (queryInfo.type == EditList)
	{
		[multicastDelegate xmppPrivacy:self didNotSetListWithName:queryInfo.privacyListName error:error];
	}
	else if (queryInfo.type == SetActiveList)
	{
		[multicastDelegate xmppPrivacy:self didNotSetActiveListName:queryInfo.privacyListName error:error];
	}
	else if (queryInfo.type == SetDefaultList)
	{
		[multicastDelegate xmppPrivacy:self didNotSetDefaultListName:queryInfo.privacyListName error:error];
	}
}

- (void)queryTimeout:(NSString *)uuid
{
	XMPPPrivacyQueryInfo *queryInfo = [privacyDict objectForKey:uuid];
	if (queryInfo)
	{
		[self processQuery:queryInfo withFailureCode:XMPPPrivacyQueryTimeout];
		[self removeQueryInfo:queryInfo withKey:uuid];
	}
}

NSInteger sortItems(id itemOne, id itemTwo, void *context)
{
	NSXMLElement *item1 = (NSXMLElement *)itemOne;
	NSXMLElement *item2 = (NSXMLElement *)itemTwo;
	
	NSString *orderStr1 = [item1 attributeStringValueForName:@"order"];
	NSString *orderStr2 = [item2 attributeStringValueForName:@"order"];
	
	NSUInteger order1;
	BOOL parse1 = [NSNumber parseString:orderStr1 intoNSUInteger:&order1];
	
	NSUInteger order2;
	BOOL parse2 = [NSNumber parseString:orderStr2 intoNSUInteger:&order2];
	
	if (parse1)
	{
		if (parse2)
		{
			// item1 = valid
			// item2 = valid
			
			if (order1 < order2)
				return NSOrderedAscending;
			if (order1 > order2)
				return NSOrderedDescending;
			
			return NSOrderedSame;
		}
		else
		{
			// item1 = valid
			// item2 = invalid
			
			return NSOrderedAscending;
		}
	}
	else if (parse2)
	{
		// item1 = invalid
		// item2 = valid
		
		return NSOrderedDescending;
	}
	else
	{
		// item1 = invalid
		// item2 = invalid
		
		return NSOrderedSame;
	}
}

- (void)processQueryResponse:(XMPPIQ *)iq withInfo:(XMPPPrivacyQueryInfo *)queryInfo
{
	if (queryInfo.type == FetchList)
	{
		// Privacy List Names Query Response:
		// 
		// <iq type='result' id='getlist1'>
		//   <query xmlns='jabber:iq:privacy'>
		//     <active name='private'/>
		//     <default name='public'/>
		//     <list name='public'/>
		//     <list name='private'/>
		//     <list name='special'/>
		//   </query>
		// </iq>
		
		if ([[iq type] isEqualToString:@"result"])
		{
			NSXMLElement *query = [iq elementForName:@"query" xmlns:@"jabber:iq:privacy"];
			if (query == nil) return;
			
			NSXMLElement *active = [query elementForName:@"active"];
			activeListName = [[active attributeStringValueForName:@"name"] copy];
			
			NSXMLElement *dfault = [query elementForName:@"default"];
			defaultListName = [[dfault attributeStringValueForName:@"name"] copy];
			
			NSArray *listNames = [query elementsForName:@"list"];
			for (NSXMLElement *listName in listNames)
			{
				NSString *name = [listName attributeStringValueForName:@"name"];
				if (name)
				{
					id value = [privacyDict objectForKey:name];
					if (value == nil)
					{
						[privacyDict setObject:[NSNull null] forKey:name];
					}
				}
			}
			
			[multicastDelegate xmppPrivacy:self didReceiveListNames:[self listNames]];
		}
		else
		{
			[multicastDelegate xmppPrivacy:self didNotReceiveListNamesDueToError:iq];
		}
	}
	else if (queryInfo.type == FetchRules)
	{
		// Privacy List Rules Query Response (success):
		// 
		// <iq type='result' id='getlist2'>
		//   <query xmlns='jabber:iq:privacy'>
		//     <list name='public'>
		//       <item type='jid' value='tybalt@example.com' action='deny' order='1'/>
		//       <item action='allow' order='2'/>
		//     </list>
		//   </query>
		// </iq>
		// 
		// 
		// Privacy List Rules Query Response (error):
		// 
		// <iq type='error' id='getlist5'>
		//   <query xmlns='jabber:iq:privacy'>
		//     <list name='The Empty Set'/>
		//   </query>
		//   <error type='cancel'>
		//     <item-not-found xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
		//   </error>
		// </iq>
		
		if ([[iq type] isEqualToString:@"result"])
		{
			NSXMLElement *query = [iq elementForName:@"query" xmlns:@"jabber:iq:privacy"];
			if (query == nil) return;
			
			NSXMLElement *list = [query elementForName:@"list"];
			if (list == nil) return;
			
			NSArray *items = [[list elementsForName:@"item"] sortedArrayUsingFunction:sortItems context:NULL];
			
			if (items == nil)
			{
				items = [NSArray array];
			}
			
			[privacyDict setObject:items forKey:queryInfo.privacyListName];
			
			[multicastDelegate xmppPrivacy:self didReceiveListWithName:queryInfo.privacyListName items:items];
		}
		else
		{
			[multicastDelegate xmppPrivacy:self didNotReceiveListWithName:queryInfo.privacyListName error:iq];
		}
	}
	else if (queryInfo.type == EditList)
	{
		// Privacy List Add/Edit/Remove Response (success):
		// 
		// <iq type='result' id='abc123' to='romeo@example.net/orchard'/>
		// 
		// Note: The result iq does NOT have a query child.
		
		if ([[iq type] isEqualToString:@"result"])
		{
			NSArray *items = [[queryInfo privacyListItems] sortedArrayUsingFunction:sortItems context:NULL];
			
			if (items == nil)
			{
				items = [NSArray array];
			}
			
			[privacyDict setObject:items forKey:queryInfo.privacyListName];
			
			[multicastDelegate xmppPrivacy:self didSetListWithName:queryInfo.privacyListName];
		}
		else
		{
			[multicastDelegate xmppPrivacy:self didNotSetListWithName:queryInfo.privacyListName error:iq];
		}
	}
	else if (queryInfo.type == SetActiveList)
	{
		// Change of active list (success):
		// 
		// <iq type='result' id='active1' to='romeo@example.net/orchard'/>
		// 
		// 
		// Change of active list (error):
		// 
		// <iq to='romeo@example.net/orchard' type='error' id='active2'>
		//   <query xmlns='jabber:iq:privacy'>
		//     <active name='Invalid List Name'/>
		//   </query>
		//   <error type='cancel'>
		//     <item-not-found xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
		//   </error>
		// </iq>
		// 
		// 
		// Note: The result iq does NOT have a query child.
		// Note: The success could also mean we declined the use of an active list.
		
		if ([[iq type] isEqualToString:@"result"])
		{
			activeListName = [[queryInfo privacyListName] copy];
			
			[multicastDelegate xmppPrivacy:self didSetActiveListName:queryInfo.privacyListName];
		}
		else
		{
			[multicastDelegate xmppPrivacy:self didNotSetActiveListName:queryInfo.privacyListName error:iq];
		}
	}
	else if (queryInfo.type == SetDefaultList)
	{
		// Change of default list (success):
		// 
		// <iq type='result' id='default1' to='romeo@example.net/orchard'/>
		// 
		// 
		// Change of default list (error):
		// 
		// <iq to='romeo@example.net/orchard' type='error' id='default1'>
		//   <query xmlns='jabber:iq:privacy'>
		//     <default name='special'/>
		//   </query>
		//   <error type='cancel'>
		//     <conflict xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
		//   </error>
		// </iq>
		// 
		// 
		// Note: The result iq does NOT have a query child.
		// Note: The success could also mean we declined the use of a default list.
		
		if ([[iq type] isEqualToString:@"result"])
		{
			defaultListName = [[queryInfo privacyListName] copy];
			
			[multicastDelegate xmppPrivacy:self didSetDefaultListName:queryInfo.privacyListName];
		}
		else
		{
			[multicastDelegate xmppPrivacy:self didNotSetDefaultListName:queryInfo.privacyListName error:iq];
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	if (self.autoRetrievePrivacyListNames)
	{
		[self retrieveListNames];
	}
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	NSString *type = [iq type];
	
	if ([type isEqualToString:@"set"])
	{
		NSXMLElement *query = [iq elementForName:@"query" xmlns:@"jabber:iq:privacy"];
		if (query)
		{
			// Privacy List Push:
			// 
			// <iq type='set' id='push1'>
			//   <query xmlns='jabber:iq:privacy'>
			//     <list name='public'/>
			//   </query>
			// </iq>
			// 
			// 
			// Push response:
			// 
			// <iq type='result' id='push1'/>
			
			NSXMLElement *list = [query elementForName:@"list"];
			
			NSString *listName = [list attributeStringValueForName:@"name"];
			if (listName == nil)
			{
				return NO;
			}
			
			[multicastDelegate xmppPrivacy:self didReceivePushWithListName:listName];
			
			XMPPIQ *iqResponse = [XMPPIQ iqWithType:@"result" to:[iq from] elementID:[iq elementID]];
			[xmppStream sendElement:iqResponse];
			
			if (self.autoRetrievePrivacyListItems)
			{
				[self retrieveListWithName:listName];
			}
			
			return YES;
		}
	}
	else
	{
		// This may be a response to a query we sent
		
		XMPPPrivacyQueryInfo *queryInfo = [pendingQueries objectForKey:[iq elementID]];
		if (queryInfo)
		{
			[self processQueryResponse:iq withInfo:queryInfo];
			
			if (queryInfo.type == FetchList && self.autoRetrievePrivacyListItems)
			{
				for (NSString *privacyListName in privacyDict)
				{
					id privacyListItems = [privacyDict objectForKey:privacyListName];
					
					if (privacyListItems == [NSNull null])
					{
						[self retrieveListWithName:privacyListName];
					}
				}
			}
			
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
		XMPPPrivacyQueryInfo *queryInfo = [privacyDict objectForKey:uuid];
		
		[self processQuery:queryInfo withFailureCode:XMPPPrivacyDisconnect];
	}
	
	// Clear the list of pending queries
	
	[pendingQueries removeAllObjects];
	
	// Maybe clear all stored privacy info
	
	if (self.autoClearPrivacyListInfo)
	{
		[self clearPrivacyListInfo];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Privacy Items
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSXMLElement *)privacyItemWithAction:(NSString *)action order:(NSUInteger)orderValue
{
	return [self privacyItemWithType:nil value:nil action:action order:orderValue];
}

+ (NSXMLElement *)privacyItemWithType:(NSString *)type
                                value:(NSString *)value
                               action:(NSString *)action
                                order:(NSUInteger)orderValue
{
	NSString *order = [[NSString alloc] initWithFormat:@"%lu", (unsigned long)orderValue];
	
	// <item type='[jid|group|subscription]'
	//      value='bar'
	//     action='[allow|deny]'
	//      order='unsignedInt'>
	//   [<iq/>]
	//   [<message/>]
	//   [<presence-in/>]
	//   [<presence-out/>]
	// </item>
	
	NSXMLElement *item = [NSXMLElement elementWithName:@"item"];
	
	if (type)
		[item addAttributeWithName:@"type"  stringValue:type];
	
	if (value)
		[item addAttributeWithName:@"value" stringValue:value];
	
	[item addAttributeWithName:@"action" stringValue:action];
	[item addAttributeWithName:@"order"  stringValue:order];
	
	return item;
}

+ (void)blockIQs:(NSXMLElement *)privacyItem
{
	[privacyItem addChild:[NSXMLElement elementWithName:@"iq"]];
}

+ (void)blockMessages:(NSXMLElement *)privacyItem
{
	[privacyItem addChild:[NSXMLElement elementWithName:@"message"]];
}

+ (void)blockPresenceIn:(NSXMLElement *)privacyItem
{
	[privacyItem addChild:[NSXMLElement elementWithName:@"presence-in"]];
}

+ (void)blockPresenceOut:(NSXMLElement *)privacyItem
{
	[privacyItem addChild:[NSXMLElement elementWithName:@"presence-out"]];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPPrivacyQueryInfo

@synthesize type;
@synthesize privacyListName;
@synthesize privacyListItems;
@synthesize timer;


- (id)initWithType:(XMPPPrivacyQueryInfoType)aType name:(NSString *)name items:(NSArray *)items
{
	if ((self = [super init]))
	{
		type = aType;
		privacyListName = [name copy];
		privacyListItems = [items copy];
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

+ (XMPPPrivacyQueryInfo *)queryInfoWithType:(XMPPPrivacyQueryInfoType)type
{
	return [self queryInfoWithType:type name:nil items:nil];
}

+ (XMPPPrivacyQueryInfo *)queryInfoWithType:(XMPPPrivacyQueryInfoType)type name:(NSString *)name
{
	return [self queryInfoWithType:type name:name items:nil];
}

+ (XMPPPrivacyQueryInfo *)queryInfoWithType:(XMPPPrivacyQueryInfoType)type name:(NSString *)name items:(NSArray *)items
{
	return [[XMPPPrivacyQueryInfo alloc] initWithType:type name:name items:items];
}

@end
