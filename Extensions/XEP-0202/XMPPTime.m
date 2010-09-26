#import "XMPPTime.h"
#import "XMPP.h"
#import "XMPPDateTimeProfiles.h"

#define INTEGRATE_WITH_CAPABILITIES 1

#if INTEGRATE_WITH_CAPABILITIES
  #import "XMPPCapabilities.h"
#endif

#define DEFAULT_TIMEOUT  30.0 // seconds


@implementation XMPPTime

- (id)initWithStream:(XMPPStream *)aXmppStream
{
	if ((self = [super initWithStream:aXmppStream]))
	{
		queryIDs = [[NSMutableDictionary alloc] initWithCapacity:5];
		
		#if INTEGRATE_WITH_CAPABILITIES
		
			[xmppStream autoAddDelegate:self toModulesOfClass:[XMPPCapabilities class]];
		
		#endif
	}
	return self;
}

- (void)dealloc
{
	#if INTEGRATE_WITH_CAPABILITIES
	
		[xmppStream removeAutoDelegate:self fromModulesOfClass:[XMPPCapabilities class]];
	
	#endif
	
	[queryIDs release];
	
	[super dealloc];
}

- (NSString *)generateQueryIDWithTimeout:(NSTimeInterval)timeout
{
	// Generate unique ID for query.
	// It's important the ID be unique as the ID is the
	// only thing that distinguishes multiple queries from each other.
	
	NSString *queryID = [xmppStream generateUUID];
	
	// Add query ID to list so we'll recognize it when we get a response
	[queryIDs setObject:[NSNumber numberWithDouble:timeout] forKey:queryID];
	
	// In case we never get a response, we want to remove the query ID eventually,
	// or we risk an ever increasing queryIDs array.
	[NSTimer scheduledTimerWithTimeInterval:timeout
									 target:self
								   selector:@selector(removeQueryID:)
								   userInfo:queryID
									repeats:NO];
	
	return queryID;
}

- (void)removeQueryID:(NSTimer *)aTimer
{
	NSString *queryID = (NSString *)[aTimer userInfo];
	
	NSNumber *timeoutNum = [[queryIDs objectForKey:queryID] retain];
	if (timeoutNum)
	{
		[queryIDs removeObjectForKey:queryID];
		
		[multicastDelegate xmppTime:self didNotReceiveResponse:queryID dueToTimeout:[timeoutNum doubleValue]];
		
		[timeoutNum release];
	}
}

- (NSString *)sendQueryToServer
{
	return [self sendQueryToServerWithTimeout:DEFAULT_TIMEOUT];
}

- (NSString *)sendQueryToServerWithTimeout:(NSTimeInterval)timeout
{
	NSString *queryID = [self generateQueryIDWithTimeout:timeout];
	
	// Send ping packet
	// 
	// <iq type="get" id="queryID">
	//   <time xmlns="urn:xmpp:time"/>
	// </iq>
	
	NSXMLElement *time = [NSXMLElement elementWithName:@"time" xmlns:@"urn:xmpp:time"];
	
	XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:nil elementID:queryID child:time];
	
	[xmppStream sendElement:iq];
	
	return queryID;
}

- (NSString *)sendQueryToJID:(XMPPJID *)jid
{
	return [self sendQueryToJID:jid withTimeout:DEFAULT_TIMEOUT];
}

- (NSString *)sendQueryToJID:(XMPPJID *)jid withTimeout:(NSTimeInterval)timeout
{
	NSString *queryID = [self generateQueryIDWithTimeout:timeout];
	
	// Send ping element
	// 
	// <iq type="get" to="fullJID" id="abc123">
	//   <time xmlns="urn:xmpp:time"/>
	// </iq>
	
	NSXMLElement *time = [NSXMLElement elementWithName:@"time" xmlns:@"urn:xmpp:time"];
	
	XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:jid elementID:queryID child:time];
	
	[xmppStream sendElement:iq];
	
	return queryID;
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	NSString *type = [[iq attributeForName:@"type"] stringValue];
	
	if ([type isEqualToString:@"result"] || [type isEqualToString:@"error"])
	{
		// Examples:
		// 
		// <iq type="result" from="robbie@voalte.com/office" to="robbie@deusty.com/home" id="abc123">
		//   <time xmlns="urn:xmpp:time">
		//     <tzo>-06:00</tzo>
		//     <utc>2006-12-19T17:58:35Z</utc>
		//   </time>
		// </iq>
		// 
		// <iq type="error" from="robbie@voalte.com/office" to="robbie@deusty.com/home" id="abc123">
		//   <time xmlns="urn:xmpp:time"/>
		//   <error code="501" type="cancel">
		//     <feature-not-implemented xmlns="urn:ietf:params:xml:ns:xmpp-stanzas"/>
		//   </error>
		// </iq>
		
		NSString *queryID = [iq elementID];
		
		NSNumber *timeoutNum = [[queryIDs objectForKey:queryID] retain];
		if (timeoutNum)
		{
			[queryIDs removeObjectForKey:queryID];
			
			[multicastDelegate xmppTime:self didReceiveResponse:iq];
			
			[timeoutNum release];
		}
	}
	else if ([type isEqualToString:@"get"])
	{
		// Example:
		// 
		// <iq type="get" from="robbie@deusty.com/home" to="robbie@voalte.com/office" id="abc123">
		//   <time xmlns="urn:xmpp:time"/>
		// </iq>
		
		NSXMLElement *time = [iq elementForName:@"time" xmlns:@"urn:xmpp:time"];
		if (time)
		{
			NSXMLElement *time = [[self class] timeElement];
			
			XMPPIQ *response = [XMPPIQ iqWithType:@"result" to:[iq from] elementID:[iq elementID]];
			[response addChild:time];
			
			[sender sendElement:response];
			
			return YES;
		}
	}
	
	return NO;
}

#if INTEGRATE_WITH_CAPABILITIES
/**
 * If an XMPPCapabilites instance is used we want to advertise our support for XEP-0202.
**/
- (void)xmppCapabilities:(XMPPCapabilities *)sender willSendMyCapabilities:(NSXMLElement *)query
{
	// <query xmlns="http://jabber.org/protocol/disco#info">
	//   ...
	//   <feature var="urn:xmpp:time"/>
	//   ...
	// </query>
	
	NSXMLElement *feature = [NSXMLElement elementWithName:@"feature"];
	[feature addAttributeWithName:@"var" stringValue:@"urn:xmpp:time"];
	
	[query addChild:feature];
}
#endif

+ (NSDate *)dateFromResponse:(XMPPIQ *)iq
{
	// <iq type="result" from="robbie@voalte.com/office" to="robbie@deusty.com/home" id="abc123">
	//   <time xmlns="urn:xmpp:time">
	//     <tzo>-06:00</tzo>
	//     <utc>2006-12-19T17:58:35Z</utc>
	//   </time>
	// </iq>
	
	NSXMLElement *time = [iq elementForName:@"time" xmlns:@"urn:xmpp:time"];
	if (time == nil) return nil;
	
	NSString *utc = [[time elementForName:@"utc"] stringValue];
	if (utc == nil) return nil;
	
	NSDate *utcDateInLocalTZO = [XMPPDateTimeProfiles parseDateTime:utc];
	
	// Since the date was given in UTC, we need to add/subtract the difference.
	
	NSTimeInterval localTZO = [[NSTimeZone systemTimeZone] secondsFromGMT];
	
	return [utcDateInLocalTZO dateByAddingTimeInterval:localTZO];
}

+ (NSTimeInterval)timeZoneOffsetFromResponse:(XMPPIQ *)iq
{
	// <iq type="result" from="robbie@voalte.com/office" to="robbie@deusty.com/home" id="abc123">
	//   <time xmlns="urn:xmpp:time">
	//     <tzo>-06:00</tzo>
	//     <utc>2006-12-19T17:58:35Z</utc>
	//   </time>
	// </iq>
	
	NSXMLElement *time = [iq elementForName:@"time" xmlns:@"urn:xmpp:time"];
	if (time == nil) return 0;
	
	NSString *tzo = [[time elementForName:@"tzo"] stringValue];
	if (tzo == nil) return 0;
	
	return [XMPPDateTimeProfiles parseTimeZoneOffset:tzo];
}

+ (NSXMLElement *)timeElement
{
	return [self timeElementFromDate:[NSDate date]];
}

+ (NSXMLElement *)timeElementFromDate:(NSDate *)date
{
	// <time xmlns="urn:xmpp:time">
	//   <tzo>-06:00</tzo>
	//   <utc>2006-12-19T17:58:35Z</utc>
	// </time>
	
	NSDateFormatter *df = [[NSDateFormatter alloc] init];
	[df setFormatterBehavior:NSDateFormatterBehavior10_4]; // Use unicode patterns (as opposed to 10_3)
	[df setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
	
	NSString *utcValue = [df stringFromDate:date];
	
	[df release];
	
	NSInteger tzoInSeconds = [[NSTimeZone systemTimeZone] secondsFromGMTForDate:date];
	
	NSInteger tzoH = tzoInSeconds / (60 * 60);
	NSInteger tzoS = tzoInSeconds % (60 * 60);
	
	NSString *tzoValue = [NSString stringWithFormat:@"%+03li:%02li", (long)tzoH, (long)tzoS];
	
	NSXMLElement *tzo = [NSXMLElement elementWithName:@"tzo" stringValue:tzoValue];
	NSXMLElement *utc = [NSXMLElement elementWithName:@"utc" stringValue:utcValue];
	
	NSXMLElement *time = [NSXMLElement elementWithName:@"time" xmlns:@"urn:xmpp:time"];
	[time addChild:tzo];
	[time addChild:utc];
	
	return time;
}

@end
