//
//  JAHConvertSDP.h
//  JAHConvertSDP
//
//  Created by Jon Hjelle on 5/16/14.
//  Copyright (c) 2014 Jon Hjelle. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JAHConvertSDP : NSObject

+ (NSDictionary*)dictionaryForSDP:(NSString*)sdp withCreatorRole:(NSString*)creator;
+ (NSString*)SDPForSession:(NSDictionary*)session sid:(NSString*)sid time:(NSString*)time;
+ (NSDictionary*)candidateForLine:(NSString*)line;
+ (NSString*)sdpForCandidate:(NSDictionary*)candidate ;
@end
