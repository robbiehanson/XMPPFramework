//
//  XMPPvCardTemp.m
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/9/11.
//  Copyright 2011 RF.com. All rights reserved.
//  Copyright 2010 Martin Morrison. All rights reserved.
//


#import "XMPPvCardTemp.h"
#import "XMPPLogging.h"
#import "XMPPDateTimeProfiles.h"
#import "NSData+XMPP.h"

#import <objc/runtime.h>

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_ERROR;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_ERROR;
#endif

NSString *const kXMPPNSvCardTemp = @"vcard-temp";
NSString *const kXMPPvCardTempElement = @"vCard";


@implementation XMPPvCardTemp

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
	size_t ourSize   = class_getInstanceSize([XMPPvCardTemp class]);
	
	if (superSize != ourSize)
	{
		XMPPLogError(@"Adding instance variables to XMPPvCardTemp is not currently supported!");
		
		[DDLog flushLog];
		exit(15);
	}
}

#endif

+ (XMPPvCardTemp *)vCardTempFromElement:(NSXMLElement *)elem {
	object_setClass(elem, [XMPPvCardTemp class]);
	
	return (XMPPvCardTemp *)elem;
}

+ (XMPPvCardTemp *)vCardTemp{
    NSXMLElement *vCardTempElement = [NSXMLElement elementWithName:kXMPPvCardTempElement xmlns:kXMPPNSvCardTemp];
    return [XMPPvCardTemp vCardTempFromElement:vCardTempElement];
}

+ (XMPPvCardTemp *)vCardTempSubElementFromIQ:(XMPPIQ *)iq
{
	if ([iq isResultIQ])
	{
		NSXMLElement *query = [iq elementForName:kXMPPvCardTempElement xmlns:kXMPPNSvCardTemp];
		if (query)
		{
			return [self vCardTempFromElement:query];
		}
	}
	
	return nil;
}

+ (XMPPvCardTemp *)vCardTempCopyFromIQ:(XMPPIQ *)iq
{
	return [[self vCardTempSubElementFromIQ:iq] copy];
}


+ (XMPPIQ *)iqvCardRequestForJID:(XMPPJID *)jid {
  XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:[jid bareJID] elementID:[XMPPStream generateUUID]];
  NSXMLElement *vCardElem = [NSXMLElement elementWithName:kXMPPvCardTempElement xmlns:kXMPPNSvCardTemp];
  
  [iq addChild:vCardElem];
  return iq;
}


#pragma mark -
#pragma mark Identification Types


- (NSDate *)bday {
	NSDate *bday = nil;
	NSXMLElement *elem = [self elementForName:@"BDAY"];
	
	if (elem != nil) {
		bday = [NSDate dateWithXmppDateString:[elem stringValue]];
	}
	
	return bday;
}


- (void)setBday:(NSDate *)bday {
	NSXMLElement *elem = [self elementForName:@"BDAY"];
  
	if (elem == nil) {
		elem = [NSXMLElement elementWithName:@"BDAY"];
		[self addChild:elem];
	}
	
	[elem setStringValue:[bday xmppDateString]];
}


- (NSData *)photo {
	NSData *decodedData = nil;
	NSXMLElement *photo = [self elementForName:@"PHOTO"];
	
	if (photo != nil) {
		// There is a PHOTO element. It should have a TYPE and a BINVAL
		//NSXMLElement *fileType = [photo elementForName:@"TYPE"];
		NSXMLElement *binval = [photo elementForName:@"BINVAL"];
		
		if (binval) {
			NSData *base64Data = [[binval stringValue] dataUsingEncoding:NSASCIIStringEncoding];
			decodedData = [base64Data xmpp_base64Decoded];
		}
	}
	
	return decodedData;
}


- (void)setPhoto:(NSData *)data {
    
    NSXMLElement *photo = [self elementForName:@"PHOTO"];
    
    if(photo)
    {
        [self removeChildAtIndex:[[self children] indexOfObject:photo]];
    }
    
    if([data length])
    {    
        NSXMLElement *photo = [NSXMLElement elementWithName:@"PHOTO"];
        [self addChild:photo];
        
        NSString *imageType = [data xmpp_imageType];
        
        if([imageType length])
        {
            NSXMLElement *type = [NSXMLElement elementWithName:@"TYPE"];
            [photo addChild:type];
            [type setStringValue:imageType];
        }
        
        NSXMLElement *binval = [NSXMLElement elementWithName:@"BINVAL"];
        [photo addChild:binval];
        [binval setStringValue:[data xmpp_base64Encoded]];
    }
}


- (NSString *)nickname {
	return [[self elementForName:@"NICKNAME"] stringValue];
}


- (void)setNickname:(NSString *)nick {
	XMPP_VCARD_SET_STRING_CHILD(nick, @"NICKNAME");
}


- (NSString *)formattedName {
	return [[self elementForName:@"FN"] stringValue];
}


- (void)setFormattedName:(NSString *)fn {
	XMPP_VCARD_SET_STRING_CHILD(fn, @"FN");
}


- (NSString *)familyName {
	NSString *result = nil;
	NSXMLElement *name = [self elementForName:@"N"];
	
	if (name != nil) {
		NSXMLElement *part = [name elementForName:@"FAMILY"];
		
		if (part != nil) {
			result = [part stringValue];
		}
	}
	
	return result;
}


- (void)setFamilyName:(NSString *)family {
	XMPP_VCARD_SET_N_CHILD(family, @"FAMILY");
}


- (NSString *)givenName {
	NSString *result = nil;
	NSXMLElement *name = [self elementForName:@"N"];
	
	if (name != nil) {
		NSXMLElement *part = [name elementForName:@"GIVEN"];
		
		if (part != nil) {
			result = [part stringValue];
		}
	}
	
	return result;
}


- (void)setGivenName:(NSString *)given {
	XMPP_VCARD_SET_N_CHILD(given, @"GIVEN");
}


- (NSString *)middleName {
	NSString *result = nil;
	NSXMLElement *name = [self elementForName:@"N"];
	
	if (name != nil) {
		NSXMLElement *part = [name elementForName:@"MIDDLE"];
		
		if (part != nil) {
			result = [part stringValue];
		}
	}
	
	return result;
}


- (void)setMiddleName:(NSString *)middle {
	XMPP_VCARD_SET_N_CHILD(middle, @"MIDDLE");
}


- (NSString *)prefix {
	NSString *result = nil;
	NSXMLElement *name = [self elementForName:@"N"];
	
	if (name != nil) {
		NSXMLElement *part = [name elementForName:@"PREFIX"];
		
		if (part != nil) {
			result = [part stringValue];
		}
	}
	
	return result;
}


- (void)setPrefix:(NSString *)prefix {
	XMPP_VCARD_SET_N_CHILD(prefix, @"PREFIX");
}


- (NSString *)suffix {
	NSString *result = nil;
	NSXMLElement *name = [self elementForName:@"N"];
	
	if (name != nil) {
		NSXMLElement *part = [name elementForName:@"SUFFIX"];
		
		if (part != nil) {
			result = [part stringValue];
		}
	}
	
	return result;
}


- (void)setSuffix:(NSString *)suffix {
	XMPP_VCARD_SET_N_CHILD(suffix, @"SUFFIX");
}


#pragma mark Delivery Addressing Types


- (NSArray *)addresses { return nil; }
- (void)addAddress:(XMPPvCardTempAdr *)adr { }
- (void)removeAddress:(XMPPvCardTempAdr *)adr { }
- (void)setAddresses:(NSArray *)adrs { }
- (void)clearAddresses { }


- (NSArray *)labels { return nil; }
- (void)addLabel:(XMPPvCardTempLabel *)label { }
- (void)removeLabel:(XMPPvCardTempLabel *)label { }
- (void)setLabels:(NSArray *)labels { }
- (void)clearLabels { }


- (NSArray *)telecomsAddresses { return nil; }
- (void)addTelecomsAddress:(XMPPvCardTempTel *)tel { }
- (void)removeTelecomsAddress:(XMPPvCardTempTel *)tel { }
- (void)setTelecomsAddresses:(NSArray *)tels { }
- (void)clearTelecomsAddresses { }


- (NSArray *)emailAddresses { return nil; }
- (void)addEmailAddress:(XMPPvCardTempEmail *)email { }
- (void)removeEmailAddress:(XMPPvCardTempEmail *)email { }
- (void)setEmailAddresses:(NSArray *)emails { }
- (void)clearEmailAddresses { }


- (XMPPJID *)jid {
	XMPPJID *jid = nil;
	NSXMLElement *elem = [self elementForName:@"JABBERID"];
	
	if (elem != nil) {
		jid = [XMPPJID jidWithString:[elem stringValue]];
	}
	
	return jid;
}


- (void)setJid:(XMPPJID *)jid {
	NSXMLElement *elem = [self elementForName:@"JABBERID"];
	
	if (elem == nil && jid != nil) {
		elem = [NSXMLElement elementWithName:@"JABBERID"];
		[self addChild:elem];
	}
	
	if (jid != nil) {
		[elem setStringValue:[jid full]];
	} else if (elem != nil) {
		[self removeChildAtIndex:[[self children] indexOfObject:elem]];
	}
}


- (NSString *)mailer {
	return [[self elementForName:@"MAILER"] stringValue];
}


- (void)setMailer:(NSString *)mailer {
	XMPP_VCARD_SET_STRING_CHILD(mailer, @"MAILER");
}


#pragma mark Geographical Types


- (NSTimeZone *)timeZone {
	// Turns out this is hard. Being lazy for now (not like anyone actually uses this, right?)
	NSXMLElement *tz = [self elementForName:@"TZ"];
	if (tz != nil) {
		// This is unlikely to work. :-(
		return [NSTimeZone timeZoneWithName:[tz stringValue]];
	} else {
		return nil;
	}
}


- (void)setTimeZone:(NSTimeZone *)tz {
	NSXMLElement *elem = [self elementForName:@"TZ"];
  
	if (elem == nil && tz != nil) {
		elem = [NSXMLElement elementWithName:@"TZ"];
		[self addChild:elem];
	}
	
	if (tz != nil) {
		NSInteger offset = [tz secondsFromGMT];
		[elem setStringValue:[NSString stringWithFormat:@"%02ld:%02ld",
							  (long)(offset / 3600), (long)((offset % 3600) / 60)]];
	} else if (elem != nil) {
		[self removeChildAtIndex:[[self children] indexOfObject:elem]];
	}
}


- (CLLocation *)location {
	CLLocation *loc = nil;
	NSXMLElement *geo = [self elementForName:@"GEO"];
	
	if (geo != nil) {
		NSXMLElement *lat = [geo elementForName:@"LAT"];
		NSXMLElement *lon = [geo elementForName:@"LON"];
		
		loc = [[CLLocation alloc] initWithLatitude:[[lat stringValue] doubleValue] longitude:[[lon stringValue] doubleValue]];
	}
	
	return loc;
}


- (void)setLocation:(CLLocation *)geo {
	NSXMLElement *elem = [self elementForName:@"GEO"];
	NSXMLElement *lat;
	NSXMLElement *lon;
	
	if (geo != nil) {
		CLLocationCoordinate2D coord = [geo coordinate];
		if (elem == nil) {
			elem = [NSXMLElement elementWithName:@"GEO"];
			[self addChild:elem];
      
			lat = [NSXMLElement elementWithName:@"LAT"];
			[elem addChild:lat];
			lon = [NSXMLElement elementWithName:@"LON"];
			[elem addChild:lon];
		} else {
			lat = [elem elementForName:@"LAT"];
			lon = [elem elementForName:@"LON"];
		}
    
		[lat setStringValue:[NSString stringWithFormat:@"%.6f", coord.latitude]];
		[lon setStringValue:[NSString stringWithFormat:@"%.6f", coord.longitude]];
	} else if (elem != nil) {
		[self removeChildAtIndex:[[self children] indexOfObject:elem]];
	}
}


#pragma mark Organizational Types


- (NSString *)title {
	return [[self elementForName:@"TITLE"] stringValue];
}


- (void)setTitle:(NSString *)title {
	XMPP_VCARD_SET_STRING_CHILD(title, @"TITLE");
}


- (NSString *)role {
	return [[self elementForName:@"ROLE"] stringValue];
}


- (void)setRole:(NSString *)role {
	XMPP_VCARD_SET_STRING_CHILD(role, @"ROLE");
}


- (NSData *)logo {
	NSData *decodedData = nil;
	NSXMLElement *logo = [self elementForName:@"LOGO"];
	
	if (logo != nil) {
		// There is a LOGO element. It should have a TYPE and a BINVAL
		//NSXMLElement *fileType = [photo elementForName:@"TYPE"];
		NSXMLElement *binval = [logo elementForName:@"BINVAL"];
		
		if (binval) {
			NSData *base64Data = [[binval stringValue] dataUsingEncoding:NSASCIIStringEncoding];
			decodedData = [base64Data xmpp_base64Decoded];
		}
	}
	
	return decodedData;
}


- (void)setLogo:(NSData *)data {
	NSXMLElement *logo = [self elementForName:@"LOGO"];
	
	if (logo == nil) {
		logo = [NSXMLElement elementWithName:@"LOGO"];
		[self addChild:logo];
	}
	
	NSXMLElement *binval = [logo elementForName:@"BINVAL"];
	
	if (binval == nil) {
		binval = [NSXMLElement elementWithName:@"BINVAL"];
		[logo addChild:binval];
	}
	
	[binval setStringValue:[data xmpp_base64Encoded]];
}


- (XMPPvCardTemp *)agent {
	XMPPvCardTemp *agent = nil;
	NSXMLElement *elem = [self elementForName:@"AGENT"];
	
	if (elem != nil) {
		agent = [XMPPvCardTemp vCardTempFromElement:elem];
	}
	
	return agent;
}


- (void)setAgent:(XMPPvCardTemp *)agent {
	NSXMLElement *elem = [self elementForName:@"AGENT"];
	
	if (elem != nil) {
		[self removeChildAtIndex:[[self children] indexOfObject:elem]];
	}
	
	if (agent != nil) {
		[self addChild:agent];
	}
}


- (NSString *)orgName {
	NSString *result = nil;
	NSXMLElement *org = [self elementForName:@"ORG"];
	
	if (org != nil) {
		NSXMLElement *orgname = [org elementForName:@"ORGNAME"];
		
		if (orgname != nil) {
			result = [orgname stringValue];
		}
	}
	
	return result;
}


- (void)setOrgName:(NSString *)orgname {
	NSXMLElement *org = [self elementForName:@"ORG"];
	NSXMLElement *elem = nil;
  
	if (orgname != nil) {
		if (org == nil) {
			org = [NSXMLElement elementWithName:@"ORG"];
			[self addChild:org];
		} else {
			elem = [org elementForName:@"ORGNAME"];
		}
		
		if (elem == nil) {
			elem = [NSXMLElement elementWithName:@"ORGNAME"];
			[org addChild:elem];
		}
		
		[elem setStringValue:orgname];
	} else if (org != nil) {
		// This implicitly removes all orgunits too, as per the spec
		[self removeChildAtIndex:[[self children] indexOfObject:org]];
	}
}


- (NSArray *)orgUnits {
	NSArray *result = nil;
	NSXMLElement *org = [self elementForName:@"ORG"];
	
	if (org != nil) {
		NSArray *elems = [org elementsForName:@"ORGUNIT"];
		NSMutableArray *arr = [[NSMutableArray alloc] initWithCapacity:[elems count]];
		
		for (NSXMLElement *elem in elems) {
			[arr addObject:[elem stringValue]];
		}
		
		result = [NSArray arrayWithArray:arr];
	}
	
	return result;
}


- (void)setOrgUnits:(NSArray *)orgunits {
	NSXMLElement *org = [self elementForName:@"ORG"];
	
	// If there is no org, then there is nothing to do (need ORGNAME first)
	if (org != nil) {
		NSArray *elems = [org elementsForName:@"ORGUNIT"];
		for (NSXMLElement *elem in elems) {
			[org removeChildAtIndex:[[org children] indexOfObject:elem]];
		}
		
		for (NSString *unit in orgunits) {
			NSXMLElement *elem = [NSXMLElement elementWithName:@"ORGUNIT"];
			[elem setStringValue:unit];
			
			[org addChild:elem];
		}
	}
}


#pragma mark Explanatory Types


- (NSArray *)categories {
	NSArray *result = nil;
	NSXMLElement *categories = [self elementForName:@"CATEGORIES"];
	
	if (categories != nil) {
		NSArray *elems = [categories elementsForName:@"KEYWORD"];
		NSMutableArray *arr = [[NSMutableArray alloc] initWithCapacity:[elems count]];
		
		for (NSXMLElement *elem in elems) {
			[arr addObject:[elem stringValue]];
		}
		
		result = [NSArray arrayWithArray:arr];
	}
	
	return result;
}


- (void)setCategories:(NSArray *)categories {
	NSXMLElement *cat = [self elementForName:@"CATEGORIES"];
	
	if (categories != nil) {
		if (cat == nil) {
			cat = [NSXMLElement elementWithName:@"CATEGORIES"];
			[self addChild:cat];
		}
		
		NSArray *elems = [cat elementsForName:@"KEYWORD"];
		for (NSXMLElement *elem in elems) {
			[cat removeChildAtIndex:[[cat children] indexOfObject:elem]];
		}
		
		for (NSString *kw in categories) {
			NSXMLElement *elem = [NSXMLElement elementWithName:@"KEYWORD"];
			[elem setStringValue:kw];
			
			[cat addChild:elem];
		}
	} else if (cat != nil) {
		[self removeChildAtIndex:[[self children] indexOfObject:cat]];
	}
}


- (NSString *)note {
	return [[self elementForName:@"NOTE"] stringValue];
}


- (void)setNote:(NSString *)note {
	XMPP_VCARD_SET_STRING_CHILD(note, @"NOTE");
}


- (NSString *)prodid {
	return [[self elementForName:@"PRODID"] stringValue];
}


- (void)setProdid:(NSString *)prodid {
	XMPP_VCARD_SET_STRING_CHILD(prodid, @"PRODID");
}


- (NSDate *)revision {
	NSDate *rev = nil;
	NSXMLElement *elem = [self elementForName:@"REV"];
	
	if (elem != nil) {
		rev = [NSDate dateWithXmppDateTimeString:[elem stringValue]];
	}
	
	return rev;
}


- (void)setRevision:(NSDate *)rev {
	NSXMLElement *elem = [self elementForName:@"REV"];
	
	if (elem == nil) {
		elem = [NSXMLElement elementWithName:@"REV"];
		[self addChild:elem];
	}
	
	[elem setStringValue:[rev xmppDateTimeString]];
}


- (NSString *)sortString {
	return [[self elementForName:@"SORT-STRING"] stringValue];
}
- (void)setSortString:(NSString *)sortString {
	XMPP_VCARD_SET_STRING_CHILD(sortString, @"SORT-STRING");
}


- (NSString *)phoneticSound {
	NSString *phon = nil;
	NSXMLElement *sound = [self elementForName:@"SOUND"];
	
	if (sound != nil) {
		NSXMLElement *elem = [sound elementForName:@"PHONETIC"];
		
		if (elem != nil) {
			phon = [elem stringValue];
		}
	}
	
	return phon;
}


- (void)setPhoneticSound:(NSString *)phonetic {
	NSXMLElement *sound = [self elementForName:@"SOUND"];
	NSXMLElement *elem = nil;
	
	if (sound == nil && phonetic != nil) {
		sound = [NSXMLElement elementWithName:@"SOUND"];
		[self addChild:sound];
	}
	
	if (sound != nil) {
		elem = [sound elementForName:@"PHONETIC"];
		
		if (elem != nil && phonetic != nil) {
			elem = [NSXMLElement elementWithName:@"PHONETIC"];
			[sound addChild:elem];
		}
	}
	
	if (phonetic != nil) {
		[elem setStringValue:phonetic];
	} else if (sound != nil) {
		[self removeChildAtIndex:[[self children] indexOfObject:phonetic]];
	}
}


- (NSData *)sound {
	NSData *decodedData = nil;
	NSXMLElement *sound = [self elementForName:@"SOUND"];
	
	if (sound != nil) {
		NSXMLElement *binval = [sound elementForName:@"BINVAL"];
		
		if (binval) {
			NSData *base64Data = [[binval stringValue] dataUsingEncoding:NSASCIIStringEncoding];
			decodedData = [base64Data xmpp_base64Decoded];
		}
	}
	
	return decodedData;
}


- (void)setSound:(NSData *)data {
	NSXMLElement *sound = [self elementForName:@"SOUND"];
	
	if (sound == nil) {
		sound = [NSXMLElement elementWithName:@"SOUND"];
		[self addChild:sound];
	}
	
	NSXMLElement *binval = [sound elementForName:@"BINVAL"];
	
	if (binval == nil) {
		binval = [NSXMLElement elementWithName:@"BINVAL"];
		[sound addChild:binval];
	}
	
	[binval setStringValue:[data xmpp_base64Encoded]];
}


- (NSString *)uid {
	return [[self elementForName:@"UID"] stringValue];
}


- (void)setUid:(NSString *)uid {
	XMPP_VCARD_SET_STRING_CHILD(uid, @"UID");
}


- (NSString *)url {
	return [[self elementForName:@"URL"] stringValue];
}


- (void)setUrl:(NSString *)url {
	XMPP_VCARD_SET_STRING_CHILD(url, @"URL");
}


- (NSString *)version {
	return [self attributeStringValueForName:@"version"];
}


- (void)setVersion:(NSString *)version {
	[self addAttributeWithName:@"version" stringValue:version];
}


- (NSString *)desc {
	return [[self elementForName:@"DESC"] stringValue];
}


- (void)setDesc:(NSString *)desc {
	XMPP_VCARD_SET_STRING_CHILD(desc, @"DESC");
}


#pragma mark Security Types


- (XMPPvCardTempClass)privacyClass {
	XMPPvCardTempClass priv = XMPPvCardTempClassNone;
	NSXMLElement *elem = [self elementForName:@"CLASS"];
	
	if (elem != nil) {
		if ([elem elementForName:@"PUBLIC"] != nil) {
			priv = XMPPvCardTempClassPublic;
		} else if ([elem elementForName:@"PRIVATE"] != nil) {
			priv = XMPPvCardTempClassPrivate;
		} else if ([elem elementForName:@"CONFIDENTIAL"] != nil) {
			priv = XMPPvCardTempClassConfidential;
		}
	}
	
	return priv;
}


- (void)setPrivacyClass:(XMPPvCardTempClass)privacyClass {
	NSXMLElement *elem = [self elementForName:@"CLASS"];
  
	if (elem == nil && privacyClass != XMPPvCardTempClassNone) {
		elem = [NSXMLElement elementWithName:@"CLASS"];
	}
	
	if (elem != nil) {
		for (NSString *cls in [NSArray arrayWithObjects:@"PUBLIC", @"PRIVATE", @"CONFIDENTIAL", nil]) {
			NSXMLElement *priv = [elem elementForName:cls];
			if (priv != nil) {
				[elem removeChildAtIndex:[[elem children] indexOfObject:priv]];
			}
		}
		
		switch (privacyClass) {
			case XMPPvCardTempClassPublic:
				[elem addChild:[NSXMLElement elementWithName:@"PUBLIC"]];
				break;
			case XMPPvCardTempClassPrivate:
				[elem addChild:[NSXMLElement elementWithName:@"PRIVATE"]];
				break;
			case XMPPvCardTempClassConfidential:
				[elem addChild:[NSXMLElement elementWithName:@"CONFIDENTIAL"]];
				break;
			default:
			case XMPPvCardTempClassNone:
				// Remove the whole element
				[self removeChildAtIndex:[[self children] indexOfObject:elem]];
				break;
		}
	}
}


- (NSData *)key { return nil; }
- (void)setKey:(NSData *)key { }


- (NSString *)keyType {
	NSString *typ = nil;
	NSXMLElement *key = [self elementForName:@"KEY"];
	
	if (key != nil) {
		NSXMLElement *elem = [key elementForName:@"TYPE"];
		
		if (elem != nil) {
			typ = [elem stringValue];
		}
	}
	
	return typ;
}


- (void)setKeyType:(NSString *)type {
	NSXMLElement *key = [self elementForName:@"KEY"];
	NSXMLElement *elem = nil;
	
	if (key == nil && type != nil) {
		key = [NSXMLElement elementWithName:@"KEY"];
		[self addChild:key];
	}
	
	if (key != nil) {
		elem = [key elementForName:@"TYPE"];
		
		if (elem != nil && type != nil) {
			elem = [NSXMLElement elementWithName:@"TYPE"];
			[key addChild:elem];
		}
	}
	
	if (type != nil) {
		[elem setStringValue:type];
	} else if (key != nil) {
		[self removeChildAtIndex:[[self children] indexOfObject:key]];
	}
}


@end
