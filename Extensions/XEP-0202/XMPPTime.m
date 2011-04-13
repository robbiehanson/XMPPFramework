#import "XMPPTime.h"
#import "XMPP.h"
#import "XMPPDateTimeProfiles.h"

#define INTEGRATE_WITH_CAPABILITIES 1

#if INTEGRATE_WITH_CAPABILITIES
  #import "XMPPCapabilities.h"
#endif

#define DEFAULT_TIMEOUT  30.0 // seconds

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface XMPPTimeQueryInfo : NSObject
{
	NSDate *timeSent;
	NSTimeInterval timeout;
}

+ (XMPPTimeQueryInfo *)queryInfoWithTimeout:(NSTimeInterval)timeout;

@property (nonatomic, readonly) NSDate *timeSent;
@property (nonatomic, readonly) NSTimeInterval timeout;

- (NSTimeInterval)rtt;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPTime

- (id)initWithStream:(XMPPStream *)aXmppStream
{
	return [self initWithStream:aXmppStream respondsToQueries:YES];
}

- (id)initWithStream:(XMPPStream *)aXmppStream respondsToQueries:(BOOL)flag;
{
	if ((self = [super initWithStream:aXmppStream]))
	{
		respondsToQueries = flag;
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
	[queryIDs setObject:[XMPPTimeQueryInfo queryInfoWithTimeout:timeout]
	             forKey:queryID];
	
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
	
	XMPPTimeQueryInfo *queryInfo = [queryIDs objectForKey:queryID];
	if (queryInfo)
	{
		[queryInfo retain];
		[queryIDs removeObjectForKey:queryID];
		
		[multicastDelegate xmppTime:self didNotReceiveResponse:queryID dueToTimeout:[queryInfo timeout]];
		
		[queryInfo release];
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
	// <iq type="get" to="domain" id="queryID">
	//   <time xmlns="urn:xmpp:time"/>
	// </iq>
	// 
	// Note: Sometimes the to attribute is required. (ejabberd)
	
	NSXMLElement *time = [NSXMLElement elementWithName:@"time" xmlns:@"urn:xmpp:time"];
	XMPPJID *domainJID = [[xmppStream myJID] domainJID];
	
	XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:domainJID elementID:queryID child:time];
	
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
	NSString *type = [iq type];
	
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
		
		XMPPTimeQueryInfo *queryInfo = [queryIDs objectForKey:queryID];
		if (queryInfo)
		{
			[queryInfo retain];
			[queryIDs removeObjectForKey:queryID];
			
			[multicastDelegate xmppTime:self didReceiveResponse:iq withRTT:[queryInfo rtt]];
			
			[queryInfo release];
		}
	}
	else if (respondsToQueries && [type isEqualToString:@"get"])
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
	if (respondsToQueries)
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
	
	// Note:
	// 
	// NSDate is a very simple class, but can be confusing at times.
	// NSDate simply stores an NSTimeInterval internally,
	// which is just a double representing the number seconds since the reference date.
	// Since it's a double, it can yield sub-millisecond precision.
	// 
	// In addition to this, it stores the values in UTC.
	// However, if you print the value using NSLog via "%@",
	// it will automatically print the date in the local timezone:
	// 
	// NSDate *refDate = [NSDate dateWithTimeIntervalSinceReferenceDate:0.0];
	// 
	// NSLog(@"%f", [refDate timeIntervalSinceReferenceDate]);  // Prints: 0.0
	// NSLog(@"%@", refDate);                                   // Prints: 2000-12-31 19:00:00 -05:00
	// NSLog(@"%@", [utcDateFormatter stringFromDate:refDate]); // Prints: 2001-01-01 00:00:00 +00:00
	// 
	// Now the value we've received from XMPPDateTimeProfiles is correct.
	// If we print it out using a utcDateFormatter we would see it is correct.
	// If we printed it out generically using NSLog, then we would see it converted into our local time zone.
	
	return [XMPPDateTimeProfiles parseDateTime:utc];
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

+ (NSTimeInterval)approximateTimeDifferenceFromResponse:(XMPPIQ *)iq andRTT:(NSTimeInterval)rtt
{
	// First things first, get the current date and time
	
	NSDate *localDate = [NSDate date];
	
	// Then worry about the calculations
	
	NSXMLElement *time = [iq elementForName:@"time" xmlns:@"urn:xmpp:time"];
	if (time == nil) return 0.0;
	
	NSString *utc = [[time elementForName:@"utc"] stringValue];
	if (utc == nil) return 0.0;
	
	NSDate *remoteDate = [XMPPDateTimeProfiles parseDateTime:utc];
	if (remoteDate == nil) return 0.0;
	
	NSTimeInterval localTI  = [localDate timeIntervalSinceReferenceDate];
	NSTimeInterval remoteTI = [remoteDate timeIntervalSinceReferenceDate] - (rtt / 2.0);
	
	// Did the response contain millisecond precision?
	// This is an important consideration.
	// Imagine if both computers are perfectly synced,
	// but the remote response doesn't contain milliseconds.
	// This could possibly cause us to think the difference is close to a full second.
	// 
	// DateTime examples (from XMPPDateTimeProfiles documentation):
	// 
	// 1969-07-21T02:56:15
	// 1969-07-21T02:56:15Z
	// 1969-07-20T21:56:15-05:00
	// 1969-07-21T02:56:15.123
	// 1969-07-21T02:56:15.123Z
	// 1969-07-20T21:56:15.123-05:00
	
	BOOL hasMilliseconds = ([utc length] > 19) && ([utc characterAtIndex:19] == '.');
	
	if (hasMilliseconds)
	{
		return remoteTI - localTI;
	}
	else
	{
		// No milliseconds. What to do?
		// 
		// We could simply truncate the milliseconds from our time...
		// But this could make things much worse.
		// For example:
		// 
		// local  = 14:22:36.750
		// remote = 14:22:37
		// 
		// If we truncate the result now we calculate a diff of 1.000 (a full second).
		// Considering the remote's milliseconds could have been anything from 000 to 999,
		// this means our calculations are:
		// 
		// perfect        :  0.1% chance
		// diff too big   : 75.0% chance
		// diff too small : 24.9% chance
		// 
		// Perhaps a better solution would give us a more even spread.
		// We can do this by calculating the range:
		// 
		// 37.000 - 36.750 = 0.25
		// 37.999 - 36.750 = 1.249
		// 
		// So a better guess of the diff is 0.750 (3/4 of a second):
		// 
		// perfect        :  0.1% chance
		// diff too big   : 50.0% chance
		// diff too small : 49.9% chance
		
		NSTimeInterval diff1 = localTI - (remoteTI + 0.000);
		NSTimeInterval diff2 = localTI - (remoteTI + 0.999);
		
		return ((diff1 + diff2) / 2.0);
	}
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
	[df setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
	
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPTimeQueryInfo

@synthesize timeSent;
@synthesize timeout;

- (id)initWithTimeout:(NSTimeInterval)to
{
	if ((self = [super init]))
	{
		timeSent = [[NSDate alloc] init];
		timeout = to;
	}
	return self;
}

- (void)dealloc
{
	[timeSent release];
	[super dealloc];
}

- (NSTimeInterval)rtt
{
	return [timeSent timeIntervalSinceNow] * -1.0;
}

+ (XMPPTimeQueryInfo *)queryInfoWithTimeout:(NSTimeInterval)timeout
{
	return [[[XMPPTimeQueryInfo alloc] initWithTimeout:timeout] autorelease];
}

@end
