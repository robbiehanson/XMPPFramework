#import <Foundation/Foundation.h>
#import "NSDate+XMPPDateTimeProfiles.h"

NS_ASSUME_NONNULL_BEGIN
@interface XMPPDateTimeProfiles : NSObject

/**
 * The following methods attempt to parse the given string following XEP-0082.
 * They return nil if the given string doesn't follow the spec.
**/

+ (nullable NSDate *)parseDate:(NSString *)dateStr;
+ (nullable NSDate *)parseTime:(NSString *)timeStr;
+ (nullable NSDate *)parseDateTime:(NSString *)dateTimeStr;

+ (nullable NSTimeZone *)parseTimeZoneOffset:(NSString *)tzo;

@end
NS_ASSUME_NONNULL_END
