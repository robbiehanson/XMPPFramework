//
//  XMPPvCardTempModule.m
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/9/11.
//  Copyright 2011 RF.com. All rights reserved.
//  Copyright 2010 Martin Morrison. All rights reserved.
//


#import "XMPPvCardTempModule.h"

#import "DDLog.h"
#import "NSXMLElementAdditions.h"
#import "XMPPIQ.h"
#import "XMPPJID.h"
#import "XMPPPresence.h"
#import "XMPPStream.h"


NSString *const XMPPNSvCardTemp = @"vcard-temp";


@implementation XMPPvCardTempModule


#pragma mark -
#pragma mark Init/dealloc methods


- (id)initWithStream:(XMPPStream *)stream 
             storage:(id <XMPPvCardTempStorage>)storage 
           autoFetch:(BOOL)autoFetch {
	if (self == [super initWithStream:stream]) {
		_storage = [storage retain];
		_autoFetch = autoFetch;
	}
	return self;
}


- (void)dealloc {
	[_storage release];
	_storage = nil;

	[super dealloc];
}


#pragma mark -
#pragma mark Public instance methods


- (BOOL)havevCardForJID:(XMPPJID *)jid{
  return [_storage havevCardForJID:jid];
}


/*
 * Return the vCard for the given JID, if stored locally.
 * If the vCard is not local, fetch the vCard from the server.
 */
- (XMPPvCard *)vCardForJID:(XMPPJID *)jid {
  
	XMPPJID *bareJID = [jid bareJID];
  XMPPvCard *vCard = [_storage vCardForJID:bareJID];
  
  // Check whether we already have a vCard
	if (vCard == nil) {
		// Not got it yet. Let's make a request for the vCard
		XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:bareJID];
		NSXMLElement *vCardElem = [NSXMLElement elementWithName:@"vCard" xmlns:XMPPNSvCardTemp];
		
		[iq addChild:vCardElem];
		
		[xmppStream sendElement:iq];
	}
  
  return vCard;
}


/*
 * Remove the stored vCard for the given JID.
 */
- (void)removevCardForJID:(XMPPJID *)jid {
  [_storage removevCardForJID:jid];
}


#pragma mark -
#pragma mark XMPPStreamDelegate methods


- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq {
	NSXMLElement *elem = [iq elementForName:@"vCard" xmlns:XMPPNSvCardTemp];
	DDLogInfo(@"Received IQ in vCard module with elem: %@", elem);
	if (elem != nil) {
		XMPPvCard *vCard = [XMPPvCard vCardFromElement:elem];
		[_storage savevCard:vCard forJID:[iq from]];
		
		[multicastDelegate xmppvCardTempModule:self didReceivevCard:vCard forJID:[iq from]];
    return YES;
	}
	
	return NO;
}


- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence {
  XMPPJID *fromJID = [presence from];
  
  // We use this to track online buddies
  if (_autoFetch &&
      [presence status] != @"unavailable" &&
      fromJID != nil) {
    [self vCardForJID:fromJID];
  }    
}


#pragma mark -
#pragma mark Getter/setter methods


@synthesize autoFetch = _autoFetch;
@synthesize storage = _storage;


@end
