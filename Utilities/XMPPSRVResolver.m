//
//  XMPPSRVResolver.m
//
//  Originally created by Eric Chamberlain on 6/15/10.
//  Based on SRVResolver by Apple, Inc.
//

#import "XMPPSRVResolver.h"
#import "XMPPLogging.h"

//#warning Fix "dns.h" issue without resorting to this ugly hack.
// This is a hack to prevent OnionKit's clobbering of the actual system's <dns.h>
//#include "/usr/include/dns.h"

#include <dns_util.h>
#include <stdlib.h>

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

NSString *const XMPPSRVResolverErrorDomain = @"XMPPSRVResolverErrorDomain";

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface XMPPSRVRecord ()

@property(nonatomic, assign) NSUInteger srvResultsIndex;
@property(nonatomic, assign) NSUInteger sum;

- (NSComparisonResult)compareByPriority:(XMPPSRVRecord *)aRecord;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPSRVResolver

- (id)initWithdDelegate:(id)aDelegate delegateQueue:(dispatch_queue_t)dq resolverQueue:(dispatch_queue_t)rq
{
	NSParameterAssert(aDelegate != nil);
	NSParameterAssert(dq != NULL);
	
	if ((self = [super init]))
	{
		XMPPLogTrace();
		
		delegate = aDelegate;
		delegateQueue = dq;
		
		#if !OS_OBJECT_USE_OBJC
		dispatch_retain(delegateQueue);
		#endif

		if (rq)
		{
			resolverQueue = rq;
			#if !OS_OBJECT_USE_OBJC
			dispatch_retain(resolverQueue);
			#endif
		}
		else
		{
			resolverQueue = dispatch_queue_create("XMPPSRVResolver", NULL);
		}
		
		resolverQueueTag = &resolverQueueTag;
		dispatch_queue_set_specific(resolverQueue, resolverQueueTag, resolverQueueTag, NULL);
		
		results = [[NSMutableArray alloc] initWithCapacity:2];
	}
	return self;
}

- (void)dealloc
{
	XMPPLogTrace();
	
    [self stop];
	
	#if !OS_OBJECT_USE_OBJC
	if (resolverQueue)
		dispatch_release(resolverQueue);
	#endif
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@dynamic srvName;
@dynamic timeout;

- (NSString *)srvName
{
	__block NSString *result = nil;
	
	dispatch_block_t block = ^{
		result = [srvName copy];
	};
	
	if (dispatch_get_specific(resolverQueueTag))
		block();
	else
		dispatch_sync(resolverQueue, block);
	
	return result;
}

- (NSTimeInterval)timeout
{
	__block NSTimeInterval result = 0.0;
	
	dispatch_block_t block = ^{
		result = timeout;
	};
	
	if (dispatch_get_specific(resolverQueueTag))
		block();
	else
		dispatch_sync(resolverQueue, block);
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Private Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)sortResults
{
	NSAssert(dispatch_get_specific(resolverQueueTag), @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	// Sort results
	NSMutableArray *sortedResults = [NSMutableArray arrayWithCapacity:[results count]];
	
	// Sort the list by priority (lowest number first)
	[results sortUsingSelector:@selector(compareByPriority:)];
	
	/* From RFC 2782
	 * 
	 * For each distinct priority level
	 * While there are still elements left at this priority level
	 * 
	 * Select an element as specified above, in the
	 * description of Weight in "The format of the SRV
	 * RR" Section, and move it to the tail of the new
	 * list.
	 * 
	 * The following algorithm SHOULD be used to order
	 * the SRV RRs of the same priority:
	 */
	
	NSUInteger srvResultsCount;
	
	while ([results count] > 0)
	{
		srvResultsCount = [results count];
		
		if (srvResultsCount == 1)
		{
			XMPPSRVRecord *srvRecord = results[0];
			
			[sortedResults addObject:srvRecord];
			[results removeObjectAtIndex:0];
		}
		else // (srvResultsCount > 1)
		{
			// more than two records so we need to sort
			
			/* To select a target to be contacted next, arrange all SRV RRs
			 * (that have not been ordered yet) in any order, except that all
			 * those with weight 0 are placed at the beginning of the list.
			 * 
			 * Compute the sum of the weights of those RRs, and with each RR
			 * associate the running sum in the selected order.
			 */
			
			NSUInteger runningSum = 0;
			NSMutableArray *samePriorityRecords = [NSMutableArray arrayWithCapacity:srvResultsCount];
			
			XMPPSRVRecord *srvRecord = results[0];
			
			NSUInteger initialPriority = srvRecord.priority;
			NSUInteger index = 0;
			
			do
			{
				if (srvRecord.weight == 0)
				{
					// add to front of array
					[samePriorityRecords insertObject:srvRecord atIndex:0];
					
					srvRecord.srvResultsIndex = index;
					srvRecord.sum = 0;
				}
				else
				{
					// add to end of array and update the running sum
					[samePriorityRecords addObject:srvRecord];
					
					runningSum += srvRecord.weight;
					
					srvRecord.srvResultsIndex = index;
					srvRecord.sum = runningSum;
				}
				
				if (++index < srvResultsCount)
				{
					srvRecord = results[index];
				}
				else
				{
					srvRecord = nil;
				}
				
			} while(srvRecord && (srvRecord.priority == initialPriority));
			
			/* Then choose a uniform random number between 0 and the sum computed
			 * (inclusive), and select the RR whose running sum value is the
			 * first in the selected order which is greater than or equal to
			 * the random number selected.
			 */
			
			NSUInteger randomIndex = arc4random() % (runningSum + 1);
			
			for (srvRecord in samePriorityRecords)
			{
				if (srvRecord.sum >= randomIndex)
				{
					/* The target host specified in the
					 * selected SRV RR is the next one to be contacted by the client.
					 * Remove this SRV RR from the set of the unordered SRV RRs and
					 * apply the described algorithm to the unordered SRV RRs to select
					 * the next target host.  Continue the ordering process until there
					 * are no unordered SRV RRs.  This process is repeated for each
					 * Priority.
					 */
					
					[sortedResults addObject:srvRecord];
					[results removeObjectAtIndex:srvRecord.srvResultsIndex];
					
					break;
				}
			}
		}
	}
	
	results = sortedResults;
	
	XMPPLogVerbose(@"%@: Sorted results:\n%@", THIS_FILE, results);
}

- (void)succeed
{
	NSAssert(dispatch_get_specific(resolverQueueTag), @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	[self sortResults];
	
	id theDelegate = delegate;
	NSArray *records = [results copy];
	
	dispatch_async(delegateQueue, ^{ @autoreleasepool {
		
		SEL selector = @selector(xmppSRVResolver:didResolveRecords:);
		
		if ([theDelegate respondsToSelector:selector])
		{
			[theDelegate xmppSRVResolver:self didResolveRecords:records];
		}
		else
		{
			XMPPLogWarn(@"%@: delegate doesn't implement %@", THIS_FILE, NSStringFromSelector(selector));
		}
		
	}});
	
	[self stop];
}

- (void)failWithError:(NSError *)error
{
	NSAssert(dispatch_get_specific(resolverQueueTag), @"Invoked on incorrect queue");
	
	XMPPLogTrace2(@"%@: %@ %@", THIS_FILE, THIS_METHOD, error);
	
	id theDelegate = delegate;
	
    if (delegateQueue != NULL)
	{
		dispatch_async(delegateQueue, ^{ @autoreleasepool {
			
			SEL selector = @selector(xmppSRVResolver:didNotResolveDueToError:);
			
			if ([theDelegate respondsToSelector:selector])
			{
				[theDelegate xmppSRVResolver:self didNotResolveDueToError:error];
			}
			else
			{
				XMPPLogWarn(@"%@: delegate doesn't implement %@", THIS_FILE, NSStringFromSelector(selector));
			}
			
		}});
	}
	
	[self stop];
}

- (void)failWithDNSError:(DNSServiceErrorType)sdErr
{
	XMPPLogTrace2(@"%@: %@ %i", THIS_FILE, THIS_METHOD, (int)sdErr);
	
	[self failWithError:[NSError errorWithDomain:XMPPSRVResolverErrorDomain code:sdErr userInfo:nil]];
}

- (XMPPSRVRecord *)processRecord:(const void *)rdata length:(uint16_t)rdlen
{
	XMPPLogTrace();
	
	// Note: This method is almost entirely from Apple's sample code.
	// 
	// Otherwise there would be a lot more comments and explanation...
	
	if (rdata == NULL)
	{
		XMPPLogWarn(@"%@: %@ - rdata == NULL", THIS_FILE, THIS_METHOD);
		return nil;
	}
	
	// Rather than write a whole bunch of icky parsing code, I just synthesise
	// a resource record and use <dns_util.h>.
	
	XMPPSRVRecord *result = nil;
	
	NSMutableData *         rrData;
	dns_resource_record_t * rr;
	uint8_t                 u8;   // 1 byte
	uint16_t                u16;  // 2 bytes
	uint32_t                u32;  // 4 bytes
	
	rrData = [NSMutableData dataWithCapacity:(1 + 2 + 2 + 4 + 2 + rdlen)];
	
	u8 = 0;
	[rrData appendBytes:&u8 length:sizeof(u8)];
	u16 = htons(kDNSServiceType_SRV);
	[rrData appendBytes:&u16 length:sizeof(u16)];
	u16 = htons(kDNSServiceClass_IN);
	[rrData appendBytes:&u16 length:sizeof(u16)];
	u32 = htonl(666);
	[rrData appendBytes:&u32 length:sizeof(u32)];
	u16 = htons(rdlen);
	[rrData appendBytes:&u16 length:sizeof(u16)];
	[rrData appendBytes:rdata length:rdlen];
	
	// Parse the record.
	
	rr = dns_parse_resource_record([rrData bytes], (uint32_t) [rrData length]);
    if (rr != NULL)
	{
        NSString *target;
        
        target = [NSString stringWithCString:rr->data.SRV->target encoding:NSASCIIStringEncoding];
        if (target != nil)
		{
			UInt16 priority = rr->data.SRV->priority;
			UInt16 weight   = rr->data.SRV->weight;
			UInt16 port     = rr->data.SRV->port;
			
			result = [XMPPSRVRecord recordWithPriority:priority weight:weight port:port target:target];
        }
		
        dns_free_resource_record(rr);
    }
	
	return result;
}

static void QueryRecordCallback(DNSServiceRef       sdRef,
                                DNSServiceFlags     flags,
                                uint32_t            interfaceIndex,
                                DNSServiceErrorType errorCode,
                                const char *        fullname,
                                uint16_t            rrtype,
                                uint16_t            rrclass,
                                uint16_t            rdlen,
                                const void *        rdata,
                                uint32_t            ttl,
                                void *              context)
{
	// Called when we get a response to our query.  
	// It does some preliminary work, but the bulk of the interesting stuff 
	// is done in the processRecord:length: method.
	
	XMPPSRVResolver *resolver = (__bridge XMPPSRVResolver *)context;
	
	NSCAssert(dispatch_get_specific(resolver->resolverQueueTag), @"Invoked on incorrect queue");
    
	XMPPLogCTrace();
	
	if (!(flags & kDNSServiceFlagsAdd))
	{
		// If the kDNSServiceFlagsAdd flag is not set, the domain information is not valid.
		return;
    }

    if (errorCode == kDNSServiceErr_NoError &&
        rrtype == kDNSServiceType_SRV)
    {
        XMPPSRVRecord *record = [resolver processRecord:rdata length:rdlen];
        if (record)
        {
            [resolver->results addObject:record];
        }

        if ( ! (flags & kDNSServiceFlagsMoreComing) )
        {
            [resolver succeed];
        }    
    }
    else
    {
        [resolver failWithDNSError:errorCode];
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Public Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)startWithSRVName:(NSString *)aSRVName timeout:(NSTimeInterval)aTimeout
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if (resolveInProgress)
		{
			return;
		}
		
		XMPPLogTrace2(@"%@: startWithSRVName:%@ timeout:%f", THIS_FILE, aSRVName, aTimeout);
		
		// Save parameters
		
		srvName = [aSRVName copy];
		
		timeout = aTimeout;
		
		// Check parameters
		
		const char *srvNameCStr = [srvName cStringUsingEncoding:NSASCIIStringEncoding];
		if (srvNameCStr == NULL)
		{
			[self failWithDNSError:kDNSServiceErr_BadParam];
			return;
			
		}
		
		// Create DNS Service
		
		DNSServiceErrorType sdErr;
		sdErr = DNSServiceQueryRecord(&sdRef,                              // Pointer to unitialized DNSServiceRef
		                              kDNSServiceFlagsReturnIntermediates, // Flags
		                              kDNSServiceInterfaceIndexAny,        // Interface index
		                              srvNameCStr,                         // Full domain name
		                              kDNSServiceType_SRV,                 // rrtype
		                              kDNSServiceClass_IN,                 // rrclass
		                              QueryRecordCallback,                 // Callback method
		                              (__bridge void *)self);              // Context pointer
		
		if (sdErr != kDNSServiceErr_NoError)
		{
			[self failWithDNSError:sdErr];
			return;
		}
		
		// Extract unix socket (so we can poll for events)
		
		sdFd = DNSServiceRefSockFD(sdRef);
		if (sdFd < 0)
		{
			// Todo...
		}
		
		// Create GCD read source for sd file descriptor
		
		sdReadSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, sdFd, 0, resolverQueue);
		
		dispatch_source_set_event_handler(sdReadSource, ^{ @autoreleasepool {
			
			XMPPLogVerbose(@"%@: sdReadSource_eventHandler", THIS_FILE);
			
			// There is data to be read on the socket (or an error occurred).
			// 
			// Invoking DNSServiceProcessResult will invoke our QueryRecordCallback,
			// the callback we set when we created the sdRef.
			
			DNSServiceErrorType dnsErr = DNSServiceProcessResult(sdRef);
			if (dnsErr != kDNSServiceErr_NoError)
			{
				[self failWithDNSError:dnsErr];
			}
			
		}});
		
		#if !OS_OBJECT_USE_OBJC
		dispatch_source_t theSdReadSource = sdReadSource;
		#endif
		DNSServiceRef theSdRef = sdRef;
		
		dispatch_source_set_cancel_handler(sdReadSource, ^{ @autoreleasepool {
			
			XMPPLogVerbose(@"%@: sdReadSource_cancelHandler", THIS_FILE);
			
			#if !OS_OBJECT_USE_OBJC
			dispatch_release(theSdReadSource);
			#endif
			DNSServiceRefDeallocate(theSdRef);
			
		}});
		
		dispatch_resume(sdReadSource);
		
		// Create timer (if requested timeout > 0)
		
		if (timeout > 0.0)
		{
			timeoutTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, resolverQueue);
			
			dispatch_source_set_event_handler(timeoutTimer, ^{ @autoreleasepool {
				
				NSString *errMsg = @"Operation timed out";
				NSDictionary *userInfo = @{NSLocalizedDescriptionKey : errMsg};
				
				NSError *err = [NSError errorWithDomain:XMPPSRVResolverErrorDomain code:0 userInfo:userInfo];
				
				[self failWithError:err];
				
			}});
			
			dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (timeout * NSEC_PER_SEC));
			
			dispatch_source_set_timer(timeoutTimer, tt, DISPATCH_TIME_FOREVER, 0);
			dispatch_resume(timeoutTimer);
		}
		
		resolveInProgress = YES;
	}};
	
	if (dispatch_get_specific(resolverQueueTag))
		block();
	else
		dispatch_async(resolverQueue, block);
}

- (void)stop
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		XMPPLogTrace();
		
		delegate = nil;
		if (delegateQueue)
		{
			#if !OS_OBJECT_USE_OBJC
			dispatch_release(delegateQueue);
			#endif
			delegateQueue = NULL;
		}
		
		[results removeAllObjects];
		
		if (sdReadSource)
		{
			// Cancel the readSource.
			// It will be released from within the cancel handler.
			dispatch_source_cancel(sdReadSource);
			sdReadSource = NULL;
			sdFd = -1;
			
			// The sdRef will be deallocated from within the cancel handler too.
			sdRef = NULL;
		}
		
		if (timeoutTimer)
		{
			dispatch_source_cancel(timeoutTimer);
			#if !OS_OBJECT_USE_OBJC
			dispatch_release(timeoutTimer);
			#endif
			timeoutTimer = NULL;
		}
		
		resolveInProgress = NO;
	}};
	
	if (dispatch_get_specific(resolverQueueTag))
		block();
	else
		dispatch_sync(resolverQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utility Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSString *)srvNameFromXMPPDomain:(NSString *)xmppDomain
{
	if (xmppDomain == nil)
		return nil;
	else
		return [NSString stringWithFormat:@"_xmpp-client._tcp.%@", xmppDomain];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPSRVRecord

@synthesize priority;
@synthesize weight;
@synthesize port;
@synthesize target;

@synthesize sum;
@synthesize srvResultsIndex;


+ (XMPPSRVRecord *)recordWithPriority:(UInt16)p1 weight:(UInt16)w port:(UInt16)p2 target:(NSString *)t
{
	return [[XMPPSRVRecord alloc] initWithPriority:p1 weight:w port:p2 target:t];
}

- (id)initWithPriority:(UInt16)p1 weight:(UInt16)w port:(UInt16)p2 target:(NSString *)t
{
	if ((self = [super init]))
	{
		priority = p1;
		weight   = w;
		port     = p2;
		target   = [t copy];
		
		sum = 0;
		srvResultsIndex = 0;
	}
	return self;
}


- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@:%p target(%@) port(%hu) priority(%hu) weight(%hu)>",
			NSStringFromClass([self class]), self, target, port, priority, weight];
}

- (NSComparisonResult)compareByPriority:(XMPPSRVRecord *)aRecord
{
	UInt16 mPriority = self.priority;
	UInt16 aPriority = aRecord.priority;
	
	if (mPriority < aPriority)
		return NSOrderedAscending;
	
	if (mPriority > aPriority)
		return NSOrderedDescending;
	
	return NSOrderedSame;
}

@end
