#import "XMPPBandwidthMonitor.h"
#import "XMPPLogging.h"
#import "NSXMLElement+XMPP.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_VERBOSE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif


@implementation XMPPBandwidthMonitor
{
	dispatch_source_t timer;
	
	uint64_t lastNumberOfBytesSent;
	uint64_t lastNumberOfBytesReceived;
	
	double smoothedAverageOutgoingBandwidth;
	double smoothedAverageIncomingBandwidth;
}

- (double)outgoingBandwidth
{
	__block double result = 0.0;
	
	dispatch_block_t block = ^{
		result = smoothedAverageOutgoingBandwidth;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

- (double)incomingBandwidth
{
	__block double result = 0.0;
	
	dispatch_block_t block = ^{
		result = smoothedAverageIncomingBandwidth;
	};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

- (void)updateBandwidth
{
	uint64_t currentNumberOfBytesSent = 0;
	uint64_t currentNumberOfBytesReceived = 0;
	
	[xmppStream getNumberOfBytesSent:&currentNumberOfBytesSent numberOfBytesReceived:&currentNumberOfBytesReceived];
	
	double currentOutgoingBandwidth = currentNumberOfBytesSent - lastNumberOfBytesSent;         // Bytes per second
	double currentIncomingBandwidth = currentNumberOfBytesReceived - lastNumberOfBytesReceived; // Bytes per second
	
	if (smoothedAverageOutgoingBandwidth || smoothedAverageIncomingBandwidth)
	{
		// Apply Brown's Simple Exponential Smoothing algorithm
		
		double smoothingFactor = 0.3;
		
		smoothedAverageOutgoingBandwidth =   (smoothingFactor * currentOutgoingBandwidth)
		                                   + ((1 - smoothingFactor) * smoothedAverageOutgoingBandwidth);
		
		smoothedAverageIncomingBandwidth =   (smoothingFactor * currentIncomingBandwidth)
		                                   + ((1 - smoothingFactor) * smoothedAverageIncomingBandwidth);
	}
	else
	{
		// No previous data
		
		smoothedAverageOutgoingBandwidth = currentOutgoingBandwidth;
		smoothedAverageIncomingBandwidth = currentIncomingBandwidth;
	}
	
	lastNumberOfBytesSent = currentNumberOfBytesSent;
	lastNumberOfBytesReceived = currentNumberOfBytesReceived;
	
	XMPPLogVerbose(@"Bandwidth = Out(%.0f, %.0f) In(%.0f, %.0f)",
	             currentOutgoingBandwidth, smoothedAverageOutgoingBandwidth,
	             currentIncomingBandwidth, smoothedAverageIncomingBandwidth);
}

- (void)startTimer
{
	if (timer == NULL)
	{
		uint64_t numberOfBytesSent = 0;
		uint64_t numberOfBytesReceived = 0;
		
		[xmppStream getNumberOfBytesSent:&numberOfBytesSent numberOfBytesReceived:&numberOfBytesReceived];
		
		lastNumberOfBytesSent = numberOfBytesSent;
		lastNumberOfBytesReceived = numberOfBytesReceived;
		
		smoothedAverageOutgoingBandwidth = 0.0;
		smoothedAverageIncomingBandwidth = 0.0;
		
		timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, moduleQueue);
		
		dispatch_source_set_event_handler(timer, ^{ @autoreleasepool {
			
			[self updateBandwidth];
			
		}});
		
		NSTimeInterval interval = 1.0; // Update every 1 second(s)
		
		uint64_t intervalTime = interval * NSEC_PER_SEC;
		dispatch_time_t startTime = dispatch_time(DISPATCH_TIME_NOW, intervalTime);
		
		dispatch_source_set_timer(timer, startTime, intervalTime, 0.25);
		dispatch_resume(timer);
	}
}

- (void)stopTimer
{
	if (timer)
	{
		lastNumberOfBytesSent = 0;
		lastNumberOfBytesReceived = 0;
		
		smoothedAverageOutgoingBandwidth = 0.0;
		smoothedAverageIncomingBandwidth = 0.0;
		
		dispatch_source_cancel(timer);
		#if !OS_OBJECT_USE_OBJC
		dispatch_release(timer);
		#endif
		timer = NULL;
	}
}

- (BOOL)activate:(XMPPStream *)aXmppStream
{
	if ([super activate:aXmppStream])
	{
		if ([xmppStream isConnected])
		{
			[self startTimer];
		}
		return YES;
	}
	
	return NO;
}

- (void)deactivate
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		[self stopTimer];
		[super deactivate];
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidStartNegotiation:(XMPPStream *)sender;
{
	[self startTimer];
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
	[self stopTimer];
}

@end
