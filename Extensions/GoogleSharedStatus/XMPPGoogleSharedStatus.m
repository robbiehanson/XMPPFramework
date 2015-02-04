#import "XMPPGoogleSharedStatus.h"
#import "XMPP.h"
#import "XMPPFramework.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#define GOOGLE_SHARED_STATUS @"google:shared-status"
#define GOOGLE_DISCO_INFO  @"http://jabber.org/protocol/disco#info"
#define GOOGLE_PRESENCE_PRIORITY @"24"

// Dictionary keys to access shared status information.
NSString *const XMPPGoogleSharedStatusShow = @"show";
NSString *const XMPPGoogleSharedStatusInvisible = @"invisible";
NSString *const XMPPGoogleSharedStatusStatus = @"status";

// Shared status display values. Note that you cannot set
// a shared status for an idle show.
NSString *const XMPPGoogleSharedStatusShowAvailable = @"default";
NSString *const XMPPGoogleSharedStatusShowBusy = @"dnd";
NSString *const XMPPGoogleSharedStatusShowIdle = @"away";

@interface XMPPGoogleSharedStatus () {
  
	// Server specified maximum values.
	NSInteger _statusListMaxCount;
	NSInteger _statusMessageMaxLength;
}

@property (nonatomic, copy) NSString *previousShow;

@end

@implementation XMPPGoogleSharedStatus

#pragma mark - Object Lifecycle

- (id)initWithDispatchQueue:(dispatch_queue_t)queue {
	if((self = [super initWithDispatchQueue:queue])) {
		self.sharedStatus = [NSDictionary dictionary];
		_status = @"";
		_show = XMPPGoogleSharedStatusShowAvailable;
		_invisible = NO;
		
#ifdef _XMPP_SYSTEM_INPUT_ACTIVITY_MONITOR_H
		self.assumeIdleUpdateResponsibility = YES;
#endif
	}
	return self;
}


- (BOOL)activate:(XMPPStream *)aXmppStream
{	
	if ([super activate:aXmppStream])
	{
		
#ifdef _XMPP_SYSTEM_INPUT_ACTIVITY_MONITOR_H
		[xmppStream autoAddDelegate:self
					  delegateQueue:moduleQueue
				   toModulesOfClass:[XMPPSystemInputActivityMonitor class]];
#endif
		
		return YES;
	}
	
	return NO;
}

- (void)deactivate
{
	
#ifdef _XMPP_SYSTEM_INPUT_ACTIVITY_MONITOR_H
	[xmppStream removeAutoDelegate:self
					 delegateQueue:moduleQueue
				fromModulesOfClass:[XMPPSystemInputActivityMonitor class]];
#endif
	
	[super deactivate];
}



#pragma mark - Convenience Properties

// Convinience single-item setters which forward status setting
// to the more complex update method below. Use these sparingly,
// because they have heavy load when used in succession.
- (void)setStatus:(NSString *)status {
	[self updateSharedStatus:status show:self.show invisible:self.invisible];
}

- (void)setShow:(NSString *)show {
	[self updateSharedStatus:self.status show:show invisible:self.invisible];
}

- (void)setInvisible:(BOOL)invisible {
	[self updateSharedStatus:self.status show:self.show invisible:invisible];
}

#pragma mark - Status Updates

// This is a heavyweight method used to update all three attributes,
// status, show, and invisible, at once. Use this method over the
// convinience accessors above. Wherever possible, lessen the status
// update load. This method refuses service if shared status is not
// supported, removes previous statuses if the list reaches max
// count, and cuts status strings to the max string length.
- (void)updateSharedStatus:(NSString *)status show:(NSString *)show invisible:(BOOL)invisible {
	if(!self.sharedStatusSupported) {
		NSLog(@"Google Shared Status Not Supported!");
		return;
	}
	
	// Create a mutable copy of shared status information and chop the status.
	NSMutableDictionary *sharedStatusUpdate = [self.sharedStatus mutableCopy];
	if(status.length > _statusMessageMaxLength)
		status = [status substringToIndex:_statusMessageMaxLength];
	
	// If the show has changed update it.
	if(![show isEqualToString:sharedStatusUpdate[XMPPGoogleSharedStatusShow]]) {
		[sharedStatusUpdate removeObjectForKey:XMPPGoogleSharedStatusShow];
		sharedStatusUpdate[XMPPGoogleSharedStatusShow] = show;
	}
	
	// Get the current show value, and whether the status should update for it.
	BOOL displayShow = ([show isEqualToString:XMPPGoogleSharedStatusShowAvailable] ||
						[show isEqualToString:XMPPGoogleSharedStatusShowBusy]);
	NSString *currentShow = self.sharedStatus[XMPPGoogleSharedStatusShow];
	
	// Since we can't show an away status, only change the status it has
	// changed and is not showing idle.
	if(![status isEqualToString:sharedStatusUpdate[XMPPGoogleSharedStatusStatus]] && displayShow) {
		[sharedStatusUpdate removeObjectForKey:XMPPGoogleSharedStatusStatus];
		sharedStatusUpdate[XMPPGoogleSharedStatusStatus] = status;
		
		// Update the appropriate status list by adding the new status.
		// If the list max count was reached, truncate its earliest status.
		NSMutableArray *statusList = [sharedStatusUpdate[currentShow] mutableCopy];
		[statusList insertObject:status atIndex:0];
		if(statusList.count > _statusListMaxCount)
			[statusList removeObjectAtIndex:statusList.count-1];
		
		// Remove any blank statuses.
		for(int i = 0; i < statusList.count; i++) {
			NSString *status = statusList[i];
			if([status isEqualToString:@""])
				[statusList removeObjectAtIndex:i];
		}
		
		// Update the status list for this status.
		[sharedStatusUpdate removeObjectForKey:currentShow];
		sharedStatusUpdate[currentShow] = statusList;
	}
	
	// Update the invisibility for this shared status.
	[sharedStatusUpdate removeObjectForKey:XMPPGoogleSharedStatusInvisible];
	sharedStatusUpdate[XMPPGoogleSharedStatusInvisible] = @(invisible);
	
	// Wrap it in an XMPPIQ "set" and send it to the server.
	XMPPIQ *statusIQ = [XMPPIQ iqWithType:@"set" to:self.xmppStream.myJID.bareJID];
	[statusIQ addAttributeWithName:@"id" stringValue:self.xmppStream.myJID.resource];
	[statusIQ addChild:[self packSharedStatus:sharedStatusUpdate]];
	[self.xmppStream sendElement:statusIQ];
	
	// Now update our local values, toll-free.
	_show = show;
	_status = status;
	_invisible = invisible;
}

#pragma mark - Capability Discovery

// Discover and refresh shared status as soon as authentication.
- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender {
	[self discoverCapabilities];
	[self refreshSharedStatus];
}

// Disable support when the stream disconnects.
- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error {
	self.sharedStatus = [NSDictionary dictionary];
	self.sharedStatusSupported = NO;
}

// First discover capabilities to find google:shared-status. If it exists,
// we can continue with the shared status support.
- (void)discoverCapabilities {
	XMPPIQ *discoIQ = [XMPPIQ iqWithType:@"get" to:[XMPPJID jidWithString:@"gmail.com"]];
	[discoIQ addChild:[XMPPElement elementWithName:@"query" xmlns:GOOGLE_DISCO_INFO]];
	[self.xmppStream sendElement:discoIQ];
}

// Manually trigger a refresh cycle for getting shared statuses. This will
// return an XML stanza containing status-lists and current status info.
- (void)refreshSharedStatus {
	XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:self.xmppStream.myJID.bareJID];
	[iq addAttributeWithName:@"id" stringValue:self.xmppStream.myJID.resource];
	
	XMPPElement *query = (XMPPElement *)[XMPPElement elementWithName:@"query" xmlns:GOOGLE_SHARED_STATUS];
	[query addAttributeWithName:@"version" stringValue:@"2"];
	
	[iq addChild:query];
	[self.xmppStream sendElement:iq];
}

// If we received a shared-status IQ and we support it, unpack it into a
// dictionary and notify the delegates. If it is the first shared-status
// subscription IQ, it contains the maximum string length and list count
// information attributes as well, so save those.
// If we received a discovery IQ, determine shared status support.
- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq {
	XMPPElement *query = (XMPPElement *) [iq children][0];
	if([query.xmlns isEqualToString:GOOGLE_SHARED_STATUS] && self.sharedStatusSupported) {
		self.sharedStatus = [self unpackSharedStatus:query];
		_show = self.sharedStatus[XMPPGoogleSharedStatusShow];
		_status = self.sharedStatus[XMPPGoogleSharedStatusStatus];
		_invisible = [self.sharedStatus[XMPPGoogleSharedStatusInvisible] boolValue];
		[multicastDelegate xmppGoogleSharedStatus:self didReceiveUpdatedStatus:self.sharedStatus];
		
		if([query attributeForName:@"status-max"])
			_statusMessageMaxLength = [[query attributeForName:@"status-max"].stringValue integerValue];
		if([query attributeForName:@"status-list-contents-max"])
			_statusListMaxCount = [[query attributeForName:@"status-list-contents-max"].stringValue integerValue];
		
	} else if([query.xmlns isEqualToString:GOOGLE_DISCO_INFO]) {
		for(XMPPElement *feature in query.children)
			if([[[feature attributeForName:@"var"] stringValue] isEqualToString:GOOGLE_SHARED_STATUS])
				self.sharedStatusSupported = YES;
	}
	
	return YES;
}

#pragma mark - Packing & Unpacking

// Unpacks the XMPPElement "query" for a shared status and returns
// a formatted NSDictionary with corresponding arrays and strings.
// The XMPPElement "query" is a child of a shared status XMPPIQ.
- (NSDictionary *)unpackSharedStatus:(XMPPElement *)sharedStatus {
	if([sharedStatus.xmlns isEqualToString:GOOGLE_SHARED_STATUS]) {
		NSMutableDictionary *dict = [NSMutableDictionary dictionary];
		
		for(XMPPElement *element in sharedStatus.children) {
			if([element.name isEqualToString:@"status-list"]) {
				NSMutableArray *array = [NSMutableArray array];
				for(XMPPElement *status in element.children)
					[array addObject:[status stringValue]];
				dict[[[element attributeForName:XMPPGoogleSharedStatusShow] stringValue]] = array;
			} else if([element.name isEqualToString:XMPPGoogleSharedStatusStatus]) {
				dict[element.name] = [element stringValue];
			} else if([element.name isEqualToString:XMPPGoogleSharedStatusShow]) {
				dict[element.name] = [element stringValue];
			} else if([element.name isEqualToString:XMPPGoogleSharedStatusInvisible]) {
				dict[element.name] = @([[[element attributeForName:@"value"] stringValue] boolValue]);
			} else {
				NSLog(@"Missed element: %@", element);
			}
		}
		
		return dict;
	}
	return nil;
}

// Packs a formatted NSDictionary with corresponding arrays and strings
// back into an XMPPElement "query" for shared status. This must be
// further wrapped in an XMPPIQ to send a status update.
- (XMPPElement *)packSharedStatus:(NSDictionary *)sharedStatus {
	XMPPElement *element = (XMPPElement *)[XMPPElement elementWithName:@"query" xmlns:GOOGLE_SHARED_STATUS];
	[element addAttributeWithName:@"version" stringValue:@"2"];
	
	[element addChild:[XMPPElement elementWithName:XMPPGoogleSharedStatusStatus
                                     stringValue:sharedStatus[XMPPGoogleSharedStatusStatus]]];
	[element addChild:[XMPPElement elementWithName:XMPPGoogleSharedStatusShow
                                     stringValue:sharedStatus[XMPPGoogleSharedStatusShow]]];
	
	for(NSString *key in sharedStatus.allKeys.reverseObjectEnumerator) {
		if([key isEqualToString:XMPPGoogleSharedStatusShowAvailable] ||
		   [key isEqualToString:XMPPGoogleSharedStatusShowBusy]) {
			
			NSArray *statusList = sharedStatus[key];
			XMPPElement *statusElement = [XMPPElement elementWithName:@"status-list"];
			[statusElement addAttributeWithName:@"show" stringValue:key];
			
			for(NSString *status in statusList)
				[statusElement addChild:[XMPPElement elementWithName:@"status" stringValue:status]];
			[element addChild:statusElement];
		} else if(!([key isEqualToString:XMPPGoogleSharedStatusInvisible] ||
					[key isEqualToString:XMPPGoogleSharedStatusShow] ||
					[key isEqualToString:XMPPGoogleSharedStatusStatus])) {
			NSLog(@"Invalid element: %@", key);
		}
	}
	
	XMPPElement *invisible = [XMPPElement elementWithName:XMPPGoogleSharedStatusInvisible];
	[invisible addAttributeWithName:@"value"
						stringValue:[sharedStatus[XMPPGoogleSharedStatusInvisible] boolValue] ? @"true" : @"false"];
	[element addChild:invisible];
	
	return element;
}

#pragma mark - Other Properties

- (void)setAssumeIdleUpdateResponsibility:(BOOL)flag {
	_assumeIdleUpdateResponsibility = flag;
}

- (void)setStatusAvailability:(NSString *)statusAvailability {
	_statusAvailability = statusAvailability;
	
	XMPPPresence *presence = [XMPPPresence presence];
    [presence addChild:[XMPPElement elementWithName:@"priority" stringValue:GOOGLE_PRESENCE_PRIORITY]];
    XMPPElement *show = [XMPPElement elementWithName:@"show"];
    XMPPElement *status = [XMPPElement elementWithName:@"status"];
	
	if(self.statusAvailability) {
		[show setStringValue:self.statusAvailability];
		[presence addChild:show];
	}
	
	if(self.statusMessage) {
		[status setStringValue:self.statusMessage];
		[presence addChild:status];
	}
	
    [self.xmppStream sendElement:presence];
}

- (void)setStatusMessage:(NSString *)statusMessage {
	_statusMessage = statusMessage;
	
	XMPPPresence *presence = [XMPPPresence presence];
    XMPPElement *show = [XMPPElement elementWithName:@"show"];
    XMPPElement *status = [XMPPElement elementWithName:@"status"];
	
	if(self.statusAvailability) {
		[show setStringValue:self.statusAvailability];
		[presence addChild:show];
	}
	
	if(self.statusMessage) {
		[status setStringValue:self.statusMessage];
		[presence addChild:status];
	}
	
    [self.xmppStream sendElement:presence];
}

#ifdef _XMPP_SYSTEM_INPUT_ACTIVITY_MONITOR_H

#pragma mark - XMPP System Input Activity Monitor Delegate

- (void)xmppSystemInputActivityMonitorDidBecomeActive:(XMPPSystemInputActivityMonitor *)xmppSystemInputActivityMonitor
{
	self.show = self.previousShow;
}

- (void)xmppSystemInputActivityMonitorDidBecomeInactive:(XMPPSystemInputActivityMonitor *)xmppSystemInputActivityMonitor
{
	self.previousShow = self.show;
	self.show = XMPPGoogleSharedStatusShowIdle;
}

#endif

@end
