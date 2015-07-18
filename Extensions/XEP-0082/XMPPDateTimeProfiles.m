#import "XMPPDateTimeProfiles.h"
#import "NSNumber+XMPP.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

static NSString * const kXEP0082SharedDateFormatterKey = @"xep0082_shared_date_formatter_key";

@interface XMPPDateTimeProfiles (PrivateAPI)
+ (NSDate *)parseDateTime:(NSString *)dateTimeStr withMandatoryTimeZone:(BOOL)mandatoryTZ;
@end


@implementation XMPPDateTimeProfiles

/**
 * The following acronyms and characters are used from XEP-0082 to represent time-related concepts:
 * 
 * CCYY	four-digit year portion of Date
 * MM	two-digit month portion of Date
 * DD	two-digit day portion of Date
 * -	ISO 8601 separator among Date portions
 * T	ISO 8601 separator between Date and Time
 * hh	two-digit hour portion of Time (00 through 23)
 * mm	two-digit minutes portion of Time (00 through 59)
 * ss	two-digit seconds portion of Time (00 through 59)
 * :	ISO 8601 separator among Time portions
 * .	ISO 8601 separator between seconds and milliseconds
 * sss	fractional second addendum to Time (MAY contain any number of digits)
 * TZD	Time Zone Definition (either "Z" for UTC or "(+|-)hh:mm" for a specific time zone)
 *
**/

+ (NSDate *)parseDate:(NSString *)dateStr
{
	if ([dateStr length] < 10) return nil;
	
	// The Date profile defines a date without including the time of day.
	// The lexical representation is as follows:
	// 
	// CCYY-MM-DD
	// 
	// Example:
	// 
	// 1776-07-04
	
	NSDateFormatter *df = [self threadDateFormatter];
	[df setFormatterBehavior:NSDateFormatterBehavior10_4]; // Use unicode patterns (as opposed to 10_3)
    [df setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
	[df setDateFormat:@"yyyy-MM-dd"];
	
	NSDate *result = [df dateFromString:dateStr];
	
	return result;
}

+ (NSDate *)parseTime:(NSString *)timeStr
{
	// The Time profile is used to specify an instant of time that recurs (e.g., every day).
	// The lexical representation is as follows:
	// 
	// hh:mm:ss[.sss][TZD]
	// 
	// The Time Zone Definition is optional; if included, it MUST be either UTC (denoted by addition
	// of the character 'Z' to the end of the string) or some offset from UTC (denoted by addition
	// of '[+|-]' and 'hh:mm' to the end of the string).
	// 
	// Examples:
	// 
	// 16:00:00
	// 16:00:00Z
	// 16:00:00+07:00
	// 16:00:00.123
	// 16:00:00.123Z
	// 16:00:00.123+07:00
	
	
	// Extract the current day so the result can be on the current day.
	// Why do we bother doing this?
	// 
	// First, it is rather intuitive.
	// Second, if we don't we risk being on a date with a conflicting DST (daylight saving time).
	// 
	// For example, -0800 instead of the current -0700.
	// This can be rather confusing when printing the result.
	
	NSDateFormatter *df = [self threadDateFormatter];
	[df setFormatterBehavior:NSDateFormatterBehavior10_4]; // Use unicode patterns (as opposed to 10_3)
    [df setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
	[df setDateFormat:@"yyyy-MM-dd"];
	
	NSString *today = [df stringFromDate:[NSDate date]];
    
	NSString *dateTimeStr = [NSString stringWithFormat:@"%@T%@", today, timeStr];
	
	return [self parseDateTime:dateTimeStr withMandatoryTimeZone:NO];
}

+ (NSDate *)parseDateTime:(NSString *)dateTimeStr
{
	// The DateTime profile is used to specify a non-recurring moment in time to an accuracy of seconds (or,
	// optionally, fractions of a second). The format is as follows:
	// 
	// CCYY-MM-DDThh:mm:ss[.sss]TZD
	// 
	// The Time Zone Definition is mandatory and MUST be either UTC (denoted by addition of the character 'Z'
	// to the end of the string) or some offset from UTC (denoted by addition of '[+|-]' and 'hh:mm' to the
	// end of the string).
	// 
	// Examples:
	// 
	// 1969-07-21T02:56:15Z
	// 1969-07-20T21:56:15-05:00
	// 1969-07-21T02:56:15.123Z
	// 1969-07-20T21:56:15.123-05:00
	
	return [self parseDateTime:dateTimeStr withMandatoryTimeZone:YES];
}

+ (NSDate *)parseDateTime:(NSString *)dateTimeStr withMandatoryTimeZone:(BOOL)mandatoryTZ
{
	if ([dateTimeStr length] < 19) return nil;
	
	// The DateTime profile is used to specify a non-recurring moment in time to an accuracy of seconds (or,
	// optionally, fractions of a second). The format is as follows:
	// 
	// CCYY-MM-DDThh:mm:ss[.sss]{TZD}
	// 
	// Examples:
	// 
	// 1969-07-21T02:56:15
	// 1969-07-21T02:56:15Z
	// 1969-07-20T21:56:15-05:00
	// 1969-07-21T02:56:15.123
	// 1969-07-21T02:56:15.123Z
	// 1969-07-20T21:56:15.123-05:00
	
	BOOL hasMilliseconds = NO;
	BOOL hasTimeZoneInfo = NO;
	BOOL hasTimeZoneOffset = NO;
	NSInteger fractionalDigits = 0;
	
	if ([dateTimeStr length] > 19)
	{
		unichar c = [dateTimeStr characterAtIndex:19];
		
		// Check for optional milliseconds
		if (c == '.')
		{
			hasMilliseconds = YES;

			// At least one fractional digit?
			if ([dateTimeStr length] < 21) return nil;
		}
		
		// Check for optional time zone info, which is at the last char (Z), or the
		// char 6 chars from the end
		if ([dateTimeStr characterAtIndex:[dateTimeStr length] - 1] == 'Z')
		{
			hasTimeZoneInfo = YES;
			hasTimeZoneOffset = NO;
			if (hasMilliseconds)
			{
				// 1969-07-21T02:56:15.1234Z -> 25 - 1 - 20 = 4
				fractionalDigits = [dateTimeStr length] - 1 - 20;
			}
		}
		else
		{
			c = [dateTimeStr characterAtIndex:[dateTimeStr length] - 6];
			if (c == '+' || c == '-')
			{
				hasTimeZoneInfo = YES;
				hasTimeZoneOffset = YES;
				if (hasMilliseconds)
				{
					// 1969-07-21T02:56:15.1234+00:00 -> 30 - 6 - 20 = 4
					fractionalDigits = [dateTimeStr length] - 6 - 20;
				}
			}
			else if (hasMilliseconds)
			{
				// 1969-07-21T02:56:15.1234 -> 24 - 20 = 4
				fractionalDigits = [dateTimeStr length] - 20;
			}
		}
	}
	
	if (mandatoryTZ && !hasTimeZoneInfo) return nil;
	
	NSDateFormatter *df = [self threadDateFormatter];
	[df setFormatterBehavior:NSDateFormatterBehavior10_4]; // Use unicode patterns (as opposed to 10_3)
    [df setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
	[df setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss"];

	NSDate *result = nil;
	NSString *dateAndTime = [dateTimeStr substringToIndex:19];
	NSString *fraction = fractionalDigits != 0 ? [NSString stringWithFormat:@"0%@", [dateTimeStr substringWithRange:NSMakeRange(19, fractionalDigits + 1)]] : nil;

	if (hasTimeZoneInfo && !hasTimeZoneOffset)
	{
		[df setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
		result = [df dateFromString:dateAndTime];
	}
	else if (hasTimeZoneInfo && hasTimeZoneOffset)
	{
		NSString *timeZone = [dateTimeStr substringFromIndex:[dateTimeStr length] - 6];
		NSTimeZone *tz = [self parseTimeZoneOffset:timeZone];
		if (tz == nil)
		{
			result = nil;
		}
		else
		{
			[df setTimeZone:tz];
			result = [df dateFromString:dateAndTime];
		}
	}
	else
	{
		result = [df dateFromString:dateAndTime];
	}

	if (result && fraction)
	{
		static NSNumberFormatter *numberFormatter = nil;
		static dispatch_once_t onceToken;
		dispatch_once(&onceToken, ^{
			numberFormatter = [[NSNumberFormatter alloc] init];
			[numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
			[numberFormatter setDecimalSeparator:@"."];
		});

		NSTimeInterval fractionInterval = [[numberFormatter numberFromString:fraction] doubleValue];
		NSTimeInterval current = [result timeIntervalSinceReferenceDate];
		result = [NSDate dateWithTimeIntervalSinceReferenceDate:floor(current) + fractionInterval];
	}

	return result;
}

+ (NSTimeZone *)parseTimeZoneOffset:(NSString *)tzo
{
	// The tzo value is supposed to start with '+' or '-'.
	// Spec says: (+-)hh:mm
	// 
	// hh : two-digit hour portion (00 through 23)
	// mm : two-digit minutes portion (00 through 59)
	
	if ([tzo length] != 6)
	{
		return nil;
	}
	
	NSString *hoursStr   = [tzo substringWithRange:NSMakeRange(1, 2)];
	NSString *minutesStr = [tzo substringWithRange:NSMakeRange(4, 2)];
	
	NSUInteger hours;
	if (![NSNumber xmpp_parseString:hoursStr intoNSUInteger:&hours])
		return nil;
	
	NSUInteger minutes;
	if (![NSNumber xmpp_parseString:minutesStr intoNSUInteger:&minutes])
		return nil;
	
	if (hours > 23) return nil;
	if (minutes > 59) return nil;
	
	NSInteger secondsOffset = (NSInteger)((hours * 60 * 60) + (minutes * 60));
	
	if ([tzo hasPrefix:@"-"])
	{
		secondsOffset = -1 * secondsOffset;
	}
	else if (![tzo hasPrefix:@"+"])
	{
		return nil;
	}
	
	return [NSTimeZone timeZoneForSecondsFromGMT:secondsOffset];
}

+ (NSDateFormatter *)threadDateFormatter {
  NSMutableDictionary *currentThreadStorage = [[NSThread currentThread] threadDictionary];
  NSDateFormatter *sharedDateFormatter = currentThreadStorage[kXEP0082SharedDateFormatterKey];
  if (!sharedDateFormatter) {
    sharedDateFormatter = [NSDateFormatter new];
    currentThreadStorage[kXEP0082SharedDateFormatterKey] = sharedDateFormatter;
  }
  
  return sharedDateFormatter;
}

@end
