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

@interface NSDate(XMPPDateTimeProfiles)


+ (NSDate *)dateWithXmppDateString:(NSString *)str;
+ (NSDate *)dateWithXmppTimeString:(NSString *)str;
+ (NSDate *)dateWithXmppDateTimeString:(NSString *)str;


- (NSString *)xmppDateString;
- (NSString *)xmppTimeString;
- (NSString *)xmppDateTimeString;


@end
