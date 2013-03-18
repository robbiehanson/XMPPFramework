#import <Foundation/Foundation.h>
#import "NSDate+XMPPDateTimeProfiles.h"

@interface XMPPDateTimeProfiles : NSObject

/**
 * The following methods attempt to parse the given string following XEP-0082.
 * They return nil if the given string doesn't follow the spec.
**/

+ (NSDate *)parseDate:(NSString *)dateStr;
+ (NSDate *)parseTime:(NSString *)timeStr;
+ (NSDate *)parseDateTime:(NSString *)dateTimeStr;

+ (NSTimeZone *)parseTimeZoneOffset:(NSString *)tzo;

@end
