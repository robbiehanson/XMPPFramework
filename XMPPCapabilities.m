#import "XMPP.h"
#import "XMPPCapabilities.h"
#import "NSDataAdditions.h"

// Debug levels: 0-off, 1-error, 2-warn, 3-info, 4-verbose
#define DEBUG_LEVEL 2
#include "DDLog.h"

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
 * Application identifier.
 * According to the XEP it is RECOMMENDED for the value of the 'node' attribute to be an HTTP URL.
**/
#define DISCO_NODE @"http://code.google.com/p/xmppframework"


@interface XMPPCapabilities (PrivateAPI)

- (void)setupTimeoutForDiscoRequestFromJID:(XMPPJID *)jid;
- (void)setupTimeoutForDiscoRequestFromJID:(XMPPJID *)jid withHashKey:(NSString *)key;

- (void)cancelTimeoutForDiscoRequestFromJID:(XMPPJID *)jid;

- (void)processTimeoutWithHashKey:(NSString *)key;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPCapabilities

@synthesize xmppCapabilitiesStorage;
@synthesize autoFetchHashedCapabilities;
@synthesize autoFetchNonHashedCapabilities;

- (id)initWithStream:(XMPPStream *)aXmppStream capabilitiesStorage:(id <XMPPCapabilitiesStorage>)storage
{
	if ((self = [super initWithStream:aXmppStream]))
	{
		xmppCapabilitiesStorage = [storage retain];
		
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
	}
	return self;
}

- (void)dealloc
{
	[xmppCapabilitiesStorage release];
	
	[discoRequestJidSet release];
	[discoRequestHashDict release];
	
	for (NSTimer *timer in discoTimerJidDict)
	{
		[timer invalidate];
	}
	[discoTimerJidDict release];
	
	[lastHash release];
	
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Hashing
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

NSString* encodeLt(NSString *str)
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

NSInteger sortIdentities(NSXMLElement *identity1, NSXMLElement *identity2, void *context)
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

NSInteger sortFeatures(NSXMLElement *feature1, NSXMLElement *feature2, void *context)
{
	// All sort operations MUST be performed using "i;octet" collation as specified in Section 9.3 of RFC 4790.
	
	NSString *var1 = [feature1 attributeStringValueForName:@"var" withDefaultValue:@""];
	NSString *var2 = [feature2 attributeStringValueForName:@"var" withDefaultValue:@""];
	
	var1 = encodeLt(var1);
	var2 = encodeLt(var2);
	
	return [var1 compare:var2 options:NSLiteralSearch];
}

NSString* extractFormTypeValue(NSXMLElement *form)
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
					NSString *baseValue = [[values objectAtIndex:0] stringValue];
					
					NSUInteger i;
					for (i = 1; i < [values count]; i++)
					{
						NSString *value = [[values objectAtIndex:i] stringValue];
						
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

NSInteger sortForms(NSXMLElement *form1, NSXMLElement *form2, void *context)
{
	// Sort the forms by the FORM_TYPE (i.e., by the XML character data of the <value/> element.
	// 
	// All sort operations MUST be performed using "i;octet" collation as specified in Section 9.3 of RFC 4790.
	
	NSString *formTypeValue1 = extractFormTypeValue(form1);
	NSString *formTypeValue2 = extractFormTypeValue(form2);
	
	// The formTypeValue variable is guaranteed to be properly encoded.
	
	return [formTypeValue1 compare:formTypeValue2 options:NSLiteralSearch];
}

NSInteger sortFormFields(NSXMLElement *field1, NSXMLElement *field2, void *context)
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

NSInteger sortFieldValues(NSXMLElement *value1, NSXMLElement *value2, void *context)
{
	NSString *str1 = [value1 stringValue];
	NSString *str2 = [value2 stringValue];
	
	if (str1 == nil) str1 = @"";
	if (str2 == nil) str2 = @"";
	
	str1 = encodeLt(str1);
	str2 = encodeLt(str2);
	
	return [str1 compare:str2 options:NSLiteralSearch];
}

- (NSString *)hashCapabilitiesFromQuery:(NSXMLElement *)query
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
	NSData *hash = [data sha1Digest];
	
	return [hash base64Encoded];
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

- (void)fetchCapabilitiesForJID:(XMPPJID *)jid
{
	if (![jid isFull])
	{
		// Invalid JID - Must be a full JID (i.e. it must include the resource)
		return;
	}
	
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
	                                       forJID:jid];
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
		NSMutableArray *jids = [discoRequestHashDict objectForKey:key];
		
		if (jids)
		{
			// We're already requesting capabilities concerning this JID.
			// That is, there is another JID with the same hash, and we've already sent a disco request to it.
			
			[jids addObject:jid];
			[discoRequestJidSet addObject:jid];
			
			return;
		}
		
		// Note: The first object in the jids array is the index of the last jid that we've sent a disco request to.
		// This is used in case the jid does not respond.
		
		NSNumber *requestIndexNum = [NSNumber numberWithUnsignedInteger:1];
		jids = [NSMutableArray arrayWithObjects:requestIndexNum, jid, nil];
		
		[discoRequestHashDict setObject:jids forKey:key];
		[discoRequestJidSet addObject:jid];
	}
	else
	{
		[discoRequestJidSet addObject:jid];
	}
	
	// <iq to="romeo@montague.lit/orchard" id="uuid" type="get">
	//   <query xmlns="http://jabber.org/protocol/disco#info" node="[node]#[ver]"/>
	// </iq>
	// 
	// Note:
	// Some xmpp clients will return an error if we don't specify the proper query node.
	// Some xmpp clients will return an error if we don't include an id attribute in the iq.
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"http://jabber.org/protocol/disco#info"];
	
	if (node && ver)
	{
		NSString *nodeValue = [NSString stringWithFormat:@"%@#%@", node, ver];
		
		[query addAttributeWithName:@"node" stringValue:nodeValue];
	}
	
	XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:jid elementID:[xmppStream generateUUID] child:query];
	
	[xmppStream sendElement:iq];
	
	// Setup request timeout
	
	if (key)
	{
		[self setupTimeoutForDiscoRequestFromJID:jid withHashKey:key];
	}
	else
	{
		[self setupTimeoutForDiscoRequestFromJID:jid];
	}
}

/**
 * Invoked when an available presence element is received with
 * a capabilities child element that conforms to the XEP-0115 standard.
**/
- (void)handlePresenceCapabilities:(NSXMLElement *)c fromJID:(XMPPJID *)jid
{
	DDLogVerbose(@"%@: %@ %@", THIS_FILE, THIS_METHOD, jid);
	
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
		
		if (self.autoFetchNonHashedCapabilities)
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
	                                                                    hash:ver
	                                                               algorithm:hash
	                                                                  forJID:jid
													   andGetNewCapabilities:&newCapabilities];
	if (areCapabilitiesKnown)
	{
		DDLogVerbose(@"Capabilities already known for jid(%@) with hash(%@)", jid, ver);
		
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
	
	if (!self.autoFetchHashedCapabilities)
	{
		return;
	}
	
	// Are we already fetching the capabilities?
	
	NSString *key = [self keyFromHash:ver algorithm:hash];
	NSMutableArray *jids = [discoRequestHashDict objectForKey:key];
	
	if (jids)
	{
		DDLogVerbose(@"We're already fetching capabilities for hash(%@)", ver);
		
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
	
	NSNumber *requestIndexNum = [NSNumber numberWithUnsignedInteger:1];
	jids = [NSMutableArray arrayWithObjects:requestIndexNum, jid, nil];
	
	[discoRequestHashDict setObject:jids forKey:key];
	[discoRequestJidSet addObject:jid];
	
	// <iq to="romeo@montague.lit/orchard" type="get">
	//   <query xmlns="http://jabber.org/protocol/disco#info"
	//          node="http://code.google.com/p/exodus#QgayPKawpkPSDYmwT/WM94uA1u0="/>
	// </iq>
	// 
	// Note:
	// Some xmpp clients will return an error if we don't specify the proper query node.
	// Some xmpp clients will return an error if we don't include an id attribute in the iq.
	
	NSString *nodeValue = [NSString stringWithFormat:@"%@#%@", node, ver];
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"http://jabber.org/protocol/disco#info"];
	[query addAttributeWithName:@"node" stringValue:nodeValue];
	
	XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:jid elementID:[xmppStream generateUUID] child:query];
	
	[xmppStream sendElement:iq];
	
	// Setup request timeout
	
	[self setupTimeoutForDiscoRequestFromJID:jid withHashKey:key];
}

/**
 * Invoked when an available presence element is received with
 * a capabilities child element that implements the legacy version of XEP-0115.
**/
- (void)handleLegacyPresenceCapabilities:(NSXMLElement *)c fromJID:(XMPPJID *)jid
{
	DDLogVerbose(@"%@: %@ %@", THIS_FILE, THIS_METHOD, jid);
	
	NSString *node = [c attributeStringValueForName:@"node"];
	NSString *ver  = [c attributeStringValueForName:@"ver"];
	NSString *ext  = [c attributeStringValueForName:@"ext"];
	
	if ((node == nil) || (ver == nil))
	{
		// Invalid capabilities node!
		
		if (self.autoFetchNonHashedCapabilities)
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
													   andGetNewCapabilities:nil];
	if (areCapabilitiesKnown)
	{
		DDLogVerbose(@"Capabilities already known for jid(%@)", jid);
		
		// The capabilities for this jid are already known
		return;
	}
	
	// Should we automatically fetch the capabilities?
	
	if (!self.autoFetchNonHashedCapabilities)
	{
		return;
	}
	
	// Are we already fetching the capabilities?
	
	if ([discoRequestJidSet containsObject:jid])
	{
		DDLogVerbose(@"We're already fetching capabilities for jid(%@)", jid);
		
		// We've already sent a disco request to this jid.
		return;
	}
	
	[discoRequestJidSet addObject:jid];
	
	// <iq to="romeo@montague.lit/orchard" type="get">
	//   <query xmlns="http://jabber.org/protocol/disco#info"
	//           node="http://code.google.com/p/exodus#1.0.6"/>
	// </iq>
	// 
	// Note:
	// Some xmpp clients will return an error if we don't specify the proper query node.
	// Some xmpp clients will return an error if we don't include an id attribute in the iq.
	
	NSString *nodeValue = [NSString stringWithFormat:@"%@#%@", node, ver];
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"http://jabber.org/protocol/disco#info"];
	[query addAttributeWithName:@"node" stringValue:nodeValue];
	
	XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:jid elementID:[xmppStream generateUUID] child:query];
	
	[xmppStream sendElement:iq];
	
	// Setup request timeout
	
	[self setupTimeoutForDiscoRequestFromJID:jid];
}

/**
 * Invoked when we receive a disco request (request for our capabilities).
 * We should response with the proper disco response.
**/
- (void)handleDiscoRequest:(XMPPIQ *)iqRequest
{
	NSXMLElement *queryRequest = [iqRequest childElement];
	NSString *node = [queryRequest attributeStringValueForName:@"node"];
	
	// <iq to="jid" id="id" type="result">
	//   <query xmlns="http://jabber.org/protocol/disco#info">
	//     <feature var='http://jabber.org/protocol/disco#info'/>
	//     <feature var="http://jabber.org/protocol/caps"/>
	//     <feature var="feature1"/>
	//     <feature var="feature2"/>
	//   </query>
	// </iq>
	
	NSXMLElement *feature1 = [NSXMLElement elementWithName:@"feature"];
	[feature1 addAttributeWithName:@"var" stringValue:@"http://jabber.org/protocol/caps"];

	NSXMLElement *feature2 = [NSXMLElement elementWithName:@"feature"];
	[feature2 addAttributeWithName:@"var" stringValue:@"http://jabber.org/protocol/disco#info"];	
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"http://jabber.org/protocol/disco#info"];
	[query addChild:feature1];
	[query addChild:feature2];
	
	if (node)
	{
		[query addAttributeWithName:@"node" stringValue:node];
	}
	
	[multicastDelegate xmppCapabilities:self willSendMyCapabilities:query];
	
	XMPPIQ *iqResponse = [XMPPIQ iqWithType:@"result"
	                                     to:[iqRequest from]
	                              elementID:[iqRequest elementID]
	                                  child:query];
	
	[xmppStream sendElement:iqResponse];
}

/**
 * Invoked when we receive a response to one of our previously sent disco requests.
**/
- (void)handleDiscoResponse:(NSXMLElement *)query fromJID:(XMPPJID *)jid
{
	DDLogTrace();
	
	NSString *hash = nil;
	NSString *hashAlg = nil;
	
	BOOL hashResponse = [xmppCapabilitiesStorage getCapabilitiesHash:&hash algorithm:&hashAlg forJID:jid];
	
	if (hashResponse)
	{
		DDLogVerbose(@"%@: %@ - Hash response...", THIS_FILE, THIS_METHOD);
		
		// Standard version 1.5+
		
		NSString *key = [self keyFromHash:hash algorithm:hashAlg];
		
		NSString *calculatedHash = [self hashCapabilitiesFromQuery:query];
		
		if ([calculatedHash isEqualToString:hash])
		{
			DDLogVerbose(@"%@: %@ - Hash matches!", THIS_FILE, THIS_METHOD);
			
			// Store the capabilities (associated with the hash)
			[xmppCapabilitiesStorage setCapabilities:query forHash:hash algorithm:hashAlg];
			
			// Remove the jid(s) from the discoRequest variables
			NSArray *jids = [discoRequestHashDict objectForKey:key];
			
			NSUInteger i;
			for (i = 1; i < [jids count]; i++)
			{
				XMPPJID *aJid = [jids objectAtIndex:i];
				
				[discoRequestJidSet removeObject:aJid];
				
				// Notify the delegate(s)
				[multicastDelegate xmppCapabilities:self didDiscoverCapabilities:query forJID:jid];
			}
			
			[discoRequestHashDict removeObjectForKey:key];
			
			// Cancel the request timeout
			[self cancelTimeoutForDiscoRequestFromJID:jid];
		}
		else
		{
			DDLogWarn(@"Hash mismatch!!");
			DDLogWarn(@"          hash = %@", hash);
			DDLogWarn(@"calculatedHash = %@", calculatedHash);
			
			// Revoke the associated hash from the jid
			[xmppCapabilitiesStorage clearCapabilitiesHashAndAlgorithmForJID:jid];
			
			// Now set the capabilities for the jid
			[xmppCapabilitiesStorage setCapabilities:query forJID:jid];
			
			// Remove the jid from the discoRequest variables.
			// 
			// When we remove it from the discoRequestHashDict
			// we also need to be sure to decrement the requestIndex
			// so the next jid in the list doesn't get skipped.
			
			[discoRequestJidSet removeObject:jid];
			
			NSMutableArray *jids = [discoRequestHashDict objectForKey:key];
			NSUInteger requestIndex = [[jids objectAtIndex:0] unsignedIntegerValue];
			
			[jids removeObjectAtIndex:requestIndex];
			
			requestIndex--;
			[jids replaceObjectAtIndex:0 withObject:[NSNumber numberWithUnsignedInteger:requestIndex]];
			
			// Notify the delegate(s)
			[multicastDelegate xmppCapabilities:self didDiscoverCapabilities:query forJID:jid];
			
			// We'd still like to know what the capabilities are for this hash.
			// Move onto the next one in the list (if there are more, otherwise stop).
			[self processTimeoutWithHashKey:key];
		}
	}
	else
	{
		DDLogVerbose(@"%@: %@ - Non-Hash response", THIS_FILE, THIS_METHOD);
		
		// Store the capabilities (associated with the jid)		
		[xmppCapabilitiesStorage setCapabilities:query forJID:jid];
		
		// Remove the jid from the discoRequest variable
		[discoRequestJidSet removeObject:jid];
		
		// Cancel the request timeout
		[self cancelTimeoutForDiscoRequestFromJID:jid];
		
		// Notify the delegate(s)
		[multicastDelegate xmppCapabilities:self didDiscoverCapabilities:query forJID:jid];
	}
}

- (void)handleDiscoErrorResponse:(NSXMLElement *)query fromJID:(XMPPJID *)jid
{
	DDLogTrace();
	
	NSString *hash = nil;
	NSString *hashAlg = nil;
	
	BOOL hashResponse = [xmppCapabilitiesStorage getCapabilitiesHash:&hash algorithm:&hashAlg forJID:jid];
	
	if (hashResponse)
	{
		NSString *key = [self keyFromHash:hash algorithm:hashAlg];
		
		// Make a note of the failure
		[xmppCapabilitiesStorage setCapabilitiesFetchFailedForJID:jid];
		
		// Remove the jid from the discoRequest variable
		[discoRequestJidSet removeObject:jid];
		
		// We'd still like to know what the capabilities are for this hash.
		// Move onto the next one in the list (if there are more, otherwise stop).
		[self processTimeoutWithHashKey:key];
	}
	else
	{
		// Make a note of the failure
		[xmppCapabilitiesStorage setCapabilitiesFetchFailedForJID:jid];
		
		// Remove the jid from the discoRequest variable
		[discoRequestJidSet removeObject:jid];
		
		// Cancel the request timeout
		[self cancelTimeoutForDiscoRequestFromJID:jid];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
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
		[xmppCapabilitiesStorage clearNonPersistentCapabilitiesForJID:[presence from]];
	}
	else if ([type isEqualToString:@"available"])
	{
		NSXMLElement *c = [presence elementForName:@"c" xmlns:@"http://jabber.org/protocol/caps"];
		if (c == nil)
		{
			if (self.autoFetchNonHashedCapabilities)
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
	
	NSXMLElement *query = [iq elementForName:@"query" xmlns:@"http://jabber.org/protocol/disco#info"];
	if (query == nil)
	{
		return NO;
	}
	
	NSString *type = [[iq attributeStringValueForName:@"type"] lowercaseString];
	if ([type isEqualToString:@"get"])
	{
		NSString *node = [query attributeStringValueForName:@"node"];
		
		if (node == nil || [node hasPrefix:DISCO_NODE])
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

- (void)xmppStream:(XMPPStream *)sender willSendPresence:(XMPPPresence *)presence
{
	NSString *type = [presence type];
	
	if ([type isEqualToString:@"unavailable"])
	{
		[xmppCapabilitiesStorage clearAllNonPersistentCapabilities];
	}
	else if ([type isEqualToString:@"available"])
	{
		// <query xmlns="http://jabber.org/protocol/disco#info">
		//   <feature var="http://jabber.org/protocol/caps"/>
		//   <feature var="feature1"/>
		//   <feature var="feature2"/>
		// </query>
		
		NSXMLElement *feature = [NSXMLElement elementWithName:@"feature"];
		[feature addAttributeWithName:@"var" stringValue:@"http://jabber.org/protocol/caps"];
		
		NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"http://jabber.org/protocol/disco#info"];
		[query addChild:feature];
		
		[multicastDelegate xmppCapabilities:self willSendMyCapabilities:query];
		
		DDLogVerbose(@"%@: My capabilities:\n%@", THIS_FILE,
					 [query XMLStringWithOptions:(NSXMLNodeCompactEmptyElement | NSXMLNodePrettyPrint)]);
		
		NSString *hash = [self hashCapabilitiesFromQuery:query];
		
		if (hash == nil)
		{
			DDLogWarn(@"XMPPCapabilities: Unable to hash capabilites (in order to send in presense element)");
			DDLogWarn(@"Perhaps there are duplicate advertised features...");
			DDLogWarn(@"%@", [query XMLStringWithOptions:(NSXMLNodeCompactEmptyElement | NSXMLNodePrettyPrint)]);
			
			return;
		}
		
		NSString *hashAlg = @"sha-1";
		
		// Cache the hash
		
		if (![hash isEqual:lastHash])
		{
			[xmppCapabilitiesStorage setCapabilities:query forHash:hash algorithm:hashAlg];
			
			[lastHash release];
			lastHash = [hash copy];
		}
		
		// <c xmlns="http://jabber.org/protocol/caps"
		//     hash="sha-1"
		//     node="http://code.google.com/p/xmppframework"
		//     ver="QgayPKawpkPSDYmwT/WM94uA1u0="/>
		
		NSXMLElement *c = [NSXMLElement elementWithName:@"c" xmlns:@"http://jabber.org/protocol/caps"];
		[c addAttributeWithName:@"hash" stringValue:hashAlg];
		[c addAttributeWithName:@"node" stringValue:DISCO_NODE];
		[c addAttributeWithName:@"ver"  stringValue:hash];
		
		[presence addChild:c];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Timers
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setupTimeoutForDiscoRequestFromJID:(XMPPJID *)jid
{
	// The userInfo for the timer is the jid.
	// 
	// If the timeout occurs, we will remove the jid from the discoRequestJidSet.
	// If we eventually get a response (after the timeout) we will still be able to process it.
	// The timeout simply prevents the set from growing infinitely.
	
	NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:CAPABILITIES_REQUEST_TIMEOUT
	                                                  target:self
	                                                selector:@selector(discoTimeout:)
	                                                userInfo:jid
	                                                 repeats:NO];
	
	// We also keep a reference to the timer in the discoTimerJidDict.
	// This allows us to cancel the timer when we get a response to the disco request.
	
	[discoTimerJidDict setObject:timer forKey:jid];
}

- (void)setupTimeoutForDiscoRequestFromJID:(XMPPJID *)jid withHashKey:(NSString *)key
{
	// The userInfo for the timer is the hash key.
	// That is, the key for the discoRequestHashDict.
	// 
	// If the timeout occurs, we want to send a request to the next jid with the same capabilities hash.
	// This list of jids is stored in the discoRequestHashDict.
	// The key will allow us to fetch the jid list.
		
	NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:CAPABILITIES_REQUEST_TIMEOUT
	                                                  target:self
	                                                selector:@selector(discoTimeout:)
	                                                userInfo:key
	                                                 repeats:NO];
	
	// We also keep a reference to the timer in the discoTimerJidDict.
	// This allows us to cancel the timer when we get a response to the disco request.
	
	[discoTimerJidDict setObject:timer forKey:jid];
}

- (void)cancelTimeoutForDiscoRequestFromJID:(XMPPJID *)jid
{
	NSTimer *timer = [discoTimerJidDict objectForKey:jid];
	
	if (timer)
	{
		[timer invalidate];
		[discoTimerJidDict removeObjectForKey:jid];
	}
}

- (void)processTimeoutWithHashKey:(NSString *)key
{
	// Get the list of jids that have the same capabilities hash
	
	NSMutableArray *jids = [discoRequestHashDict objectForKey:key];
	
	if (jids == nil)
	{
		DDLogWarn(@"%@: %@ - Key doesn't exist in discoRequestHashDict", THIS_FILE, THIS_METHOD);
		
		return;
	}
	
	// Get the previous request index
	NSUInteger requestIndex = [[jids objectAtIndex:0] unsignedIntegerValue];
	
	// Release the associated timer
	[self cancelTimeoutForDiscoRequestFromJID:[jids objectAtIndex:requestIndex]];
	
	// Increment request index (and update object in jids array)
	
	requestIndex++;
	[jids replaceObjectAtIndex:0 withObject:[NSNumber numberWithUnsignedInteger:requestIndex]];
	
	// Do we have another jid that we can query?
	// That is, another jid that was broadcasting the same capabilities hash.
	
	if (requestIndex < [jids count])
	{
		XMPPJID *jid = [jids objectAtIndex:requestIndex];
		
		NSString *node = nil;
		NSString *ver  = nil;
		
		[xmppCapabilitiesStorage getCapabilitiesKnown:nil
		                                       failed:nil
		                                         node:&node
		                                          ver:&ver
		                                          ext:nil
		                                         hash:nil
		                                    algorithm:nil
		                                       forJID:jid];
		
		// <iq to="romeo@montague.lit/orchard" type="get">
		//   <query xmlns="http://jabber.org/protocol/disco#info" node="[node]#[ver]"/>
		// </iq>
		// 
		// Note:
		// Some xmpp clients will return an error if we don't specify the proper query node.
		// Some xmpp clients will return an error if we don't include an id attribute in the iq.
		
		NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"http://jabber.org/protocol/disco#info"];
		
		if (node && ver)
		{
			NSString *nodeValue = [NSString stringWithFormat:@"%@#%@", node, ver];
			
			[query addAttributeWithName:@"node" stringValue:nodeValue];
		}
		
		XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:jid elementID:[xmppStream generateUUID] child:query];
		
		[xmppStream sendElement:iq];
		
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
			XMPPJID *jid = [jids objectAtIndex:i];
			
			[discoRequestJidSet removeObject:jid];
			[xmppCapabilitiesStorage setCapabilitiesFetchFailedForJID:jid];
		}
		
		[discoRequestHashDict removeObjectForKey:key];
	}
}

- (void)processTimeoutWithJID:(XMPPJID *)jid
{
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
	[xmppCapabilitiesStorage setCapabilitiesFetchFailedForJID:jid];
}

- (void)discoTimeout:(NSTimer *)timer
{
	id timerInfo = [timer userInfo];
	
	if ([timerInfo isKindOfClass:[NSString class]])
	{
		NSString *key = (NSString *)timerInfo;
		
		[self processTimeoutWithHashKey:key];
	}
	else if ([timerInfo isKindOfClass:[XMPPJID class]])
	{
		XMPPJID *jid = (XMPPJID *)timerInfo;
		
		[self processTimeoutWithJID:jid];
	}
}

@end
