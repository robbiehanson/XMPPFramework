//
//  XMPPvCardTempModule.m
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/17/11.
//  Copyright 2011 RF.com. All rights reserved.
//

#import "XMPP.h"
#import "XMPPLogging.h"
#import "XMPPvCardTempModule.h"
#import "XMPPvCardTemp.h"
#import "XMPPIDTracker.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
// Log flags: trace
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

@interface XMPPvCardTempModule()

- (void)_updatevCardTemp:(XMPPvCardTemp *)vCardTemp forJID:(XMPPJID *)jid;
- (void)_fetchvCardTempForJID:(XMPPJID *)jid;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPvCardTempModule

@synthesize xmppvCardTempModuleStorage = _xmppvCardTempModuleStorage;

- (id)init
{
	// This will cause a crash - it's designed to.
	// Only the init methods listed in XMPPvCardTempModule.h are supported.
	
	return [self initWithvCardStorage:nil dispatchQueue:NULL];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	// This will cause a crash - it's designed to.
	// Only the init methods listed in XMPPvCardTempModule.h are supported.
	
	return [self initWithvCardStorage:nil dispatchQueue:NULL];
}

- (id)initWithvCardStorage:(id <XMPPvCardTempModuleStorage>)storage
{
	return [self initWithvCardStorage:storage dispatchQueue:NULL];
}

- (id)initWithvCardStorage:(id <XMPPvCardTempModuleStorage>)storage dispatchQueue:(dispatch_queue_t)queue
{
	NSParameterAssert(storage != nil);
	
	if ((self = [super initWithDispatchQueue:queue]))
	{
		if ([storage configureWithParent:self queue:moduleQueue])
		{
			_xmppvCardTempModuleStorage = storage;
		}
		else
		{
			XMPPLogError(@"%@: %@ - Unable to configure storage!", THIS_FILE, THIS_METHOD);
		}
	}
	return self;
}

- (BOOL)activate:(XMPPStream *)aXmppStream
{
	if ([super activate:aXmppStream])
	{
		// Custom code goes here (if needed)
		
        _myvCardTracker = [[XMPPIDTracker alloc] initWithStream:xmppStream dispatchQueue:moduleQueue];

		return YES;
	}
	
	return NO;
}

- (void)deactivate
{
	// Custom code goes here (if needed)
    
    dispatch_block_t block = ^{ @autoreleasepool {
		
		[_myvCardTracker removeAllIDs];
		_myvCardTracker = nil;
		
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	[super deactivate];
}

- (void)dealloc
{
	_xmppvCardTempModuleStorage = nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Fetch vCardTemp methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)fetchvCardTempForJID:(XMPPJID *)jid
{
	return [self fetchvCardTempForJID:jid ignoreStorage:NO];
}

- (void)fetchvCardTempForJID:(XMPPJID *)jid ignoreStorage:(BOOL)ignoreStorage
{	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		XMPPvCardTemp *vCardTemp = nil;
		
		if (!ignoreStorage)
		{
			// Try loading from storage
			vCardTemp = [_xmppvCardTempModuleStorage vCardTempForJID:jid xmppStream:xmppStream];
		}
		
		if (vCardTemp == nil && [_xmppvCardTempModuleStorage shouldFetchvCardTempForJID:jid xmppStream:xmppStream])
		{
			[self _fetchvCardTempForJID:jid];
		}
		
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (XMPPvCardTemp *)vCardTempForJID:(XMPPJID *)jid shouldFetch:(BOOL)shouldFetch{
    
    __block XMPPvCardTemp *result;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		XMPPvCardTemp *vCardTemp = [_xmppvCardTempModuleStorage vCardTempForJID:jid xmppStream:xmppStream];
		
		if (vCardTemp == nil && shouldFetch && [_xmppvCardTempModuleStorage shouldFetchvCardTempForJID:jid xmppStream:xmppStream])
		{
			[self _fetchvCardTempForJID:jid];
		}
		
		result = vCardTemp;
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

- (XMPPvCardTemp *)myvCardTemp
{
	return [self vCardTempForJID:[xmppStream myJID] shouldFetch:YES];
}

- (void)updateMyvCardTemp:(XMPPvCardTemp *)vCardTemp
{
    
    dispatch_block_t block = ^{ @autoreleasepool {

        XMPPvCardTemp *newvCardTemp = [vCardTemp copy];
        
        XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:nil elementID:[xmppStream generateUUID] child:newvCardTemp];
        [xmppStream sendElement:iq];
        
        [_myvCardTracker addElement:iq
                             target:self
                           selector:@selector(handleMyvcard:withInfo:)
                            timeout:600];
        
        [self _updatevCardTemp:newvCardTemp forJID:[xmppStream myJID]];
        
    }};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Private
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)_updatevCardTemp:(XMPPvCardTemp *)vCardTemp forJID:(XMPPJID *)jid
{
    if(!jid) return;
    
	// this method could be called from anywhere
	dispatch_block_t block = ^{ @autoreleasepool {
		
		XMPPLogVerbose(@"%@: %s %@", THIS_FILE, __PRETTY_FUNCTION__, [jid bare]);
		
		[_xmppvCardTempModuleStorage setvCardTemp:vCardTemp forJID:jid xmppStream:xmppStream];
		
		[(id <XMPPvCardTempModuleDelegate>)multicastDelegate xmppvCardTempModule:self
		                                                     didReceivevCardTemp:vCardTemp
		                                                                  forJID:jid];
	}};
	
	if (dispatch_get_specific(moduleQueueTag))
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)_fetchvCardTempForJID:(XMPPJID *)jid{
    if(!jid) return;
    

    XMPPIQ *iq = [XMPPvCardTemp iqvCardRequestForJID:jid];
    
    [_myvCardTracker addElement:iq
                         target:self
                       selector:@selector(handleFetchvCard:withInfo:)
                        timeout:600];
    
    [xmppStream sendElement:iq];
}

- (void)handleMyvcard:(XMPPIQ *)iq withInfo:(XMPPBasicTrackingInfo *)trackerInfo{

    if([iq isResultIQ])
    {
        [(id <XMPPvCardTempModuleDelegate>)multicastDelegate xmppvCardTempModuleDidUpdateMyvCard:self];
    }
    else if([iq isErrorIQ])
    {
        NSXMLElement *errorElement = [iq elementForName:@"error"];
        [(id <XMPPvCardTempModuleDelegate>)multicastDelegate xmppvCardTempModule:self failedToUpdateMyvCard:errorElement];
    }
}

- (void)handleFetchvCard:(XMPPIQ*)iq withInfo:(XMPPBasicTrackingInfo*)trackerInfo {
    XMPPJID *jid = trackerInfo.element.to;
    // If JID was omitted from request, you were fetching your own vCard
    if (!jid) {
        jid = xmppStream.myJID;
    }
    if([iq isErrorIQ])
    {
        NSXMLElement *errorElement = [iq elementForName:@"error"];
        [(id <XMPPvCardTempModuleDelegate>)multicastDelegate xmppvCardTempModule:self failedToFetchvCardForJID:jid error:errorElement];
    } else if([iq isResultIQ]) {
        NSXMLElement *vCard = [[iq elementForName:@"vCard"] copy];
        if (vCard.childCount == 0) {
            [(id <XMPPvCardTempModuleDelegate>)multicastDelegate xmppvCardTempModule:self failedToFetchvCardForJID:jid error:nil];
        } else if (![iq from]) {
            // If there's no fromJID, it means the vCard was already within didReceiveIQ, and this is
            // the vCard for yourself
            XMPPvCardTemp *vCardTemp = [XMPPvCardTemp vCardTempFromElement:vCard];
            [self _updatevCardTemp:vCardTemp forJID:jid];
        }
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStreamDelegate methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	// This method is invoked on the moduleQueue.
	
    if (!iq.from) {
        // Some error responses for self or contacts don't have a "from"
        [_myvCardTracker invokeForID:iq.elementID withObject:iq];
    } else {
        [_myvCardTracker invokeForElement:iq withObject:iq];
    }
    
	// Remember XML heirarchy memory management rules.
	// The passed parameter is a subnode of the IQ, and we need to pass it to an asynchronous operation.
	// 
	// Therefore we use vCardTempCopyFromIQ instead of vCardTempSubElementFromIQ.
	
    
	XMPPvCardTemp *vCardTemp = [XMPPvCardTemp vCardTempCopyFromIQ:iq];
	if (vCardTemp != nil)
	{
		[self _updatevCardTemp:vCardTemp forJID:[iq from]];
		
		return YES;
	}
	
	return NO;
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
	[_myvCardTracker removeAllIDs];
}

@end
