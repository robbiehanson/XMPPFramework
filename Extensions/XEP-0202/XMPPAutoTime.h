#import "XMPP.h"
#import "XMPPTime.h"

#define _XMPP_AUTO_TIME_H

@class XMPPJID;

/**
 * The XMPPAutoTime module monitors the time difference between our machine and the target.
 * The target may simply be the server, or a specific resource.
 * 
 * The module works by sending time queries to the target, and tracking the responses.
 * The module will automatically send multiple queuries, and take into account the average RTT.
 * It will also automatically update itself on a customizable interval, and whenever the machine's clock changes.
 * 
 * This module is helpful when you are using timestamps from the target.
 * For example, you may be receiving offline messages from your server.
 * However, all these offline messages are timestamped from the server's clock.
 * And the current machine's clock may vary considerably from the server's clock.
 * Timezone differences don't matter as UTC is always used in XMPP, but clocks can easily differ.
 * This may cause the user some confusion as server timestamps may reflect a time in the future,
 * or much longer ago than in reality.
**/
@interface XMPPAutoTime : XMPPModule
{
	NSTimeInterval recalibrationInterval;
	XMPPJID *targetJID;
	NSTimeInterval timeDifference;
	
	dispatch_time_t lastCalibrationTime;
	dispatch_source_t recalibrationTimer;
	
	BOOL awaitingQueryResponse;
	XMPPTime *xmppTime;
	
	NSData *lastServerAddress;
	
	NSDate *systemUptimeChecked;
	NSTimeInterval systemUptime;
}

/**
 * How often to recalibrate the time difference.
 * 
 * The module will automatically calculate the time difference when it is activated,
 * or when it first sees the xmppStream become authenticated (whichever occurs first).
 * After that first calculation, it will update itself according to this interval.
 * 
 * To temporarily disable recalibration, set the interval to zero.
 * 
 * The default recalibrationInterval is 24 hours.
**/
@property (readwrite) NSTimeInterval recalibrationInterval;

/**
 * The target to query.
 * 
 * If the targetJID is nil, this implies the target is the xmpp server we're connected to.
 * If the targetJID is non-nil, it must be a full JID (user@domain.tld/rsrc).
 * 
 * The default targetJID is nil.
**/
@property (readwrite, strong) XMPPJID *targetJID;

/**
 * Returns the calculated time difference between our machine and the target.
 * 
 * This is NOT a reference to the difference in time zones.
 * Time zone differences generally shouldn't matter as xmpp standards mandate the use of UTC.
 * 
 * Rather this is the difference between our UTC time, and the remote party's UTC time.
 * If the two clocks are not synchronized, then the result represents the approximate difference.
 * 
 * If our clock is earlier than the remote clock, then the value will be negative.
 * If our clock is ahead of the remote clock, then the value will be positive.
 * 
 * If you later receive a timestamp from the remote party, you can simply add the diff.
 * For example:
 * 
 * myTime = [givenTimeFromRemoteParty dateByAddingTimeInterval:diff];
**/
@property (readonly) NSTimeInterval timeDifference;

/**
 * Returns the date of the target based on the time difference.
**/
@property (readonly) NSDate *date;

/**
 * The last time we've completed a calibration.
**/
@property (readonly) dispatch_time_t lastCalibrationTime;

/**
 * XMPPAutoTime is used to automatically query a target for its time (and calculate the difference).
 * Sometimes the target is also sending time requests to us as well.
 * If so, you may optionally set respondsToQueries to YES to allow the module to respond to incoming time queries.
 * 
 * If you create multiple instances of XMPPAutoTime or XMPPTime,
 * then only one instance should respond to queries. 
 * 
 * The default value is NO.
**/
@property (readwrite) BOOL respondsToQueries;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPAutoTimeDelegate
@optional

- (void)xmppAutoTime:(XMPPAutoTime *)sender didUpdateTimeDifference:(NSTimeInterval)timeDifference;

@end

@interface XMPPStream (XMPPAutoTime)

- (NSTimeInterval)xmppAutoTime_timeDifferenceForTargetJID:(XMPPJID *)targetJID;
- (NSDate *)xmppAutoTime_dateForTargetJID:(XMPPJID *)targetJID;

@end
