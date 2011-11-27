//
//  XMPPIQRequest.m
//  iPhoneXMPP
//
//  Created by studentdeng on 11-11-27.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "XMPPIQRequest.h"
#import "XMPPIDTracker.h"
#import "XMPPLogging.h"

#define RELEASE_SAFELY(__POINTER) { [__POINTER release]; __POINTER = nil; }

static const int ddLogLevel = LOG_LEVEL_ERROR;

#define IQTIMEOUT          10
#define TIMEOUT            IQTIMEOUT + 5

@interface XMPPIQRequest(PrivateAPI)

- (void)iqSyncResult:(XMPPIQ *)iq withInfo:(id <XMPPTrackingInfo>)info;

@end

@implementation XMPPIQRequest

- (id)init 
{
    return [self initWithDispatchQueue:NULL];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue 
{
    if ((self = [super initWithDispatchQueue:queue]))
    {
        xmppIDTracker = [[XMPPIDTracker alloc] initWithDispatchQueue:self.moduleQueue];  
        waitObjects = [[NSMutableDictionary alloc] initWithCapacity:3];
    }
    return self;
}

- (BOOL)activate:(XMPPStream *)aXmppStream
{
    if ([super activate:aXmppStream])
    {
        return YES;
    }
    
    return NO;
}

- (void)deactivate
{
    [super deactivate];
}

- (NSString *)moduleName
{
    return @"XMPPIQRequest";
}

- (void)dealloc
{
    RELEASE_SAFELY(xmppIDTracker);  
    RELEASE_SAFELY(waitObjects);
    
    [super dealloc];
}

#pragma mark method

- (XMPPIQ *)sendSyncEx:(XMPPIQ *)iq;
{
    // this method can invoke on any thread 
    
    if ([xmppStream isDisconnected]) {
        return nil;
    }
    
    XMPPIQ *sendIQ = [XMPPIQ iqFromElement:iq];
    
    if (sendIQ == nil || [[sendIQ elementID] length] == 0) {
        return nil;
    }
    
    XMPPIQRequestPakage *pakage = [[XMPPIQRequestPakage alloc] init];
    XMPPElementReceipt *aReceipt = [[XMPPElementReceipt alloc] init];
    pakage.receipt = aReceipt;
    [aReceipt release];
    
    dispatch_block_t block = ^{
        [waitObjects setObject:pakage forKey:[sendIQ elementID]];
        
        [xmppIDTracker addID:[sendIQ elementID] 
                      target:self 
                    selector:@selector(iqSyncResult:withInfo:) 
                     timeout:IQTIMEOUT];
	};
	
	if (dispatch_get_current_queue() == self.moduleQueue)
		block();
	else
		dispatch_sync(self.moduleQueue, block);
    
    [xmppStream sendElement:sendIQ];
    
    BOOL bRes = [pakage.receipt wait:TIMEOUT];
    
    if (!bRes) {
        DDLogError(@"%@, %@, may be dead lock happen", THIS_FILE, THIS_METHOD);
    }
    
    XMPPIQ *iqReceive = pakage.iqReceive;
    
    if (iqReceive == nil || [iqReceive isErrorIQ]) {
        RELEASE_SAFELY(pakage);
        return nil;
    }
    
    [pakage autorelease];
    return [XMPPIQ iqFromElement:iqReceive];
}

- (void)iqSyncResult:(XMPPIQ *)iq withInfo:(id <XMPPTrackingInfo>)info 
{
    NSAssert(dispatch_get_current_queue() == self.moduleQueue, 
             @"Invoked on incorrect queue");
    
    XMPPIQRequestPakage *pakage = [waitObjects objectForKey:[iq elementID]];
    if (iq) {
        pakage.iqReceive = iq;
        [pakage.receipt signalSuccess];
    }
    else {
        pakage.iqReceive = nil;
        [pakage.receipt signalFailure];
    }
    
    [waitObjects removeObjectForKey:[iq elementID]];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


- (void)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{   
    NSAssert(dispatch_get_current_queue() == self.moduleQueue, @"Invoked on incorrect queue");
    
    NSString *type = [iq type];
    if ([type isEqualToString:@"result"] || [type isEqualToString:@"error"])
    {
        [xmppIDTracker invokeForID:[iq elementID] withObject:iq]; 
    }
}

@end

@implementation XMPPIQRequestPakage

@synthesize iqReceive;
@synthesize receipt;

- (void)dealloc
{
    [iqReceive release];
    
    [receipt signalFailure];
    [receipt release];
    
    [super dealloc];
}

@end


