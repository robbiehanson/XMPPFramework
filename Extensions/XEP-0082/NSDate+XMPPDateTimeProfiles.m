//
//  NSDate+XMPPDateTimeProfiles.m
//
//  NSDate category to implement XEP-0082.
//
//  Created by Eric Chamberlain on 3/9/11.
//  Copyright 2011 RF.com. All rights reserved.
//  Copyright 2010 Martin Morrison. All rights reserved.
//

#import "NSDate+XMPPDateTimeProfiles.h"
#import "XMPPDateTimeProfiles.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

@interface NSDate(XMPPDateTimeProfilesPrivate)
- (NSString *)xmppStringWithDateFormat:(NSString *)dateFormat;
@end

#pragma mark -

@implementation NSDate(XMPPDateTimeProfiles)


#pragma mark Convert from XMPP string to NSDate


+ (NSDate *)dateWithXmppDateString:(NSString *)str {
  return [XMPPDateTimeProfiles parseDate:str];
}


+ (NSDate *)dateWithXmppTimeString:(NSString *)str {
  return [XMPPDateTimeProfiles parseTime:str];
}


+ (NSDate *)dateWithXmppDateTimeString:(NSString *)str {
  return [XMPPDateTimeProfiles parseDateTime:str];
}


#pragma mark Convert from NSDate to XMPP string


- (NSString *)xmppDateString {	
	return [self xmppStringWithDateFormat:@"yyyy-MM-dd"];
}


- (NSString *)xmppTimeString {
	return [self xmppStringWithDateFormat:@"HH:mm:ss'Z'"];
}


- (NSString *)xmppDateTimeString {
	return [self xmppStringWithDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
}


#pragma mark XMPPDateTimeProfilesPrivate methods


- (NSString *)xmppStringWithDateFormat:(NSString *)dateFormat
{
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
    [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
	[dateFormatter setDateFormat:dateFormat];
	[dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
	
	NSString *str = [dateFormatter stringFromDate:self];
	
	return str;
}


@end
