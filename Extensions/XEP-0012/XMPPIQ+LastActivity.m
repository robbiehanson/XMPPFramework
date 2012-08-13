//
//  XMPPIQ+LastActivity.m
//  ArgelaIMPS
//
//  Created by Tolga Tanriverdi on 8/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "XMPPIQ+LastActivity.h"
#import "NSXMLElement+XMPP.h"
#import "XMPPJID.h"
#import "XMPPStream.h"

@implementation XMPPIQ (LastActivity)

+(XMPPIQ*) queryLastActivityOf:(XMPPJID *)jid
{
    XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:jid elementID:[XMPPStream generateUUID]];
    [iq addChild:[self elementLastActivity]];
    return iq;
}

+(NSXMLElement *)elementLastActivity {
	return [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:last"];
}

-(BOOL) hasLastActivity
{
    if (![[self type] isEqualToString:@"result"]) {
        return NO;
    }
    
    if ([self elementForName:@"error"]) {
        return NO;
    }
    
    return ([self elementForName:@"query" xmlns:@"jabber:iq:last"] != nil);
}


-(NSDate*)lastActivityTime
{
    NSXMLElement *activityElement = [self elementForName:@"query"];
    int lastLogoutTime = [activityElement attributeIntValueForName:@"seconds"];
    NSLog(@"Last Logout Time: %d Seconds Left",lastLogoutTime);
    
    
    NSDate *result = [NSDate date];
    
    result = [result dateByAddingTimeInterval:(lastLogoutTime*-1)];
    
    return result;
}

-(NSString*) lastActivityFrom
{
    return [[self from] bare];
}

-(BOOL) hasStatusMessage
{
    NSXMLElement *activityElement = [self elementForName:@"query"];
    NSLog(@"Activity Message: %@",[self description]);
    if ([[activityElement stringValue] length]) {
        return YES;
    }
    
    return NO;
}

-(NSString*) statusMessage
{
    return [[self elementForName:@"query"] stringValue];
}

@end
