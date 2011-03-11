//
//  XMPPvCardTempMemoryStorage.m
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/9/11.
//  Copyright 2011 RF.com. All rights reserved.
//  Copyright 2010 Martin Morrison. All rights reserved.
//


#import "XMPPvCardTempMemoryStorage.h"


#ifdef DEBUG_LEVEL
#undef DEBUG_LEVEL
#define DEBUG_LEVEL 1
#endif


@implementation XMPPvCardTempMemoryStorage


#pragma mark -
#pragma mark Init/dealloc methods


- (id)init {
	if (self == [super init]) {
		vcards = [[NSMutableDictionary alloc] init];
	}
	
	return self;
}


- (void)dealloc {
	[vcards release];
	[super dealloc];
}


#pragma mark -
#pragma mark XMPPvCardTempStorage protocol


- (BOOL)havevCardForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream {
	return [self vCardForJID:jid xmppStream:stream] != nil;
}


- (XMPPvCard *)vCardForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream {  
  if (jid == nil) {
    return nil;
  }
  
  DDLogInfo(@"%s %@", __PRETTY_FUNCTION__, [jid bare]);
  DDLogVerbose(@"\t\t\t%@", [[vcards objectForKey:jid] compactXMLString]);
	return [vcards objectForKey:jid];
}


- (void)savevCard:(XMPPvCard *)vCard forJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream {  
  if (jid != nil) {
    if (vCard == nil) {
      [self removevCardForJID:jid xmppStream:stream];
    } else {
      [vcards setObject:vCard forKey:jid];
      DDLogInfo(@"%s %@\n", __PRETTY_FUNCTION__, [jid bare]);
      DDLogVerbose(@"\t\t\t%@", [[vcards objectForKey:jid] compactXMLString]);
    }
  }
}


- (void)removevCardForJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream {
  if (jid != nil) {
    [vcards removeObjectForKey:jid];
    DDLogInfo(@"%s %@", __PRETTY_FUNCTION__, [jid bare]);
  }
}


@end
