//
//  NSDate+XMPPDateTimeProfiles.h
//
//  NSDate category to implement XEP-0082.
//
//  Created by Eric Chamberlain on 3/9/11.
//  Copyright 2011 RF.com. All rights reserved.
//  Copyright 2010 Martin Morrison. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface NSDate(XMPPDateTimeProfiles)

+ (nullable NSDate *)dateWithXmppDateString:(NSString *)str;
+ (nullable NSDate *)dateWithXmppTimeString:(NSString *)str;
+ (nullable NSDate *)dateWithXmppDateTimeString:(NSString *)str;

@property (nonatomic, readonly) NSString *xmppDateString;
@property (nonatomic, readonly) NSString *xmppTimeString;
@property (nonatomic, readonly) NSString *xmppDateTimeString;

@end
NS_ASSUME_NONNULL_END
