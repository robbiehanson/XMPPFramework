//
//  XMPPXFacebookPlatformAuthentication.m
//  iPhoneXMPP
//
//  Created by Eric Chamberlain on 10/1/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "XMPPXFacebookPlatformAuthentication.h"

#import "NSData+XMPP.h"
#import "XMPPLogging.h"
#import "XMPPStream.h"

// Log levels: off, error, warn, info, verbose
#if DEBUG
    static const int xmppLogLevel = XMPP_LOG_LEVEL_INFO | XMPP_LOG_FLAG_SEND_RECV; // | XMPP_LOG_FLAG_TRACE;
#else
    static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

@implementation XMPPXFacebookPlatformAuthentication

- (id)initWithChallenge:(NSXMLElement *)challenge appId:(NSString *)aAppId accessToken:(NSString *)aAccessToken
{
    if ((self = [super init]))
    {
        self.appId = aAppId;
        self.accessToken = aAccessToken;

        // Convert the base 64 encoded data into a string
        NSData *base64Data = [[challenge stringValue] dataUsingEncoding:NSASCIIStringEncoding];
        NSData *decodedData = [base64Data base64Decoded];
            
        NSString *authStr = [[[NSString alloc] initWithData:decodedData 
                                                   encoding:NSUTF8StringEncoding] autorelease];
            
        XMPPLogVerbose(@"XMPPXFacebookPlatformAuthentication: decoded challenge: %@", authStr);
            
        // Extract all the key=value pairs, and put them in a dictionary for easy lookup
        NSMutableDictionary *auth = [NSMutableDictionary dictionaryWithCapacity:3];
            
        NSArray *components = [authStr componentsSeparatedByString:@"&"];
            
        int i;
        for(i = 0; i < [components count]; i++)
        {
            NSString *component = [components objectAtIndex:i];
                
            NSRange separator = [component rangeOfString:@"="];
            if(separator.location != NSNotFound)
            {
                NSString *key = [[component substringToIndex:separator.location] 
                                 stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                NSString *value = [[component substringFromIndex:separator.location+1]
                                   stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    
            if([value hasPrefix:@"\""] && 
               [value hasSuffix:@"\""] && 
               [value length] > 2)
            {
                // Strip quotes from value
                value = [value substringWithRange:NSMakeRange(1,([value length]-2))];
            }
                    
            [auth setObject:value forKey:key];
          }
        }
            
        // Extract and retain the elements we need
        self.nonce = [auth objectForKey:@"nonce"];
        self.method = [auth objectForKey:@"method"];
    }
    return self;
}

- (void)dealloc
{
    [appId release];
    [accessToken release];
    [nonce release];
    [method release];
	[super dealloc];
}

- (NSString *)base64EncodedFullResponse
{
    if (self.appId == nil || 
        self.accessToken == nil || 
        self.method == nil || 
        self.nonce == nil)
    {
        return nil;
    }

    srand([[NSDate date] timeIntervalSince1970]);

    NSMutableString *buffer = [NSMutableString stringWithCapacity:250];
    [buffer appendFormat:@"method=%@&", self.method];
    [buffer appendFormat:@"nonce=%@&", self.nonce];
    [buffer appendFormat:@"access_token=%@&", self.accessToken];
    [buffer appendFormat:@"api_key=%@&", self.appId];
    [buffer appendFormat:@"call_id=%d&", rand()];
    [buffer appendFormat:@"v=%@",@"1.0"];

    XMPPLogVerbose(@"XMPPXFacebookPlatformAuthentication: response for facebook: %@", buffer);

    NSData *utf8data = [buffer dataUsingEncoding:NSUTF8StringEncoding];

    return [utf8data base64Encoded];
}

@synthesize appId;
@synthesize accessToken;
@synthesize nonce;
@synthesize method;

@end 
