//
//  XMPPvCardTempAdrTypes.m
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/9/11.
//  Copyright 2011 RF.com. All rights reserved.
//  Copyright 2010 Martin Morrison. All rights reserved.
//


#import "XMPPvCardTempAdrTypes.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif


@implementation XMPPvCardTempAdrTypes


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


- (BOOL)isParcel {
	return [self elementForName:@"PARCEL"] != nil;
}


- (void)setParcel:(BOOL)parcel {
	XMPP_VCARD_SET_EMPTY_CHILD(parcel && ![self isParcel], @"PARCEL");
}


- (BOOL)isPostal {
	return [self elementForName:@"POSTAL"] != nil;
}


- (void)setPostal:(BOOL)postal {
	XMPP_VCARD_SET_EMPTY_CHILD(postal && ![self isPostal], @"POSTAL");
}


- (BOOL)isDomestic {
	return [self elementForName:@"DOM"] != nil;
}


- (void)setDomestic:(BOOL)dom {
	XMPP_VCARD_SET_EMPTY_CHILD(dom && ![self isDomestic], @"DOM");
	// INTL and DOM are mutually exclusive
	if (dom) {
		[self setInternational:NO];
	}
}


- (BOOL)isInternational {
	return [self elementForName:@"INTL"] != nil;
}


- (void)setInternational:(BOOL)intl {
	XMPP_VCARD_SET_EMPTY_CHILD(intl && ![self isInternational], @"INTL");
	// INTL and DOM are mutually exclusive
	if (intl) {
		[self setDomestic:NO];
	}
}


- (BOOL)isPreferred {
	return [self elementForName:@"PREF"] != nil;
}


- (void)setPreferred:(BOOL)pref {
	XMPP_VCARD_SET_EMPTY_CHILD(pref && ![self isPreferred], @"PREF");
}


@end
