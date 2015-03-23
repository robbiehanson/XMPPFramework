//
//  XMPPvCardTempTel.m
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/9/11.
//  Copyright 2011 RF.com. All rights reserved.
//  Copyright 2010 Martin Morrison. All rights reserved.
//


#import "XMPPvCardTempTel.h"
#import "XMPPLogging.h"

#import <objc/runtime.h>

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_ERROR;
#endif


@implementation XMPPvCardTempTel

#if DEBUG

+ (void)initialize {
	// We use the object_setClass method below to dynamically change the class from a standard NSXMLElement.
	// The size of the two classes is expected to be the same.
	// 
	// If a developer adds instance methods to this class, bad things happen at runtime that are very hard to debug.
	// This check is here to aid future developers who may make this mistake.
	// 
	// For Fearless And Experienced Objective-C Developers:
	// It may be possible to support adding instance variables to this class if you seriously need it.
	// To do so, try realloc'ing self after altering the class, and then initialize your variables.
	
	size_t superSize = class_getInstanceSize([NSXMLElement class]);
	size_t ourSize   = class_getInstanceSize([XMPPvCardTempTel class]);
	
	if (superSize != ourSize)
	{
		XMPPLogError(@"Adding instance variables to XMPPvCardTempTel is not currently supported!");
		
		[DDLog flushLog];
		exit(15);
	}
}

#endif

+ (XMPPvCardTempTel *)vCardTelFromElement:(NSXMLElement *)elem {
	object_setClass(elem, [XMPPvCardTempTel class]);
	
	return (XMPPvCardTempTel *)elem;
}


#pragma mark -
#pragma mark Getter/setter methods

- (BOOL)isHome {
	return [self elementForName:@"HOME"] != nil;
}


- (void)setHome:(BOOL)home {
	XMPP_VCARD_SET_EMPTY_CHILD(home && ![self isHome], @"HOME");
}


- (BOOL)isWork {
	return [self elementForName:@"WORK"] != nil;
}


- (void)setWork:(BOOL)work {
	XMPP_VCARD_SET_EMPTY_CHILD(work && ![self isWork], @"WORK");
}


- (BOOL)isVoice {
	return [self elementForName:@"VOICE"] != nil;
}


- (void)setVoice:(BOOL)voice {
	XMPP_VCARD_SET_EMPTY_CHILD(voice && ![self isVoice], @"VOICE");
}


- (BOOL)isFax {
	return [self elementForName:@"FAX"] != nil;
}


- (void)setFax:(BOOL)fax {
	XMPP_VCARD_SET_EMPTY_CHILD(fax && ![self isFax], @"FAX");
}


- (BOOL)isPager {
	return [self elementForName:@"PAGER"] != nil;
}


- (void)setPager:(BOOL)pager {
	XMPP_VCARD_SET_EMPTY_CHILD(pager && ![self isPager], @"PAGER");
}


- (BOOL)hasMessaging {
	return [self elementForName:@"MSG"] != nil;
}


- (void)setMessaging:(BOOL)msg {
	XMPP_VCARD_SET_EMPTY_CHILD(msg && ![self hasMessaging], @"MSG");
}


- (BOOL)isCell {
	return [self elementForName:@"CELL"] != nil;
}


- (void)setCell:(BOOL)cell {
	XMPP_VCARD_SET_EMPTY_CHILD(cell && ![self isCell], @"CELL");
}


- (BOOL)isVideo {
	return [self elementForName:@"VIDEO"] != nil;
}


- (void)setVideo:(BOOL)video {
	XMPP_VCARD_SET_EMPTY_CHILD(video && ![self isVideo], @"VIDEO");
}


- (BOOL)isBBS {
	return [self elementForName:@"BBS"] != nil;
}


- (void)setBBS:(BOOL)bbs {
	XMPP_VCARD_SET_EMPTY_CHILD(bbs && ![self isBBS], @"BBS");
}


- (BOOL)isModem {
	return [self elementForName:@"MODEM"] != nil;
}


- (void)setModem:(BOOL)modem {
	XMPP_VCARD_SET_EMPTY_CHILD(modem && ![self isModem], @"MODEM");
}


- (BOOL)isISDN {
	return [self elementForName:@"ISDN"] != nil;
}


- (void)setISDN:(BOOL)isdn {
	XMPP_VCARD_SET_EMPTY_CHILD(isdn && ![self isISDN], @"ISDN");
}


- (BOOL)isPCS {
	return [self elementForName:@"PCS"] != nil;
}


- (void)setPCS:(BOOL)pcs {
	XMPP_VCARD_SET_EMPTY_CHILD(pcs && ![self isPCS], @"PCS");
}


- (BOOL)isPreferred {
	return [self elementForName:@"PREF"] != nil;
}


- (void)setPreferred:(BOOL)pref {
	XMPP_VCARD_SET_EMPTY_CHILD(pref && ![self isPreferred], @"PREF");
}


- (NSString *)number {
	return [[self elementForName:@"NUMBER"] stringValue];
}


- (void)setNumber:(NSString *)number {
	XMPP_VCARD_SET_STRING_CHILD(number, @"NUMBER");
}


@end
