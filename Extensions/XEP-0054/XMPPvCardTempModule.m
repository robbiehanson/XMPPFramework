//
//  XMPPvCardTempModule.m
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/17/11.
//  Copyright 2011 RF.com. All rights reserved.
//

#import "XMPPvCardTempModule.h"

#undef DEBUG_LEVEL
#define DEBUG_LEVEL 4

#import "DDLog.h"


#if XMPP_VCARD_TEMP_QUEUEING
enum {
  kXMPPvCardTempModuleMaxOpenFetchRequests = 5,
  kXMPPvCardTempModuleOpenFetchRequestTimeout = 10,
};
#endif


@implementation XMPPvCardTempModule


#pragma mark -
#pragma mark Init/dealloc methods


- (id)initWithStream:(XMPPStream *)aXmppStream 
             storage:(id <XMPPvCardTempModuleStorage>)moduleStorage {
  if ((self = [super initWithStream:aXmppStream])) {
    _moduleStorage = [moduleStorage retain];
    
#if XMPP_VCARD_TEMP_QUEUEING
    _openFetchRequests = 0;
    _pendingFetchRequests = [[NSMutableArray alloc] initWithCapacity:2];
#endif
  }
  return self;
}


- (void)dealloc {
#if XMPP_VCARD_TEMP_QUEUEING
  [_pendingFetchRequests release];
#endif
  
  [_moduleStorage release];
  _moduleStorage = nil;
  
  [super dealloc];
}


#pragma mark -
#pragma mark Private methods


- (void)_fetchvCardTempForJID:(XMPPJID *)jid {
  XMPPIQ *iq = [XMPPvCardTemp iqvCardRequestForJID:jid];
  
#if XMPP_VCARD_TEMP_QUEUEING
  _openFetchRequests++;
  DDLogVerbose(@"%s %d", __PRETTY_FUNCTION__, _openFetchRequests);
#endif
  
  [xmppStream sendElement:iq];
}


#pragma mark -
#pragma mark Fetch vCardTemp methods


- (XMPPvCardTemp *)fetchvCardTempForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)aXmppStream {
  return [self fetchvCardTempForJID:jid xmppStream:aXmppStream useCache:YES];
}


- (XMPPvCardTemp *)fetchvCardTempForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)xmppStream useCache:(BOOL)useCache {
  XMPPvCardTemp *vCardTemp = nil;
  
  if (useCache) {
    // try loading from the cache
    vCardTemp = [_moduleStorage vCardTempForJID:jid];
  }
  
  if (vCardTemp == nil && [_moduleStorage shouldFetchvCardTempForJID:jid]) {
    
#if XMPP_VCARD_TEMP_QUEUEING
    if (_openFetchRequests >= kXMPPvCardTempModuleMaxOpenFetchRequests) {
      // queue the request
      [_pendingFetchRequests addObject:jid];
      
      return vCardTemp;
    }
#endif
    
    [self _fetchvCardTempForJID:jid];
  }
  return vCardTemp;
}


#pragma mark -
#pragma mark XMPPStreamDelegate methods


#if XMPP_VCARD_TEMP_QUEUEING
/*
 * clean up if we get disconnected
 */
- (void)xmppStreamDidDisconnect:(XMPPStream *)sender {
  _openFetchRequests = 0;
  [_pendingFetchRequests removeAllObjects];
}
#endif


- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq {  
  XMPPvCardTemp *vCardTemp = [XMPPvCardTemp vCardTempFromIQ:iq];
  
	if (vCardTemp != nil) { 
    XMPPJID *jid = [iq from];
    DDLogVerbose(@"%s %@", __PRETTY_FUNCTION__,[jid bare]);
    
#if XMPP_VCARD_TEMP_QUEUEING
    if (_openFetchRequests > 0) {
      _openFetchRequests--;
    }
    
    DDLogVerbose(@"%s %d", __PRETTY_FUNCTION__, _openFetchRequests);
    
    if (_openFetchRequests < kXMPPvCardTempModuleMaxOpenFetchRequests &&
        [_pendingFetchRequests count] > 0) {
      [self _fetchvCardTempForJID:[_pendingFetchRequests objectAtIndex:0]];
      [_pendingFetchRequests removeObjectAtIndex:0];
    }
    
#endif
    
    [_moduleStorage setvCardTemp:vCardTemp forJID:jid];
    
    [multicastDelegate xmppvCardTempModule:self 
                           didReceivevCardTemp:vCardTemp 
                                    forJID:jid
                                xmppStream:sender];
    return YES;
	}
	return NO;
}


#pragma mark -
#pragma mark Getter/setter methods


@synthesize moduleStorage = _moduleStorage;


@end
