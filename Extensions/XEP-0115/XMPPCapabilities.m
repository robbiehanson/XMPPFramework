#import "XMPP.h"
#import "XMPPLogging.h"
#import "XMPPCapabilities.h"
#import "NSData+XMPP.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
// Log flags: trace
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

/**
 * Defines the timeout for a capabilities request.
 * 
 * There are two reasons to have a timeout:
 * - To prevent the discoRequest variables from growing indefinitely if responses are not received.
 * - If a request is sent to a jid broadcasting a capabilities hash, and it does not respond within the timeout,
 *   we can then send a request to a different jid broadcasting the same capabilities hash.
 * 
 * Remember, if multiple jids all broadcast the same capabilities hash,
 * we only (initially) send a disco request to the first jid.
 * This is an obvious optimization to remove unnecessary traffic and cpu load.
 * 
 * However, if that jid doesn't respond within a sensible time period,
 * we should move on to the next jid in the list.
**/
#define CAPABILITIES_REQUEST_TIMEOUT 30.0 // seconds

/**
 * Define various xmlns values.
**/
#define XMLNS_DISCO_INFO  @"http://jabber.org/protocol/disco#info"
#define XMLNS_CAPS        @"http://jabber.org/protocol/caps"

/**
 * Application identifier.
 * According to the XEP it is RECOMMENDED for the value of the 'node' attribute to be an HTTP URL.
**/
#ifndef DISCO_NODE
	#define DISCO_NODE @"https://github.com/robbiehanson/XMPPFramework"
#endif

@interface GCDTimerWrapper : NSObject
{
	dispatch_source_t timer;
}

- (id)initWithDispatchTimer:(dispatch_source_t)aTimer;
- (void)cancel;

@end

@interface XMPPCapabilities (PrivateAPI)

- (void)continueCollectMyCapabilities:(NSXMLElement *)query;

- (void)maybeQueryNextJidWithHashKey:(NSString *)key dueToHashMismatch:(BOOL)hashMismatch;

- (void)setupTimeoutForDiscoRequestFromJID:(XMPPJID *)jid;
- (void)setupTimeoutForDiscoRequestFromJID:(XMPPJID *)jid withHashKey:(NSString *)key;

- (void)cancelTimeoutForDiscoRequestFromJID:(XMPPJID *)jid;

- (void)processTimeoutWithHashKey:(NSString *)key;
- (void)processTimeoutWithJID:(XMPPJID *)jid;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPCapabilities

@dynamic xmppCapabilitiesStorage;
@dynamic autoFetchHashedCapabilities;
@dynamic autoFetchNonHashedCapabilities;
@dynamic autoFetchMyServerCapabilities;

- (id)init
{
	// This will cause a crash - it's designed to.
	// Only the init methods listed in XMPPCapabilities.h are supported.
	
	return [self initWithCapabilitiesStorage:nil dispatchQueue:NULL];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	// This will cause a crash - it's designed to.
	// Only the init methods listed in XMPPCapabilities.h are supported.
	
	return [self initWithCapabilitiesStorage:nil dispatchQueue:queue];
}

- (id)initWithCapabilitiesStorage:(id <XMPPCapabilitiesStorage>)storage
{
	return [self initWithCapabilitiesStorage:storage dispatchQueue:NULL];
}

- (id)initWithCapabilitiesStorage:(id <XMPPCapabilitiesStorage>)storage dispatchQueue:(dispatch_queue_t)queue
{
	NSParameterAssert(storage != nil);
	
	if ((self = [super initWithDispatchQueue:queue]))
	{
		if ([storage configureWithParent:self queue:moduleQueue])
		{
			xmppCapabilitiesStorage = storage;
		}
		else
		{
			XMPPLogError(@"%@: %@ - Unable to configure storage!", THIS_FILE, THIS_METHOD);
		}
        
        myCapabilitiesNode = DISCO_NODE;
		
		// discoRequestJidSet:
		// 
		// A set which contains every JID for which a current disco request applies.
		// Note that one disco request may satisfy multiple jids in this set.
		// This is the case if multiple jids broadcast the same capabilities hash.
		// When this happens we send a single disco request to one of the jids,
		// but every single jid with that hash is included in this set.
		// This allows us to quickly and easily see if there is an outstanding disco request for a jid.
		// 
		// discoRequestHashDict:
		// 
		// A dictionary which tells us about disco requests that have been sent concerning hashed capabilities.
		// It maps from hash (key=hash+hashAlgorithm) to an array of jids that use this hash.
		// 
		// discoTimerJidDict:
		// 
		// A dictionary that contains all the timers for timing out disco requests.
		// It maps from jid to associated timer.
		
		discoRequestJidSet = [[NSMutableSet alloc] init];
		discoRequestHashDict = [[NSMutableDictionary alloc] init];
		discoTimerJidDict = [[NSMutableDictionary alloc] init];
		
		autoFetchHashedCapabilities = YES;
		autoFetchNonHashedCapabilities = NO;
		autoFetchMyServerCapabilities = NO;
	}
	return self;
}

- (void)dealloc
{
    [discoTimerJidDict enumerateKeysAndObjectsUsingBlock:^(XMPPJID * _Nonnull key, GCDTimerWrapper * _Nonnull obj, BOOL * _Nonnull stop) {
        [obj cancel];
    }];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Configuration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id <XMPPCapabilitiesStorage>)xmppCapabilitiesStorage
{
	return xmppCapabilitiesStorage;
}

- (NSString *)myCapabilitiesNode
{
	if (dispatch_get_specific(moduleQueueTag))
	{
		return myCapabilitiesNode;
	}
	else
	{
		__block NSString *result;
		
		dispatch_sync(moduleQueue, ^{
			result = myCapabilitiesNode;
		});
		
		return result;
	}
}

- (void)setMyCapabilitiesNode:(NSString *)flag
{
    NSAssert([flag length], @"myCapabilitiesNode MUST NOT be nil");

	dispatch_block_t block = ^{
		myCapabilitiesNode = flag;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (BOOL)autoFetchHashedCapabilities
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		result = autoFetchHashedCapabilities;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

- (void)setAutoFetchHashedCapabilities:(BOOL)flag
{
	dispatch_block_t block = ^{
		autoFetchHashedCapabilities = flag;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (BOOL)autoFetchNonHashedCapabilities
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		result = autoFetchNonHashedCapabilities;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

- (void)setAutoFetchNonHashedCapabilities:(BOOL)flag
{
	dispatch_block_t block = ^{
		autoFetchNonHashedCapabilities = flag;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (BOOL)autoFetchMyServerCapabilities
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		result = autoFetchMyServerCapabilities;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

- (void)setAutoFetchMyServerCapabilities:(BOOL)flag
{
	dispatch_block_t block = ^{
		autoFetchMyServerCapabilities = flag;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Hashing
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

static NSString* encodeLt(NSString *str)
{
	// From the RFC:
	// 
	// If the string "&lt;" appears in any of the hash values,
	// then that value MUST NOT convert it to "<" because
	// completing such a conversion would open the protocol to trivial attacks.
	// 
	// All of the XML libraries perform this conversion for us automatically (which makes sense).
	// Furthermore, it is illegal for an attribute or namespace value to have a raw "<" character (as per XML).
	// So the solution is very simple:
	// Just convert any '<' characters to the escaped "&lt;" string.
	
	return [str stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
}

static NSInteger sortIdentities(NSXMLElement *identity1, NSXMLElement *identity2, void *context)
{
	// Sort the service discovery identities by category and then by type and then by xml:lang (if it exists).
	// 
	// All sort operations MUST be performed using "i;octet" collation as specified in Section 9.3 of RFC 4790.
	
	NSComparisonResult result;
	
	NSString *category1 = [identity1 attributeStringValueForName:@"category" withDefaultValue:@""];
	NSString *category2 = [identity2 attributeStringValueForName:@"category" withDefaultValue:@""];
	
	category1 = encodeLt(category1);
	category2 = encodeLt(category2);
	
	result = [category1 compare:category2 options:NSLiteralSearch];
	if (result != NSOrderedSame)
	{
		return result;
	}
	
	NSString *type1 = [identity1 attributeStringValueForName:@"type" withDefaultValue:@""];
	NSString *type2 = [identity2 attributeStringValueForName:@"type" withDefaultValue:@""];
	
	type1 = encodeLt(type1);
	type2 = encodeLt(type2);
	
	result = [type1 compare:type2 options:NSLiteralSearch];
	if (result != NSOrderedSame)
	{
		return result;
	}
	
	NSString *lang1 = [identity1 attributeStringValueForName:@"xml:lang" withDefaultValue:@""];
	NSString *lang2 = [identity2 attributeStringValueForName:@"xml:lang" withDefaultValue:@""];
	
	lang1 = encodeLt(lang1);
	lang2 = encodeLt(lang2);
	
	result = [lang1 compare:lang2 options:NSLiteralSearch];
	if (result != NSOrderedSame)
	{
		return result;
	}
	
	NSString *name1 = [identity1 attributeStringValueForName:@"name" withDefaultValue:@""];
	NSString *name2 = [identity2 attributeStringValueForName:@"name" withDefaultValue:@""];
	
	name1 = encodeLt(name1);
	name2 = encodeLt(name2);
	
	return [name1 compare:name2 options:NSLiteralSearch];
}

static NSInteger sortFeatures(NSXMLElement *feature1, NSXMLElement *feature2, void *context)
{
	// All sort operations MUST be performed using "i;octet" collation as specified in Section 9.3 of RFC 4790.
	
	NSString *var1 = [feature1 attributeStringValueForName:@"var" withDefaultValue:@""];
	NSString *var2 = [feature2 attributeStringValueForName:@"var" withDefaultValue:@""];
	
	var1 = encodeLt(var1);
	var2 = encodeLt(var2);
	
	return [var1 compare:var2 options:NSLiteralSearch];
}

static NSString* extractFormTypeValue(NSXMLElement *form)
{
	// From the RFC:
	// 
	// If the FORM_TYPE field is not of type "hidden" or the form does not
	// include a FORM_TYPE field, ignore the form but continue processing.
	// 
	// If the FORM_TYPE field contains more than one <value/> element with different XML character data,
	// consider the entire response to be ill-formed.
	
	// This method will return:
	// 
	// - The form type's value if it exists
	// - An empty string if it does not contain a form type field (or the form type is not of type hidden)
	// - Nil if the form type is invalid (contains more than one <value/> element which are different)
	// 
	// In other words
	// 
	// - Non-empty string -> proper form
	// - Empty string -> ignore form
	// - Nil -> Entire response is to be considered ill-formed
	// 
	// The returned value is properly encoded via encodeLt() and contains the trailing '<' character.
	
	NSArray *fields = [form elementsForName:@"field"];
	for (NSXMLElement *field in fields)
	{
		NSString *var = [field attributeStringValueForName:@"var"];
		NSString *type = [field attributeStringValueForName:@"type"];
		
		if ([var isEqualToString:@"FORM_TYPE"] && [type isEqualToString:@"hidden"])
		{
			NSArray *values = [field elementsForName:@"value"];
			
			if ([values count] > 0)
			{
				if ([values count] > 1)
				{
					NSString *baseValue = [values[0] stringValue];
					
					NSUInteger i;
					for (i = 1; i < [values count]; i++)
					{
						NSString *value = [values[i] stringValue];
						
						if (![value isEqualToString:baseValue])
						{
							// Multiple <value/> elements with differing XML character data
							return nil;
						}
					}
				}
				
				NSString *result = [[values lastObject] stringValue];
				if (result == nil)
				{
					// This is why the result contains the trailing '<' character.
					result = @"";
				}
				
				return [NSString stringWithFormat:@"%@<", encodeLt(result)];
			}
		}
	}
	
	return @"";
}

static NSInteger sortForms(NSXMLElement *form1, NSXMLElement *form2, void *context)
{
	// Sort the forms by the FORM_TYPE (i.e., by the XML character data of the <value/> element.
	// 
	// All sort operations MUST be performed using "i;octet" collation as specified in Section 9.3 of RFC 4790.
	
	NSString *formTypeValue1 = extractFormTypeValue(form1);
	NSString *formTypeValue2 = extractFormTypeValue(form2);
	
	// The formTypeValue variable is guaranteed to be properly encoded.
	
	if (formTypeValue1)
	{
		if (formTypeValue2)
			return [formTypeValue1 compare:formTypeValue2 options:NSLiteralSearch];
		else
			return NSOrderedAscending;
	}
	else if (formTypeValue2)
	{
		return NSOrderedDescending;
	}
	else
	{
		return NSOrderedSame;
	}
}

static NSInteger sortFormFields(NSXMLElement *field1, NSXMLElement *field2, void *context)
{
	// Sort the fields by the "var" attribute.
	// 
	// All sort operations MUST be performed using "i;octet" collation as specified in Section 9.3 of RFC 4790.
	
	NSString *var1 = [field1 attributeStringValueForName:@"var" withDefaultValue:@""];
	NSString *var2 = [field2 attributeStringValueForName:@"var" withDefaultValue:@""];
	
	var1 = encodeLt(var1);
	var2 = encodeLt(var2);
	
	return [var1 compare:var2 options:NSLiteralSearch];
}

static NSInteger sortFieldValues(NSXMLElement *value1, NSXMLElement *value2, void *context)
{
	NSString *str1 = [value1 stringValue];
	NSString *str2 = [value2 stringValue];
	
	if (str1 == nil) str1 = @"";
	if (str2 == nil) str2 = @"";
	
	str1 = encodeLt(str1);
	str2 = encodeLt(str2);
	
	return [str1 compare:str2 options:NSLiteralSearch];
}

+ (NSString *)hashCapabilitiesFromQuery:(NSXMLElement *)query
{
	if (query == nil) return nil;
	
	NSMutableSet *set = [NSMutableSet set];
	
	NSMutableString *s = [NSMutableString string];
	
	NSArray *identities = [[query elementsForName:@"identity"] sortedArrayUsingFunction:sortIdentities context:NULL];
	for (NSXMLElement *identity in identities)
	{
		// Format as: category / type / lang / name
		
		NSString *category = [identity attributeStringValueForName:@"category" withDefaultValue:@""];
		NSString *type     = [identity attributeStringValueForName:@"type"     withDefaultValue:@""];
		NSString *lang     = [identity attributeStringValueForName:@"xml:lang" withDefaultValue:@""];
		NSString *name     = [identity attributeStringValueForName:@"name"     withDefaultValue:@""];
		
		category = encodeLt(category);
		type     = encodeLt(type);
		lang     = encodeLt(lang);
		name     = encodeLt(name);
		
		NSString *mash = [NSString stringWithFormat:@"%@/%@/%@/%@<", category, type, lang, name];
		
		// Section 5.4, rule 3.3:
		// 
		// If the response includes more than one service discovery identity with
		// the same category/type/lang/name, consider the entire response to be ill-formed.
		
		if ([set containsObject:mash])
		{
			return nil;
		}
		else
		{
			[set addObject:mash];
		}
		
		[s appendString:mash];
	}
	
	[set removeAllObjects];
	
	
	NSArray *features = [[query elementsForName:@"feature"] sortedArrayUsingFunction:sortFeatures context:NULL];
	for (NSXMLElement *feature in features)
	{
		NSString *var = [feature attributeStringValueForName:@"var" withDefaultValue:@""];
		
		var = encodeLt(var);
		
		NSString *mash = [NSString stringWithFormat:@"%@<", var];
		
		// Section 5.4, rule 3.4:
		// 
		// If the response includes more than one service discovery feature with the
		// same XML character data, consider the entire response to be ill-formed.
		
		if ([set containsObject:mash])
		{
			return nil;
		}
		else
		{
			[set addObject:mash];
		}
		
		[s appendString:mash];
	}
	
	[set removeAllObjects];
	
	NSArray *unsortedForms = [query elementsForLocalName:@"x" URI:@"jabber:x:data"];
	NSArray *forms = [unsortedForms sortedArrayUsingFunction:sortForms context:NULL];
	for (NSXMLElement *form in forms)
	{
		NSString *formTypeValue = extractFormTypeValue(form);
		
		if (formTypeValue == nil)
		{
			// Invalid according to section 5.4, rule 3.5
			return nil;
		}
		if ([formTypeValue length] == 0)
		{
			// Ignore according to section 5.4, rule 3.6
			continue;
		}
		
		// Note: The formTypeValue is properly encoded and contains the trailing '<' character.
		
		[s appendString:formTypeValue];
		
		NSArray *fields = [[form elementsForName:@"field"] sortedArrayUsingFunction:sortFormFields context:NULL];
		for (NSXMLElement *field in fields)
		{
			// For each field other than FORM_TYPE:
			// 
			// 1. Append the value of the var attribute, followed by the '<' character.
			// 2. Sort values by the XML character data of the <value/> element.
			// 3. For each <value/> element, append the XML character data, followed by the '<' character.
			
			NSString *var = [field attributeStringValueForName:@"var" withDefaultValue:@""];
			
			var = encodeLt(var);
			
			if ([var isEqualToString:@"FORM_TYPE"])
			{
				continue;
			}
			
			[s appendFormat:@"%@<", var];
			
			NSArray *values = [[field elementsForName:@"value"] sortedArrayUsingFunction:sortFieldValues context:NULL];
			for (NSXMLElement *value in values)
			{
				NSString *str = [value stringValue];
				if (str == nil)
				{
					str = @"";
				}
				
				str = encodeLt(str);
				
				[s appendFormat:@"%@<", str];
			}
		}
	}
	
	NSData *data = [s dataUsingEncoding:NSUTF8StringEncoding];
	NSData *hash = [data xmpp_sha1Digest];
	
	return [hash xmpp_base64Encoded];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Key Conversions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)keyFromHash:(NSString *)hash algorithm:(NSString *)hashAlg
{
	return [NSString stringWithFormat:@"%@-%@", hash, hashAlg];
}

- (BOOL)getHash:(NSString **)hashPtr algorithm:(NSString **)hashAlgPtr fromKey:(NSString *)key
{
	if (key == nil) return NO;
	
	NSRange range = [key rangeOfString:@"-"];
	
	if (range.location == NSNotFound)
	{
		return NO;
	}
	
	if (hashPtr)
	{
		*hashPtr = [key substringToIndex:range.location];
	}
	if (hashAlgPtr)
	{
		*hashAlgPtr = [key substringFromIndex:(range.location + range.length)];
	}
	
	return YES;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Logic
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)collectMyCapabilities
{
	// This method must be invoked on the moduleQueue
	NSAssert(dispatch_get_specific(moduleQueueTag), @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	if (collectingMyCapabilities)
	{
		XMPPLogInfo(@"%@: %@ - Existing collection already in progress", [self class], THIS_METHOD);
		return;
	}
	
	 myCapabilitiesQuery = nil;
	 myCapabilitiesC = nil;
	
	collectingMyCapabilities = YES;
	
	// Create new query and add standard features
	// 
	// <query xmlns="http://jabber.org/protocol/disco#info">
	//   <feature var='http://jabber.org/protocol/disco#info'/>
	//   <feature var="http://jabber.org/protocol/caps"/>
	// </query>
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:XMLNS_DISCO_INFO];
	
	NSXMLElement *feature1 = [NSXMLElement elementWithName:@"feature"];
	[feature1 addAttributeWithName:@"var" stringValue:XMLNS_DISCO_INFO];
	
	NSXMLElement *feature2 = [NSXMLElement elementWithName:@"feature"];
	[feature2 addAttributeWithName:@"var" stringValue:XMLNS_CAPS];
	
	[query addChild:feature1];
	[query addChild:feature2];
	
	// Now prompt the delegates to add any additional features.
	
	SEL collectingMyCapabilitiesSelector = @selector(xmppCapabilities:collectingMyCapabilities:);
	SEL myFeaturesForXMPPCapabilitiesSelector = @selector(myFeaturesForXMPPCapabilities:);
		
	if (![multicastDelegate hasDelegateThatRespondsToSelector:collectingMyCapabilitiesSelector]
		&& ![multicastDelegate hasDelegateThatRespondsToSelector:myFeaturesForXMPPCapabilitiesSelector])
	{
		// None of the delegates implement the method.
		// Use a shortcut.
		
		[self continueCollectMyCapabilities:query];
	}
	else
	{
		// Query all interested delegates.
		// This must be done serially to allow them to alter the element in a thread-safe manner.
		
		GCDMulticastDelegateEnumerator *collectingMyCapabilitiesDelegateEnumerator = [multicastDelegate delegateEnumerator];
		GCDMulticastDelegateEnumerator *myFeaturesForXMPPCapabilitiesDelegateEnumerator = [multicastDelegate delegateEnumerator];

		
		dispatch_queue_t concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
		dispatch_async(concurrentQueue, ^{ @autoreleasepool {
			
						
			id del;
			dispatch_queue_t dq;
			
			while ([collectingMyCapabilitiesDelegateEnumerator getNextDelegate:&del delegateQueue:&dq forSelector:collectingMyCapabilitiesSelector])
			{
				dispatch_sync(dq, ^{ @autoreleasepool {
					
					[del xmppCapabilities:self collectingMyCapabilities:query];
				}});
			}
						
			while ([myFeaturesForXMPPCapabilitiesDelegateEnumerator getNextDelegate:&del delegateQueue:&dq forSelector:myFeaturesForXMPPCapabilitiesSelector])
			{
				dispatch_sync(dq, ^{ @autoreleasepool {
					
					NSArray *features =  [del myFeaturesForXMPPCapabilities:self];
					
					for(NSString *feature in features){
					
						BOOL found = NO;
						
						//Check to see if the feature is already in my capabilities
						for (NSXMLElement *childElement in query.children) {
							
							if([[childElement attributeStringValueForName:@"var"] isEqualToString:feature])
							{
								found = YES;
								break;
							}
						}
						
						//The feature is not already in our capabilities so add it
						if(!found)
						{
							NSXMLElement *featureElement = [NSXMLElement elementWithName:@"feature"];
							[featureElement addAttributeWithName:@"var" stringValue:feature];
							[query addChild:featureElement];
						}
					}
					
				}});
			}
						
			dispatch_async(moduleQueue, ^{ @autoreleasepool {
				
				[self continueCollectMyCapabilities:query];
			}});
			
		}});
	}
}

- (void)continueCollectMyCapabilities:(NSXMLElement *)query
{
	// This method must be invoked on the moduleQueue
	NSAssert(dispatch_get_specific(moduleQueueTag), @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	collectingMyCapabilities = NO;
	
	myCapabilitiesQuery = query;
	
	XMPPLogVerbose(@"%@: My capabilities:\n%@", THIS_FILE,
				   [query XMLStringWithOptions:(NSXMLNodeCompactEmptyElement | NSXMLNodePrettyPrint)]);
	
	NSString *hash = [self.class hashCapabilitiesFromQuery:query];
	
	if (hash == nil)
	{
		XMPPLogWarn(@"%@: Unable to hash capabilites (in order to send in presense element)\n"
					"Perhaps there are duplicate advertised features...\n%@", THIS_FILE,
					[query XMLStringWithOptions:(NSXMLNodeCompactEmptyElement | NSXMLNodePrettyPrint)]);
		return;
	}
	
	NSString *hashAlg = @"sha-1";
	
	// Cache the hash
	
	[xmppCapabilitiesStorage setCapabilities:query forHash:hash algorithm:hashAlg];
	
	// Create the c element, which will be added to normal outgoing presence elements.
	// 
	// <c xmlns="http://jabber.org/protocol/caps"
	//     hash="sha-1"
	//     node="https://github.com/robbiehanson/XMPPFramework"
	//     ver="QgayPKawpkPSDYmwT/WM94uA1u0="/>
	
	myCapabilitiesC = [[NSXMLElement alloc] initWithName:@"c" xmlns:XMLNS_CAPS];
	[myCapabilitiesC addAttributeWithName:@"hash" stringValue:hashAlg];
	[myCapabilitiesC addAttributeWithName:@"node" stringValue:myCapabilitiesNode];
	[myCapabilitiesC addAttributeWithName:@"ver"  stringValue:hash];
	
	// If the collection process started when the stream was connected,
	// and ended up taking so long as to not be available when the presence was sent,
	// we should re-broadcast our presence now that we know what our capabilities are.
	
	[xmppStream resendMyPresence];
}

- (void)recollectMyCapabilities
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		[self collectMyCapabilities];
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)sendDiscoInfoQueryTo:(XMPPJID *)jid withNode:(NSString *)node ver:(NSString *)ver
{
	// <iq to="romeo@montague.lit/orchard" id="uuid" type="get">
	//   <query xmlns="http://jabber.org/protocol/disco#info" node="[node]#[ver]"/>
	// </iq>
	// 
	// Note:
	// Some xmpp clients will return an error if we don't specify the proper query node.
	// Some xmpp clients will return an error if we don't include an id attribute in the iq.
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:XMLNS_DISCO_INFO];
	
	if (node && ver)
	{
		NSString *nodeValue = [NSString stringWithFormat:@"%@#%@", node, ver];
		
		[query addAttributeWithName:@"node" stringValue:nodeValue];
	}
	
	XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:jid elementID:[xmppStream generateUUID] child:query];
	
	[xmppStream sendElement:iq];
}

- (void)fetchCapabilitiesForJID:(XMPPJID *)jid
{
	// This is a public method.
	// It may be invoked on any thread/queue.
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if ([discoRequestJidSet containsObject:jid])
		{
			// We're already requesting capabilities concerning this JID
			return;
		}
		
		BOOL areCapabilitiesKnown;
		BOOL haveFailedFetchingBefore;
		
		NSString *node    = nil;
		NSString *ver     = nil;
		NSString *hash    = nil;
		NSString *hashAlg = nil;
		
		[xmppCapabilitiesStorage getCapabilitiesKnown:&areCapabilitiesKnown
		                                       failed:&haveFailedFetchingBefore
		                                         node:&node
		                                          ver:&ver
		                                          ext:nil
		                                         hash:&hash
		                                    algorithm:&hashAlg
		                                       forJID:jid
		                                   xmppStream:xmppStream];
		
		if (areCapabilitiesKnown)
		{
			// We already know the capabilities for this JID
			return;
		}
		if (haveFailedFetchingBefore)
		{
			// We've already sent a fetch request to the JID in the past, which failed.
			return;
		}
		
		NSString *key = nil;
		
		if (hash && hashAlg)
		{
			// This jid is associated with a capabilities hash.
			// 
			// Now, we've verified that the jid is not in the discoRequestJidSet.
			// But consider the following scenario.
			// 
			// - autoFetchCapabilities is false.
			// - We receive 2 presence elements from 2 different jids, both advertising the same capabilities hash.
			// - This method is called for the first jid.
			// - This method is then immediately called for the second jid.
			// 
			// Now since autoFetchCapabilities is false, the second jid will not be in the discoRequestJidSet.
			// However, there is still a disco request that concerns the jid.
			
			key = [self keyFromHash:hash algorithm:hashAlg];
			NSMutableArray *jids = discoRequestHashDict[key];
			
			if (jids)
			{
				// We're already requesting capabilities concerning this JID.
				// That is, there is another JID with the same hash, and we've already sent a disco request to it.
				
				[jids addObject:jid];
				[discoRequestJidSet addObject:jid];
				
				return;
			}
			
			// The first object in the jids array is the index of the last jid that we've sent a disco request to.
			// This is used in case the jid does not respond.
			
			NSNumber *requestIndexNum = @1;
			jids = [@[requestIndexNum, jid] mutableCopy];
			
			discoRequestHashDict[key] = jids;
			[discoRequestJidSet addObject:jid];
		}
		else
		{
			[discoRequestJidSet addObject:jid];
		}
		
		// Send disco#info query
		
		[self sendDiscoInfoQueryTo:jid withNode:node ver:ver];
		
		// Setup request timeout
		
		if (key)
		{
			[self setupTimeoutForDiscoRequestFromJID:jid withHashKey:key];
		}
		else
		{
			[self setupTimeoutForDiscoRequestFromJID:jid];
		}
		
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

/**
 * Invoked when an available presence element is received with
 * a capabilities child element that conforms to the XEP-0115 standard.
**/
- (void)handlePresenceCapabilities:(NSXMLElement *)c fromJID:(XMPPJID *)jid
{
	// This method must be invoked on the moduleQueue
	NSAssert(dispatch_get_specific(moduleQueueTag), @"Invoked on incorrect queue");
	
	XMPPLogTrace2(@"%@: %@ %@", THIS_FILE, THIS_METHOD, jid);
	
	// <presence from="romeo@montague.lit/orchard">
	//   <c xmlns="http://jabber.org/protocol/caps"
	//       hash="sha-1"
	//       node="http://code.google.com/p/exodus"
	//       ver="QgayPKawpkPSDYmwT/WM94uA1u0="/>
	// </presence>
	
	NSString *node = [c attributeStringValueForName:@"node"];
	NSString *ver  = [c attributeStringValueForName:@"ver"];
	NSString *hash = [c attributeStringValueForName:@"hash"];
	
	if ((node == nil) || (ver == nil))
	{
		// Invalid capabilities node!
		
		if (autoFetchNonHashedCapabilities)
		{
			[self fetchCapabilitiesForJID:jid];
		}
		
		return;
	}
	
	// Note: We already checked the hash variable in the xmppStream:didReceivePresence: method below.
	
	// Remember: hash="sha-1" ver="ABC-Actual-Hash-DEF".
	// It's a bit confusing as it was designed this way for backwards compatibility with v 1.4 and below.
	
	NSXMLElement *newCapabilities = nil;
	
	BOOL areCapabilitiesKnown = [xmppCapabilitiesStorage setCapabilitiesNode:node
	                                                                     ver:ver
	                                                                     ext:nil
	                                                                    hash:ver  // Yes, this is correct (see above)
	                                                               algorithm:hash // Ditto
	                                                                  forJID:jid
	                                                              xmppStream:xmppStream
	                                                   andGetNewCapabilities:&newCapabilities];
	if (areCapabilitiesKnown)
	{
		XMPPLogVerbose(@"%@: Capabilities already known for jid(%@) with hash(%@)", THIS_FILE, jid, ver);
		
		if (newCapabilities)
		{
			// This is the first time we've linked the jid with the set of capabilities.
			// We didn't need to do any lookups due to hashing and caching.
			
			// Notify the delegate(s)
			[multicastDelegate xmppCapabilities:self didDiscoverCapabilities:newCapabilities forJID:jid];
		}
		
		// The capabilities for this hash are already known
		return;
	}
	
	// Should we automatically fetch the capabilities?
	
	if (!autoFetchHashedCapabilities)
	{
		return;
	}
	
	// Are we already fetching the capabilities?
	
	NSString *key = [self keyFromHash:ver algorithm:hash];
	NSMutableArray *jids = discoRequestHashDict[key];
	
	if (jids)
	{
		XMPPLogVerbose(@"%@: We're already fetching capabilities for hash(%@)", THIS_FILE, ver);
		
		// Is the jid already included in this list?
		// 
		// There are actually two ways we can answer this question.
		// - Invoke containsObject on the array (jids)
		// - Invoke containsObject on the set (discoRequestJidSet)
		// 
		// This is much faster to do on a set.
		
		if (![discoRequestJidSet containsObject:jid])
		{
			[discoRequestJidSet addObject:jid];
			[jids addObject:jid];
		}
		
		// We've already sent a disco request concerning this hash.
		return;
	}
	
	// We've never sent a request for this hash.
	// Add the jid to the discoRequest variables.
	
	// Note: The first object in the jids array is the index of the last jid that we've sent a disco request to.
	// This is used in case the jid does not respond.
	// 
	// Here's the scenario:
	// We receive 5 presence elements from 5 different jids,
	// all advertising the same capabilities via the same hash.
	// We don't want to waste bandwidth and cpu by sending a disco request to all 5 jids.
	// So we send a disco request to the first jid.
	// But then what happens if that jid never responds?
	// Perhaps it went offline before it could get the message.
	// After a period of time ellapses, we should send a request to the next jid in the list.
	// So how do we know what the next jid in the list is?
	// Via the requestIndexNum of course.
	
	NSNumber *requestIndexNum = @1;
	jids = [@[requestIndexNum, jid] mutableCopy];
	
	discoRequestHashDict[key] = jids;
	[discoRequestJidSet addObject:jid];
	
	// Send disco#info query
	
	[self sendDiscoInfoQueryTo:jid withNode:node ver:ver];
	
	// Setup request timeout
	
	[self setupTimeoutForDiscoRequestFromJID:jid withHashKey:key];
}

/**
 * Invoked when an available presence element is received with
 * a capabilities child element that implements the legacy version of XEP-0115.
**/
- (void)handleLegacyPresenceCapabilities:(NSXMLElement *)c fromJID:(XMPPJID *)jid
{
	// This method must be invoked on the moduleQueue
	NSAssert(dispatch_get_specific(moduleQueueTag), @"Invoked on incorrect queue");
	
	XMPPLogTrace2(@"%@: %@ %@", THIS_FILE, THIS_METHOD, jid);
	
	NSString *node = [c attributeStringValueForName:@"node"];
	NSString *ver  = [c attributeStringValueForName:@"ver"];
	NSString *ext  = [c attributeStringValueForName:@"ext"];
	
	if ((node == nil) || (ver == nil))
	{
		// Invalid capabilities node!
		
		if (autoFetchNonHashedCapabilities)
		{
			[self fetchCapabilitiesForJID:jid];
		}
		
		return;
	}
	
	BOOL areCapabilitiesKnown = [xmppCapabilitiesStorage setCapabilitiesNode:node
	                                                                     ver:ver
	                                                                     ext:ext
	                                                                    hash:nil
	                                                               algorithm:nil
	                                                                  forJID:jid
	                                                              xmppStream:xmppStream
	                                                   andGetNewCapabilities:nil];
	if (areCapabilitiesKnown)
	{
		XMPPLogVerbose(@"%@: Capabilities already known for jid(%@)", THIS_FILE, jid);
		
		// The capabilities for this jid are already known
		return;
	}
	
	// Should we automatically fetch the capabilities?
	
	if (!autoFetchNonHashedCapabilities)
	{
		return;
	}
	
	// Are we already fetching the capabilities?
	
	if ([discoRequestJidSet containsObject:jid])
	{
		XMPPLogVerbose(@"%@: We're already fetching capabilities for jid(%@)", THIS_FILE, jid);
		
		// We've already sent a disco request to this jid.
		return;
	}
	
	[discoRequestJidSet addObject:jid];
	
	// Send disco#info query
	
	[self sendDiscoInfoQueryTo:jid withNode:node ver:ver];
	
	// Setup request timeout
	
	[self setupTimeoutForDiscoRequestFromJID:jid];
}

/**
 * Invoked when we receive a disco request (request for our capabilities).
 * We should response with the proper disco response.
**/
- (void)handleDiscoRequest:(XMPPIQ *)iqRequest
{
	// This method must be invoked on the moduleQueue
	NSAssert(dispatch_get_specific(moduleQueueTag), @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	if (myCapabilitiesQuery == nil)
	{
		// It appears we haven't collected our list of capabilites yet.
		// This will need to be done before we can add the hash to the outgoing presence element.
		
		[self collectMyCapabilities];
	}
	else if (myCapabilitiesC)
	{
		NSXMLElement *queryRequest = [iqRequest childElement];
		NSString *node = [queryRequest attributeStringValueForName:@"node"];
		
		// <iq to="jid" id="id" type="result">
		//   <query xmlns="http://jabber.org/protocol/disco#info">
		//     <feature var="feature1"/>
		//     <feature var="feature2"/>
		//   </query>
		// </iq>
		
		NSXMLElement *query = [myCapabilitiesQuery copy];
		if (node)
		{
			[query addAttributeWithName:@"node" stringValue:node];
		}
		
		XMPPIQ *iqResponse = [XMPPIQ iqWithType:@"result"
		                                     to:[iqRequest from]
		                              elementID:[iqRequest elementID]
		                                  child:query];
		
		[xmppStream sendElement:iqResponse];
	}
}

/**
 * Invoked when we receive a response to one of our previously sent disco requests.
**/
- (void)handleDiscoResponse:(NSXMLElement *)querySubElement fromJID:(XMPPJID *)jid
{
	// This method must be invoked on the moduleQueue
	NSAssert(dispatch_get_specific(moduleQueueTag), @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	// Remember XML hiearchy memory management rules.
	// The passed parameter is a subnode of the IQ, and we need to pass it asynchronously to storge / delegate(s).
	NSXMLElement *query = [querySubElement copy];
	
	NSString *hash = nil;
	NSString *hashAlg = nil;
	
	BOOL hashResponse = [xmppCapabilitiesStorage getCapabilitiesHash:&hash
	                                                       algorithm:&hashAlg
	                                                          forJID:jid
	                                                      xmppStream:xmppStream];
	if (hashResponse)
	{
		XMPPLogVerbose(@"%@: %@ - Hash response...", THIS_FILE, THIS_METHOD);
		
		// Standard version 1.5+
		
		NSString *key = [self keyFromHash:hash algorithm:hashAlg];
		
		NSString *calculatedHash = [self.class hashCapabilitiesFromQuery:query];
		
		if ([calculatedHash isEqualToString:hash])
		{
			XMPPLogVerbose(@"%@: %@ - Hash matches!", THIS_FILE, THIS_METHOD);
			
			// Store the capabilities (associated with the hash)
			[xmppCapabilitiesStorage setCapabilities:query forHash:hash algorithm:hashAlg];
			
			// Remove the jid(s) from the discoRequest variables
			NSArray *jids = discoRequestHashDict[key];
			
			NSUInteger i;
			for (i = 1; i < [jids count]; i++)
			{
				XMPPJID *currentJid = jids[i];
				
				[discoRequestJidSet removeObject:currentJid];
				
				// Notify the delegate(s)
				[multicastDelegate xmppCapabilities:self didDiscoverCapabilities:query forJID:currentJid];
			}
			
			[discoRequestHashDict removeObjectForKey:key];
			
			// Cancel the request timeout
			[self cancelTimeoutForDiscoRequestFromJID:jid];
		}
		else
		{
			XMPPLogWarn(@"%@: Hash mismatch! hash(%@) != calculatedHash(%@)", THIS_FILE, hash, calculatedHash);
			
			// Revoke the associated hash from the jid
			[xmppCapabilitiesStorage clearCapabilitiesHashAndAlgorithmForJID:jid xmppStream:xmppStream];
			
			// Now set the capabilities for the jid
			[xmppCapabilitiesStorage setCapabilities:query forJID:jid xmppStream:xmppStream];
			
			// Notify the delegate(s)
			[multicastDelegate xmppCapabilities:self didDiscoverCapabilities:query forJID:jid];
			
			// We'd still like to know what the capabilities are for this hash.
			// Move onto the next one in the list (if there are more, otherwise stop).
			[self maybeQueryNextJidWithHashKey:key dueToHashMismatch:YES];
		}
	}
	else
	{
		XMPPLogVerbose(@"%@: %@ - Non-Hash response", THIS_FILE, THIS_METHOD);
		
		// Store the capabilities (associated with the jid)		
		[xmppCapabilitiesStorage setCapabilities:query forJID:jid xmppStream:xmppStream];
		
		// Remove the jid from the discoRequest variable
		[discoRequestJidSet removeObject:jid];
		
		// Cancel the request timeout
		[self cancelTimeoutForDiscoRequestFromJID:jid];
		
		// Notify the delegate(s)
		[multicastDelegate xmppCapabilities:self didDiscoverCapabilities:query forJID:jid];
	}
}

- (void)handleDiscoErrorResponse:(NSXMLElement *)querySubElement fromJID:(XMPPJID *)jid
{
	// This method must be invoked on the moduleQueue
	NSAssert(dispatch_get_specific(moduleQueueTag), @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	NSString *hash = nil;
	NSString *hashAlg = nil;
	
	BOOL hashResponse = [xmppCapabilitiesStorage getCapabilitiesHash:&hash
	                                                       algorithm:&hashAlg
	                                                          forJID:jid
	                                                      xmppStream:xmppStream];
	if (hashResponse)
	{
		NSString *key = [self keyFromHash:hash algorithm:hashAlg];
		
		// We'd still like to know what the capabilities are for this hash.
		// Move onto the next one in the list (if there are more, otherwise stop).
		[self maybeQueryNextJidWithHashKey:key dueToHashMismatch:NO];
	}
	else
	{
		// Make a note of the failure
		[xmppCapabilitiesStorage setCapabilitiesFetchFailedForJID:jid xmppStream:xmppStream];
		
		// Remove the jid from the discoRequest variable
		[discoRequestJidSet removeObject:jid];
		
		// Cancel the request timeout
		[self cancelTimeoutForDiscoRequestFromJID:jid];
	}
}

- (void)maybeQueryNextJidWithHashKey:(NSString *)key dueToHashMismatch:(BOOL)hashMismatch
{
	// This method must be invoked on the moduleQueue
	NSAssert(dispatch_get_specific(moduleQueueTag), @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	// Get the list of jids that have the same capabilities hash
	
	NSMutableArray *jids = discoRequestHashDict[key];
	if (jids == nil)
	{
		XMPPLogWarn(@"%@: %@ - Key doesn't exist in discoRequestHashDict", THIS_FILE, THIS_METHOD);
		
		return;
	}
	
	// Get the index and jid of the fetch that just failed
	
	NSUInteger requestIndex = [jids[0] unsignedIntegerValue];
	XMPPJID *jid = jids[requestIndex];
	
	// Release the associated timer
	[self cancelTimeoutForDiscoRequestFromJID:jid];
	
	if (hashMismatch)
	{
		// We need to remove the naughty jid from the lists.
		
		[discoRequestJidSet removeObject:jid];
		[jids removeObjectAtIndex:requestIndex];
	}
	else
	{
		// We want to move onto the next jid in the list.
		// Increment request index (and update object in jids array),
	
		requestIndex++;
		jids[0] = @(requestIndex);
	}
	
	// Do we have another jid that we can query?
	// That is, another jid that was broadcasting the same capabilities hash.
	
	if (requestIndex < [jids count])
	{
		jid = jids[requestIndex];
		
		NSString *node = nil;
		NSString *ver  = nil;
		
		[xmppCapabilitiesStorage getCapabilitiesKnown:nil
		                                       failed:nil
		                                         node:&node
		                                          ver:&ver
		                                          ext:nil
		                                         hash:nil
		                                    algorithm:nil
		                                       forJID:jid
		                                   xmppStream:xmppStream];
		
		// Send disco#info query
		
		[self sendDiscoInfoQueryTo:jid withNode:node ver:ver];
		
		// Setup request timeout
		
		[self setupTimeoutForDiscoRequestFromJID:jid withHashKey:key];
	}
	else
	{
		// We've queried every single jid that was broadcasting this capabilities hash.
		// Nothing left to do now but wait.
		// 
		// If one of the jids happens to eventually respond,
		// then we'll still be able to link the capabilities to every jid with the same capabilities hash.
		// 
		// This would be handled by the xmppCapabilitiesStorage class,
		// via the setCapabilitiesForJID method.
		
		NSUInteger i;
		for (i = 1; i < [jids count]; i++)
		{
			jid = jids[i];
			
			[discoRequestJidSet removeObject:jid];
			[xmppCapabilitiesStorage setCapabilitiesFetchFailedForJID:jid xmppStream:xmppStream];
		}
		
		[discoRequestHashDict removeObjectForKey:key];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
	// If this is the first time we've connected, start collecting our list of capabilities.
	// We do this now so that the process is likely ready by the time we need to send a presence element.
	
	if (myCapabilitiesQuery == nil)
	{
		[self collectMyCapabilities];
	}
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{	
	if (autoFetchMyServerCapabilities)
	{
		XMPPJID *myJID = [xmppStream myJID];
		XMPPJID *myServerJID = [XMPPJID jidWithUser:nil domain:[myJID domain] resource:nil];
		[self fetchCapabilitiesForJID:myServerJID];
	}
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
	// This method is invoked on the moduleQueue.
	
	// XEP-0115 presence:
	// 
	// <presence from="romeo@montague.lit/orchard">
	//   <c xmlns="http://jabber.org/protocol/caps"
	//       hash="sha-1"
	//       node="http://code.google.com/p/exodus"
	//       ver="QgayPKawpkPSDYmwT/WM94uA1u0="/>
	// </presence>
	
	NSString *type = [presence type];
	
	XMPPJID *myJID = xmppStream.myJID;
	if ([myJID isEqual:[presence from]])
	{
		// Our own presence is being reflected back to us.
		return;
	}
	
	if ([type isEqualToString:@"unavailable"])
	{
		[xmppCapabilitiesStorage clearNonPersistentCapabilitiesForJID:[presence from] xmppStream:xmppStream];
	}
	else if ([type isEqualToString:@"available"])
	{
		NSXMLElement *c = [presence elementForName:@"c" xmlns:XMLNS_CAPS];
		if (c == nil)
		{
			if (autoFetchNonHashedCapabilities)
			{
				[self fetchCapabilitiesForJID:[presence from]];
			}
		}
		else
		{
			NSString *hash = [c attributeStringValueForName:@"hash"];
			if (hash)
			{
				[self handlePresenceCapabilities:c fromJID:[presence from]];
			}
			else
			{
				[self handleLegacyPresenceCapabilities:c fromJID:[presence from]];
			}
		}
	}
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	// This method is invoked on the moduleQueue.
	
	// Disco Request:
	// 
	// <iq from="juliet@capulet.lit/chamber" type="get">
	//   <query xmlns="http://jabber.org/protocol/disco#info"/>
	// </iq>
	// 
	// Disco Response:
	// 
	// <iq from="romeo@montague.lit/orchard" type="result">
	//   <query xmlns="http://jabber.org/protocol/disco#info">
	//     <feature var="feature1"/>
	//     <feature var="feature2"/>
	//   </query>
	// </iq>
	
	NSXMLElement *query = [iq elementForName:@"query" xmlns:XMLNS_DISCO_INFO];
	if (query == nil)
	{
		return NO;
	}
	
	NSString *type = [[iq attributeStringValueForName:@"type"] lowercaseString];
	if ([type isEqualToString:@"get"])
	{
		NSString *node = [query attributeStringValueForName:@"node"];
		
		if (node == nil || [node hasPrefix:myCapabilitiesNode])
		{
			[self handleDiscoRequest:iq];
		}
		else
		{
			return NO;
		}
	}
	else if ([type isEqualToString:@"result"])
	{
		[self handleDiscoResponse:query fromJID:[iq from]];
	}
	else if ([type isEqualToString:@"error"])
	{
		[self handleDiscoErrorResponse:query fromJID:[iq from]];
	}
	else
	{
		return NO;
	}
	
	return YES;
}

- (XMPPPresence *)xmppStream:(XMPPStream *)sender willSendPresence:(XMPPPresence *)presence
{
	// This method is invoked on the moduleQueue.
	
	NSString *type = [presence type];
	
	if ([type isEqualToString:@"unavailable"])
	{
		[xmppCapabilitiesStorage clearAllNonPersistentCapabilitiesForXMPPStream:xmppStream];
	}
	else if ([type isEqualToString:@"available"])
	{
		if (myCapabilitiesQuery == nil)
		{
			// It appears we haven't collected our list of capabilites yet.
			// This will need to be done before we can add the hash to the outgoing presence element.
			
			[self collectMyCapabilities];
		}
		else if (myCapabilitiesC)
		{
			NSXMLElement *c = [myCapabilitiesC copy];
			NSXMLElement *oldC = [presence elementForName:c.name xmlns:c.xmlns];
			if (oldC)
			{
				[presence removeChildAtIndex:[presence.children indexOfObject:oldC]];
				[presence addChild:c];
			}
			else
			{
				[presence addChild:c];
			}
		}
	}
	
	return presence;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Timers
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setupTimeoutForDiscoRequestFromJID:(XMPPJID *)jid
{
	// This method must be invoked on the moduleQueue
	NSAssert(dispatch_get_specific(moduleQueueTag), @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	// If the timeout occurs, we will remove the jid from the discoRequestJidSet.
	// If we eventually get a response (after the timeout) we will still be able to process it.
	// The timeout simply prevents the set from growing infinitely.
	
	dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, moduleQueue);
	
	dispatch_source_set_event_handler(timer, ^{ @autoreleasepool {
		
		[self processTimeoutWithJID:jid];
		
		dispatch_source_cancel(timer);
		#if !OS_OBJECT_USE_OBJC
		dispatch_release(timer);
		#endif
	}});
	
	dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (CAPABILITIES_REQUEST_TIMEOUT * NSEC_PER_SEC));
	
	dispatch_source_set_timer(timer, tt, DISPATCH_TIME_FOREVER, 0);
	dispatch_resume(timer);
	
	// We also keep a reference to the timer in the discoTimerJidDict.
	// This allows us to cancel the timer when we get a response to the disco request.
	
	GCDTimerWrapper *timerWrapper = [[GCDTimerWrapper alloc] initWithDispatchTimer:timer];
	
	discoTimerJidDict[jid] = timerWrapper;
}

- (void)setupTimeoutForDiscoRequestFromJID:(XMPPJID *)jid withHashKey:(NSString *)key
{
	// This method must be invoked on the moduleQueue
	NSAssert(dispatch_get_specific(moduleQueueTag), @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	// If the timeout occurs, we want to send a request to the next jid with the same capabilities hash.
	// This list of jids is stored in the discoRequestHashDict.
	// The key will allow us to fetch the jid list.
		
	dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, moduleQueue);
	
	dispatch_source_set_event_handler(timer, ^{ @autoreleasepool {
		
		[self processTimeoutWithHashKey:key];
		
		dispatch_source_cancel(timer);
		#if !OS_OBJECT_USE_OBJC
		dispatch_release(timer);
		#endif
	}});
	
	dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (CAPABILITIES_REQUEST_TIMEOUT * NSEC_PER_SEC));
	
	dispatch_source_set_timer(timer, tt, DISPATCH_TIME_FOREVER, 0);
	dispatch_resume(timer);
	
	// We also keep a reference to the timer in the discoTimerJidDict.
	// This allows us to cancel the timer when we get a response to the disco request.
	
	GCDTimerWrapper *timerWrapper = [[GCDTimerWrapper alloc] initWithDispatchTimer:timer];
	
	discoTimerJidDict[jid] = timerWrapper;
}

- (void)cancelTimeoutForDiscoRequestFromJID:(XMPPJID *)jid
{
	// This method must be invoked on the moduleQueue
	NSAssert(dispatch_get_specific(moduleQueueTag), @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	GCDTimerWrapper *timerWrapper = discoTimerJidDict[jid];
	if (timerWrapper)
	{
		[timerWrapper cancel];
		[discoTimerJidDict removeObjectForKey:jid];
	}
}

- (void)processTimeoutWithHashKey:(NSString *)key
{
	// This method must be invoked on the moduleQueue
	NSAssert(dispatch_get_specific(moduleQueueTag), @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	[self maybeQueryNextJidWithHashKey:key dueToHashMismatch:NO];
}

- (void)processTimeoutWithJID:(XMPPJID *)jid
{
	// This method must be invoked on the moduleQueue
	NSAssert(dispatch_get_specific(moduleQueueTag), @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	// We queried the jid for its capabilities, but it didn't answer us.
	// Nothing left to do now but wait.
	// 
	// If it happens to eventually respond,
	// then we'll still be able to process the capabilities properly.
	// 
	// But at this point we're going to consider the query to be done.
	// This prevents our discoRequestJidSet from growing infinitely,
	// and also opens up the possibility of sending it another query in the future.
	
	[discoRequestJidSet removeObject:jid];
	[xmppCapabilitiesStorage setCapabilitiesFetchFailedForJID:jid xmppStream:xmppStream];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation GCDTimerWrapper

- (id)initWithDispatchTimer:(dispatch_source_t)aTimer
{
	if ((self = [super init]))
	{
		timer = aTimer;
		#if !OS_OBJECT_USE_OBJC
		dispatch_retain(timer);
		#endif
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

@end
