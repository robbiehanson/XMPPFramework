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

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPvCardTempModule

@synthesize moduleStorage = _moduleStorage;

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
			_moduleStorage = storage;
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
		
        myvCardTracker = [[XMPPIDTracker alloc] initWithDispatchQueue:moduleQueue];

		return YES;
	}
	
	return NO;
}

- (void)deactivate
{
	// Custom code goes here (if needed)
    
    dispatch_block_t block = ^{ @autoreleasepool {
		
		[myvCardTracker removeAllIDs];
		myvCardTracker = nil;
		
	}};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	[super deactivate];
}

- (void)dealloc
{
	_moduleStorage = nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Fetch vCardTemp methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (XMPPvCardTemp *)fetchvCardTempForJID:(XMPPJID *)jid
{
	return [self fetchvCardTempForJID:jid useCache:YES];
}

- (XMPPvCardTemp *)fetchvCardTempForJID:(XMPPJID *)jid useCache:(BOOL)useCache
{
	__block XMPPvCardTemp *result;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		XMPPvCardTemp *vCardTemp = nil;
		
		if (useCache)
		{
			// Try loading from the cache
			vCardTemp = [_moduleStorage vCardTempForJID:jid xmppStream:xmppStream];
		}
		
		if (vCardTemp == nil && [_moduleStorage shouldFetchvCardTempForJID:jid xmppStream:xmppStream])
		{
			[xmppStream sendElement:[XMPPvCardTemp iqvCardRequestForJID:jid]];
		}
		
		result = vCardTemp;
	}};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

- (XMPPvCardTemp *)myvCardTemp
{
	return [self fetchvCardTempForJID:[xmppStream myJID]];
}

- (void)updateMyvCardTemp:(XMPPvCardTemp *)vCardTemp
{
    
    dispatch_block_t block = ^{ @autoreleasepool {

        XMPPvCardTemp *newvCardTemp = [vCardTemp copy];

        NSString *myvCardElementID = [xmppStream generateUUID];
        
        XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:nil elementID:myvCardElementID child:newvCardTemp];
        [xmppStream sendElement:iq];
        
        [myvCardTracker addID:myvCardElementID
                       target:self
                     selector:@selector(handleMyvcard:withInfo:)
                      timeout:60];
        
        [self _updatevCardTemp:newvCardTemp forJID:[xmppStream myJID]];
        
    }};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_sync(moduleQueue, block);

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Private
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)_updatevCardTemp:(XMPPvCardTemp *)vCardTemp forJID:(XMPPJID *)jid
{
    if(jid == nil){
        return;
    }
    
	// this method could be called from anywhere
	dispatch_block_t block = ^{ @autoreleasepool {
		
		XMPPLogVerbose(@"%@: %s %@", THIS_FILE, __PRETTY_FUNCTION__, [jid bare]);
		
		[_moduleStorage setvCardTemp:vCardTemp forJID:jid xmppStream:xmppStream];
		
		[(id <XMPPvCardTempModuleDelegate>)multicastDelegate xmppvCardTempModule:self
		                                                     didReceivevCardTemp:vCardTemp
		                                                                  forJID:jid];
	}};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStreamDelegate methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	// This method is invoked on the moduleQueue.
	
    [myvCardTracker invokeForID:[iq elementID] withObject:iq];
    
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
	[myvCardTracker removeAllIDs];
}

@end
