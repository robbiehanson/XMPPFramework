//
//  XMPPvCardTempAdr.m
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/9/11.
//  Copyright 2011 RF.com. All rights reserved.
//  Copyright 2010 Martin Morrison. All rights reserved.
//


#import "XMPPvCardTempAdr.h"
#import "XMPPLogging.h"

#import <objc/runtime.h>

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_ERROR;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_ERROR;
#endif


@implementation XMPPvCardTempAdr


+ (void)initialize
{
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
	size_t ourSize   = class_getInstanceSize([XMPPvCardTempAdr class]);
	
	if (superSize != ourSize)
	{
		XMPPLogError(@"Adding instance variables to XMPPvCardTempAdr is not currently supported!");
		
		[DDLog flushLog];
		exit(15);
	}
}


+ (XMPPvCardTempAdr *)vCardAdrFromElement:(NSXMLElement *)elem {
	object_setClass(elem, [XMPPvCardTempAdr class]);
  
	return (XMPPvCardTempAdr *)elem;
}


#pragma mark -
#pragma mark Getter/setter methods


- (NSString *)pobox {
	return [[self elementForName:@"POBOX"] stringValue];
}


- (void)setPobox:(NSString *)pobox {
	XMPP_VCARD_SET_STRING_CHILD(pobox, @"POBOX");
}


- (NSString *)extendedAddress {
	return [[self elementForName:@"EXTADD"] stringValue];
}


- (void)setExtendedAddress:(NSString *)extadd {
	XMPP_VCARD_SET_STRING_CHILD(extadd, @"EXTADD");
}	


- (NSString *)street {
	return [[self elementForName:@"STREET"] stringValue];
}


- (void)setStreet:(NSString *)street {
	XMPP_VCARD_SET_STRING_CHILD(street, @"STREET");
}


- (NSString *)locality {
	return [[self elementForName:@"LOCALITY"] stringValue];
}


- (void)setLocality:(NSString *)locality {
	XMPP_VCARD_SET_STRING_CHILD(locality, @"LOCALITY");
}


- (NSString *)region {
	return [[self elementForName:@"REGION"] stringValue];
}


- (void)setRegion:(NSString *)region {
	XMPP_VCARD_SET_STRING_CHILD(region, @"REGION");
}


- (NSString *)postalCode {
	return [[self elementForName:@"PCODE"] stringValue];
}


- (void)setPostalCode:(NSString *)pcode {
	XMPP_VCARD_SET_STRING_CHILD(pcode, @"PCODE");
}


- (NSString *)country {
	return [[self elementForName:@"CTRY"] stringValue];
}


- (void)setCountry:(NSString *)ctry {
	XMPP_VCARD_SET_STRING_CHILD(ctry, @"CTRY");
}


@end
