#import <Foundation/Foundation.h>
#import "XMPPModule.h"

#if TARGET_OS_IPHONE
  #import "DDXML.h"
#endif

@class XMPPJID;
@class XMPPStream;
@class XMPPIQ;
@protocol XMPPTimeDelegate;


@interface XMPPTime : XMPPModule
{
	NSMutableDictionary *queryIDs;
}

- (id)initWithStream:(XMPPStream *)xmppStream;

/**
 * Send query to the server or a specific JID.
 * The disco module may be used to detect if the target supports this XEP.
 * 
 * The returned string is the queryID (the elementID of the query that was sent).
 * In other words:
 * 
 * SEND: <iq id="<returned_string>" type="get" .../>
 * RECV: <iq id="<returned_string>" type="result" .../>
 * 
 * This may be helpful if you are sending multiple simultaneous queries to the same target.
**/
- (NSString *)sendQueryToServer;
- (NSString *)sendQueryToServerWithTimeout:(NSTimeInterval)timeout;
- (NSString *)sendQueryToJID:(XMPPJID *)jid;
- (NSString *)sendQueryToJID:(XMPPJID *)jid withTimeout:(NSTimeInterval)timeout;

/**
 * Extracts the utc date from the given response/time element,
 * and returns an NSDate representation of the time in the local time zone.
 * Since the returned date is in the local time zone, it is suitable for presentation.
**/
+ (NSDate *)dateFromResponse:(XMPPIQ *)iq;

/**
 * Extracts the time zone offset from the given response/time element.
 * The time zone offset is given as an NSTimeInterval, reprsenting the number of seconds from GMT.
**/
+ (NSTimeInterval)timeZoneOffsetFromResponse:(XMPPIQ *)iq;

/**
 * Creates and returns a time element.
**/
+ (NSXMLElement *)timeElement;
+ (NSXMLElement *)timeElementFromDate:(NSDate *)date;

@end

@protocol XMPPTimeDelegate
@optional

- (void)xmppTime:(XMPPTime *)sender didReceiveResponse:(XMPPIQ *)iq withRTT:(NSTimeInterval)rtt;
- (void)xmppTime:(XMPPTime *)sender didNotReceiveResponse:(NSString *)queryID dueToTimeout:(NSTimeInterval)timeout;

@end
