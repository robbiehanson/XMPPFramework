//
//  RFSRVResolver.m
//  RF Talk
//
//  Created by Eric Chamberlain on 6/15/10.
//  Copyright 2010 RF.com. All rights reserved.
//

#import "RFSRVResolver.h"

#include <dns_util.h>
#include <stdlib.h>

#import "XMPPStream.h"


NSString * kRFSRVResolverErrorDomain = @"kRFSRVResolverErrorDomain";

#define RFSRVRESOLVER_TIMEOUT 30.0

@interface RFSRVRecord ()

@property(nonatomic, assign) NSUInteger srvResultsIndex;
@property(nonatomic, assign) NSUInteger sum;

- (NSComparisonResult)compareByPriority:(RFSRVRecord *)aRecord;

@end


#pragma mark -


@implementation RFSRVRecord

@synthesize priority;
@synthesize weight;
@synthesize port;
@synthesize target;

@synthesize sum;
@synthesize srvResultsIndex;


+ (RFSRVRecord *)recordWithPriority:(UInt16)p1 weight:(UInt16)w port:(UInt16)p2 target:(NSString *)t
{
	return [[[RFSRVRecord alloc] initWithPriority:p1 weight:w port:p2 target:t] autorelease];
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

- (void)dealloc {
  [target release];
  target = nil;
  
  [super dealloc];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@:%p target(%@) port(%hu) priority(%hu) weight(%hu)>",
			NSStringFromClass([self class]), self, target, port, priority, weight];
}

- (NSComparisonResult)compareByPriority:(RFSRVRecord *)aRecord
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

#pragma mark -

@interface RFSRVResolver()

// Redeclare some external properties as read/write
@property (nonatomic, retain, readwrite) XMPPStream *				xmppStream;

@property (nonatomic, assign, readwrite, getter=isFinished) BOOL    finished;
@property (nonatomic, retain, readwrite) NSError *                  error;
@property (nonatomic, retain, readwrite) NSArray *                  results;
@property (nonatomic, retain, readwrite) NSTimer *                  timeoutTimer;

// Forward declarations

- (void)_closeSockets;
- (void)_didTimeoutTimer:(NSTimer *)timer;
- (void)_start;
- (void)_stopWithDNSServiceError:(DNSServiceErrorType)errorCode;
- (void)sortResults;

@end


#pragma mark -


@implementation RFSRVResolver

@synthesize xmppStream      = _xmppStream;
@synthesize delegate        = _delegate;

@synthesize finished        = _finished;
@synthesize error           = _error;
@synthesize results         = _results;
@synthesize timeoutTimer    = _timeoutTimer;

#pragma mark Init methods

+ (RFSRVResolver *)resolveWithStream:(XMPPStream *)aXmppStream 
							delegate:(id)delegate
{
	RFSRVResolver *srvResolver = [[[RFSRVResolver alloc] initWithStream:aXmppStream] autorelease];
	srvResolver.delegate = delegate;
	[srvResolver start];
	return srvResolver;
}

- (id)initWithStream:(XMPPStream *)xmppStream
{
	if (self = [super init]) {
		self.xmppStream = xmppStream;
		self.results = [NSMutableArray arrayWithCapacity:1];
    }
    return self;
}

- (void)dealloc
{
    [self _closeSockets];
    [_error release];
    [_results release];
	[_xmppStream release];
    
    [_timeoutTimer invalidate];
    [_timeoutTimer release];
    
    [super dealloc];
}

#pragma mark Public methods
	 
- (void)start
{
    if (self->_sdRef == NULL) {
	//	NSLog(@"%s",__PRETTY_FUNCTION__);
        self.error    = nil;            // starting up again, so forget any previous error
        self.finished = NO;
        
        self.timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:RFSRVRESOLVER_TIMEOUT
                                                             target:self
                                                           selector:@selector(_didTimeoutTimer:)
                                                           userInfo:nil
                                                            repeats:NO];
        
        [self _start];
	}
}

- (void)stop
{
    [self _closeSockets];
    
    [self.timeoutTimer invalidate];
    self.timeoutTimer = nil;
    
    self.finished = YES;

	[self sortResults];
}

#pragma mark Private Methods

- (void)_closeSockets
{
	if (self->_sdRefSocket != NULL) {
        CFSocketInvalidate(self->_sdRefSocket);
        CFRelease(self->_sdRefSocket);
        self->_sdRefSocket = NULL;
    }
    if (self->_sdRef != NULL) {
        DNSServiceRefDeallocate(self->_sdRef);
        self->_sdRef = NULL;
    }
}

- (void)_didTimeoutTimer:(NSTimer *)timer {
    DDLogTrace();
    [self _stopWithDNSServiceError:kDNSServiceErr_Unknown];
}

- (void)_stopWithError:(NSError *)error
{
    if (error != nil) {
        DDLogError(@"%s %@",__PRETTY_FUNCTION__,error);
    }

    // error may be nil
    self.error = error;
    [self stop];
	 
	 if (error != nil) {
		 if (self.delegate != nil && [self.delegate respondsToSelector:@selector(srvResolver:didNotResolveSRVWithError:)]) {
			 [self.delegate srvResolver:self didNotResolveSRVWithError:error];
		 }
		 
	 } else {
		 if (self.delegate != nil && [self.delegate respondsToSelector:@selector(srvResolverDidResoveSRV:)]) {
			 [self.delegate srvResolverDidResoveSRV:self];
		 }
	 }
}

- (void)_stopWithDNSServiceError:(DNSServiceErrorType)errorCode
{
    NSError *   error;
    
    error = nil;
    if (errorCode != kDNSServiceErr_NoError) {
        error = [NSError errorWithDomain:kRFSRVResolverErrorDomain code:errorCode userInfo:nil];
    }
    [self _stopWithError:error];
}

- (void)_processRecord:(const void *)rdata length:(NSUInteger)rdlen
{
    NSMutableData *         rrData;
    dns_resource_record_t * rr;
    uint8_t                 u8;
    uint16_t                u16;
    uint32_t                u32;
    
    NSAssert(rdata != NULL,@"rdata is NULL");
    NSAssert(rdlen < 65536,@"rdlen is too big");      // rdlen comes from a uint16_t, so can't exceed this.  
	// This also constrains [rrData length] to well less than a uint32_t.
    
    // Rather than write a whole bunch of icky parsing code, I just synthesise 
    // a resource record and use <dns_util.h>.
	
    rrData = [NSMutableData data];
    NSAssert(rrData != nil,@"Can't create rrData");
    
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
    NSAssert(rr != NULL, @"Can't parse dns resource record");
    
    // If the parse is successful, add the results to the array.
    
    if (rr != NULL) {
        NSString *target;
        
        target = [NSString stringWithCString:rr->data.SRV->target encoding:NSASCIIStringEncoding];
        if (target != nil)
		{
			RFSRVRecord * result;
			NSIndexSet  * resultIndexSet;
			
			UInt16 priority = rr->data.SRV->priority;
			UInt16 weight   = rr->data.SRV->weight;
			UInt16 port     = rr->data.SRV->port;
			
			result = [RFSRVRecord recordWithPriority:priority weight:weight port:port target:target];
            
            resultIndexSet = [NSIndexSet indexSetWithIndex:self.results.count];
            NSAssert(resultIndexSet != nil, @"Can't create a result set index");
            
            [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:resultIndexSet forKey:@"results"];
            [_results addObject:result];
            [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:resultIndexSet forKey:@"results"];			
        }
		
        dns_free_resource_record(rr);
    }
}

static void QueryRecordCallback(
								DNSServiceRef       sdRef,
								DNSServiceFlags     flags,
								uint32_t            interfaceIndex,
								DNSServiceErrorType errorCode,
								const char *        fullname,
								uint16_t            rrtype,
								uint16_t            rrclass,
								uint16_t            rdlen,
								const void *        rdata,
								uint32_t            ttl,
								void *              context
								)
// Call (via our CFSocket callback) when we get a response to our query.  
// It does some preliminary work, but the bulk of the interesting stuff 
// is done in the -_processRecord:length: method.
{
    RFSRVResolver *   obj;
    
    DDLogVerbose(@"%s",__PRETTY_FUNCTION__);
	
    obj = (RFSRVResolver *) context;
    
    NSCAssert([obj isKindOfClass:[RFSRVResolver class]],@"obj is not of class RFSRVResolver");
    
#pragma unused(sdRef)
    NSCAssert(sdRef == obj->_sdRef, @"sdRef objects are not the same.");
    
    if (!(flags & kDNSServiceFlagsAdd)) {
        // if the kDNSServiceFlagsAdd flag is not set, the domain information is not valid.
        return;
    }
#pragma unused(interfaceIndex)
    // errorCode looked at below
#pragma unused(fullname)
#pragma unused(rrclass)
    NSCAssert(rrclass == kDNSServiceClass_IN, @"rrclass is not kDNSServiceClass_IN");
    // rdlen and rdata used below
#pragma unused(ttl)
    // context used above
    
    if (errorCode == kDNSServiceErr_NoError && 
        rrtype != kDNSServiceType_SRV) {
        // facebook does a CNAME redirect instead of SRV lookup for _xmpp-client._tcp.chat.facebook.com
        [obj _stopWithError:nil];
    } else if (errorCode == kDNSServiceErr_NoError) {
        [obj _processRecord:rdata length:rdlen];
        if ( ! (flags & kDNSServiceFlagsMoreComing) ) {
            [obj _stopWithError:nil];
        }
    } else {
        [obj _stopWithDNSServiceError:errorCode];
    }
}

static void SDRefSocketCallback(
								CFSocketRef             s, 
								CFSocketCallBackType    type, 
								CFDataRef               address, 
								const void *            data, 
								void *                  info
								)
// A CFSocket callback.  This runs when we get messages from mDNSResponder 
// regarding our DNSServiceRef.  We just turn around and call DNSServiceProcessResult, 
// which does all of the heavy lifting (and would typically call QueryRecordCallback).
{
    DNSServiceErrorType err;
    RFSRVResolver *       obj;
    
    DDLogVerbose(@"%s",__PRETTY_FUNCTION__);
    
    if (type != kCFSocketReadCallBack) {
        // we only care about kCFSocketReadCallBack
        return;
    }

#pragma unused(address)
#pragma unused(data)
    
    obj = (RFSRVResolver *) info;
    NSCAssert([obj isKindOfClass:[RFSRVResolver class]], @"obj is not of class RFSRVResolver");
    
#pragma unused(s)
    NSCAssert(s == obj->_sdRefSocket,@"s is not obj->_sdRefSocket");
    
    err = DNSServiceProcessResult(obj->_sdRef);
    if (err != kDNSServiceErr_NoError) {
        [obj _stopWithDNSServiceError:err];
    }
}

- (void)_start
{
    DNSServiceErrorType err;
    const char *        srvNameCStr;
    int                 fd;
    CFSocketContext     context = { 0, self, NULL, NULL, NULL };
    CFRunLoopSourceRef  rls;
    
    NSAssert(self->_sdRef == NULL, @"_sdRef is not NULL");
    
    // Create the DNSServiceRef to run our query.
    
    err = kDNSServiceErr_NoError;
	
	
	NSString *srvName = [NSString stringWithFormat:@"_xmpp-client._tcp.%@", [[self.xmppStream myJID] domain]];
	
	DDLogVerbose(@"%s Looking up %@...",__PRETTY_FUNCTION__,srvName);	
    
    srvNameCStr = [srvName cStringUsingEncoding:NSASCIIStringEncoding];
    if (srvNameCStr == nil) {
        err = kDNSServiceErr_BadParam;
    }
    if (err == kDNSServiceErr_NoError) {
        err = DNSServiceQueryRecord(
									&self->_sdRef, 
									kDNSServiceFlagsReturnIntermediates,
									kDNSServiceInterfaceIndexAny,                      // interfaceIndex
									srvNameCStr, 
									kDNSServiceType_SRV, 
									kDNSServiceClass_IN, 
									QueryRecordCallback,
									self
									);
    }
	
    // Create a CFSocket to handle incoming messages associated with the 
    // DNSServiceRef.
	
    if (err == kDNSServiceErr_NoError) {
        NSAssert(self->_sdRef != NULL, @"_sdRef is NULL");
        
        fd = DNSServiceRefSockFD(self->_sdRef);
        NSAssert(fd >= 0, @"could not get a file descriptor");
        
        NSAssert(self->_sdRefSocket == NULL, @"_sdRefSocket is not NULL");
        self->_sdRefSocket = CFSocketCreateWithNative(
													  NULL, 
													  fd, 
													  kCFSocketReadCallBack, 
													  SDRefSocketCallback, 
													  &context
													  );
        NSAssert(self->_sdRefSocket != NULL, @"Could not create a socket.");
        
        CFSocketSetSocketFlags(
							   self->_sdRefSocket, 
							   CFSocketGetSocketFlags(self->_sdRefSocket) & ~kCFSocketCloseOnInvalidate
							   );
        
        rls = CFSocketCreateRunLoopSource(NULL, self->_sdRefSocket, 0);
        NSAssert(rls != NULL,@"Could not create a run loop source");
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, kCFRunLoopDefaultMode);
        
        CFRelease(rls);
    }
    if (err != kDNSServiceErr_NoError) {
        [self _stopWithDNSServiceError:err];
    }
}				 

- (void)sortResults
{
    DDLogVerbose(@"%s",__PRETTY_FUNCTION__);
	
    if ([_results count] < 1) {
        DDLogWarn(@"%s no results",__PRETTY_FUNCTION__);
        return;
    }
    
	// Sort results
	NSMutableArray *sortedResults = [NSMutableArray arrayWithCapacity:[_results count]];
	
	// Sort the list by priority (lowest number first)
	[_results sortUsingSelector:@selector(compareByPriority:)];
	
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
	
	while ([_results count] > 0)
	{
		srvResultsCount = [_results count];
		
		if (srvResultsCount == 1)
		{
			RFSRVRecord *srvRecord = [_results objectAtIndex:0];
			
			[sortedResults addObject:srvRecord];
			[_results removeObjectAtIndex:0];
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
			
			RFSRVRecord *srvRecord = [_results objectAtIndex:0];
			
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
					srvRecord = [_results objectAtIndex:index];
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
					[_results removeObjectAtIndex:srvRecord.srvResultsIndex];
					
					break;
				}
			}
		}
	}
	
	self.results = sortedResults;
    DDLogVerbose(@"%s Sorted results: %@",__PRETTY_FUNCTION__, self.results);
}

@end
