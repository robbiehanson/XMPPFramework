#import <Foundation/Foundation.h>


@interface XMPPDateTimeProfiles : NSObject

+ (NSDate *)parseDate:(NSString *)dateStr;
+ (NSDate *)parseTime:(NSString *)timeStr;
+ (NSDate *)parseDateTime:(NSString *)dateTimeStr;

+ (NSTimeInterval)parseTimeZoneOffset:(NSString *)tzo;

@end
