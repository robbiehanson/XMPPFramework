//
//  XMPPPresence+XEP_0153.m
//
//  Created by Indragie Karunaratne on 2013-01-08.
//  Copyright (c) 2013 Indragie Karunaratne. All rights reserved.
//

#import "XMPPPresence+XEP_0153.h"
#import "NSXMLElement+XMPP.h"

static NSString* const XMPPPresenceElementX = @"x";
static NSString* const XMPPPresenceElementNSX = @"vcard-temp:x:update";
static NSString* const XMPPPresenceElementPhoto = @"photo";

@implementation XMPPPresence (XEP_0153)

- (NSString *)photoHash
{
	NSXMLElement *x = [self elementForName:XMPPPresenceElementX xmlns:XMPPPresenceElementNSX];
	NSXMLElement *photo = [x elementForName:XMPPPresenceElementPhoto];
	return [photo stringValue];
}

- (void)setPhotoHash:(NSString *)photoHash
{
	NSXMLElement *x = [self elementForName:XMPPPresenceElementX xmlns:XMPPPresenceElementNSX];
	if (!x) {
		x = [NSXMLElement elementWithName:XMPPPresenceElementX xmlns:XMPPPresenceElementNSX];
		[self addChild:x];
	}
	NSXMLElement *photo = [x elementForName:XMPPPresenceElementPhoto];
	if (!photo) {
		photo = [NSXMLElement elementWithName:XMPPPresenceElementPhoto];
		[x addChild:photo];
	}
	[photo setStringValue:photoHash];
}
@end
