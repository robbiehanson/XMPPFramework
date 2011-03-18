//
//  XMPPvCardTempModule.m
//  talk
//
//  Created by Eric Chamberlain on 3/17/11.
//  Copyright 2011 RF.com. All rights reserved.
//

#import "XMPPvCardTempModule.h"


@implementation XMPPvCardTempModule


#pragma mark -
#pragma mark Init/dealloc methods


- (id)initWithStream:(XMPPStream *)aXmppStream 
             storage:(id <XMPPvCardTempModuleStorage>)moduleStorage {
  if ((self = [super initWithStream:aXmppStream])) {
    _moduleStorage = [moduleStorage retain];
  }
  return self;
}


- (void)dealloc {
  [_moduleStorage release];
  _moduleStorage = nil;
  
  [super dealloc];
}


#pragma mark -
#pragma mark Private methods


- (void)_fetchvCardTempForJID:(XMPPJID *)jid {
  XMPPIQ *iq = [XMPPvCardTemp iqvCardTempRequestForJID:jid];
  
  [xmppStream sendElement:iq];
}


#pragma mark -
#pragma mark Fetch vCardTemp methods


- (XMPPvCardTemp *)fetchvCardTempForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)aXmppStream {
  return [self fetchvCard:jid xmppStream:aXmppStream useCache:YES];
}


- (XMPPvCardTemp *)fetchvCardTempForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)xmppStream useCache:(BOOL)useCache {
  XMPPvCardTemp *vCardTemp = nil;
  
  if (useCache) {
    // try loading from the cache
    vCardTemp = [_moduleStorage vCardTempForJID:jid];
  }
  
  if (vCardTemp == nil) {
    [self _fetchvCardTempForJID:jid];
  }
  
  return vCardTemp;
}


#pragma mark -
#pragma mark XMPPStreamDelegate methods


- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq {  
  XMPPvCardTemp *vCardTemp = [XMPPvCardTemp vCardTempFromIQ:iq];
  
	if (vCardTemp != nil) { 
    DDLogVerbose(@"%s %@", __PRETTY_FUNCTION__,[[iq from] bare]);
    
    [multicastDelegate xmppvCardTempModule:self 
                           didReceivevCardTemp:vCardTemp 
                                    forJID:[iq from]
                                xmppStream:sender];
    return YES;
	}
	return NO;
}


#pragma mark -
#pragma mark Getter/setter methods


@synthesize moduleStorage = _moduleStorage;


@end
