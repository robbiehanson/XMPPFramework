#import <Foundation/Foundation.h>

#import "NSDate+XMPPDateTimeProfiles.h"


@interface XMPPDateTimeProfiles : NSObject

+ (NSDate *)parseDate:(NSString *)dateStr;
+ (NSDate *)parseTime:(NSString *)timeStr;
+ (NSDate *)parseDateTime:(NSString *)dateTimeStr;

+ (NSTimeInterval)parseTimeZoneOffset:(NSString *)tzo;

@end
