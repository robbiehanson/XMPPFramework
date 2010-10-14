//
//  XMPPStreamFacebook.m
//
//  Created by Eric Chamberlain on 10/13/10.
//  Copyright 2010 RF.com. All rights reserved.
//

#import "XMPPStreamFacebook.h"

#import "AsyncSocket.h"
#import "DDLog.h"
#import "NSDataAdditions.h"
#import "NSXMLElementAdditions.h"

@interface XMPPXFacebookPlatformAuthentication : NSObject
{
    NSString *nonce;
    NSString *method;
    NSString *accessToken;
    NSString *sessionSecret;
}

@property (nonatomic,copy) NSString *accessToken;
@property (nonatomic,copy) NSString *sessionSecret;
@property (nonatomic,copy) NSString *nonce;
@property (nonatomic,copy) NSString *method;

@property (nonatomic,retain,readonly) NSString *appId;
@property (nonatomic,retain,readonly) NSString *sessionKey;


- (id)initWithChallenge:(NSXMLElement *)challenge;

- (NSString *)base64EncodedFullResponse;

@end 


@implementation XMPPStreamFacebook

- (void)dealloc {
    [facebook release];
    [super dealloc];
}

#pragma mark -
#pragma mark Public class methods

+ (NSArray *)permissions {
    return [NSArray arrayWithObjects:  
            @"offline_access", 
            @"xmpp_login",
            nil];
}

#pragma mark -
#pragma mark Public instance methods

/**
 * This method attemts to sign-in to Facebook using the access token.
 **/
- (BOOL)authenticateWithAccessToken:(NSString *)accessToken error:(NSError **)errPtr {
    // hard coding expiration date, because we use offline_access in the permissions
    return [self authenticateWithAccessToken:accessToken expirationDate:[NSDate distantFuture] error:errPtr];
}

- (BOOL)authenticateWithAccessToken:(NSString *)accessToken expirationDate:(NSDate *)expirationDate error:(NSError **)errPtr {
	if (state != STATE_CONNECTED)
	{
		if (errPtr)
		{
			NSString *errMsg = @"Please wait until the stream is connected.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			*errPtr = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
		}
		return NO;
	}
    
    if (![self supportsXFacebookPlatform])
	{
		if (errPtr)
		{
			NSString *errMsg = @"The server does not support X-FACEBOOK-PLATFORM authentication.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			*errPtr = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamUnsupportedAction userInfo:info];
			
		}
		return NO;
	}
    
    if (accessToken == nil || expirationDate == nil)
	{
		if (errPtr)
		{
			NSString *errMsg = @"You must get the facebook accessToken and expirationDate before calling authenticateWithAccessToken:expirationDate:error:.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			*errPtr = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidProperty userInfo:info];
		}
		return NO;
	}
    
    self.facebook = [[[Facebook alloc] init] autorelease];
    self.facebook.accessToken = accessToken; 
    self.facebook.expirationDate = expirationDate;
    
    [self.facebook requestWithMethodName:@"auth.promoteSession" 
                               andParams:[NSMutableDictionary dictionaryWithCapacity:3] 
                           andHttpMethod:@"GET" 
                             andDelegate:self]; 
    return YES;
}

- (BOOL)authenticateWithPassword:(NSString *)password error:(NSError **)errPtr {
	if (state != STATE_CONNECTED)
	{
		if (errPtr)
		{
			NSString *errMsg = @"Please wait until the stream is connected.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			*errPtr = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
		}
		return NO;
	}
    
	if (self.facebook != nil && [self supportsXFacebookPlatform]) {
		NSString *auth = @"<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' mechanism='X-FACEBOOK-PLATFORM'/>";
		
		NSData *outgoingData = [auth dataUsingEncoding:NSUTF8StringEncoding];
		
		DDLogSend(@"SEND: %@", auth);
		numberOfBytesSent += [outgoingData length];
		
		[asyncSocket writeData:outgoingData
				   withTimeout:TIMEOUT_WRITE
						   tag:TAG_WRITE_STREAM];
		
		// Save authentication information
		[tempPassword release];
		tempPassword = [password copy];
		
		// Update state
		state = STATE_AUTH_1;
        return YES;
	} else {
        return [super authenticateWithPassword:password error:errPtr];
    }
}

/**
 * This method checks the stream features of the connected server to
 determine if X-FACEBOOK-PLATFORM authentication is supported.
 * If we are not connected to a server, this method simply returns NO.
 *
 * This is the preferred authentication technique, and will be used if
 the server supports it.
 **/
- (BOOL)supportsXFacebookPlatform
{
	//return NO;
	// The root element can be properly queried for authentication mechanisms anytime after the
	// stream:features are received, and TLS has been setup (if required)
	if (state > STATE_STARTTLS)
	{
		NSXMLElement *features = [rootElement
								  elementForName:@"stream:features"];
		NSXMLElement *mech = [features elementForName:@"mechanisms"
												xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
		
		NSArray *mechanisms = [mech elementsForName:@"mechanism"];
		
		for (NSXMLElement *mechanism in mechanisms)
		{
			if ([[mechanism stringValue] isEqualToString:@"X-FACEBOOK-PLATFORM"])
			{
				return YES;
			}
		}
	}
	return NO; 
}

#pragma mark -
#pragma mark Private instance methods

- (void)handleAuth1:(NSXMLElement *)response
{
	if (self.facebook != nil && [self supportsXFacebookPlatform]) {
		DDLogSend(@"SEND: X-FACEBOOK-PLATFORM");
		if(![[response name] isEqualToString:@"challenge"])
		{
			// Revert back to connected state (from authenticating state)
			state = STATE_CONNECTED;
			
			[multicastDelegate xmppStream:self didNotAuthenticate:response];
		}
		else
		{
			XMPPXFacebookPlatformAuthentication *auth = [[XMPPXFacebookPlatformAuthentication alloc] initWithChallenge:response];
            
            [auth setAccessToken:facebook.accessToken];
            [auth setSessionSecret:tempPassword];
			
			// Create and send challenge response element
			NSXMLElement *cr = [NSXMLElement elementWithName:@"response" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
			[cr setStringValue:[auth base64EncodedFullResponse]];
			
			NSString *outgoingStr = [cr compactXMLString];
			NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
			
			DDLogSend(@"SEND: %@", outgoingStr);
			numberOfBytesSent += [outgoingData length];
			
			[asyncSocket writeData:outgoingData
					   withTimeout:TIMEOUT_WRITE
							   tag:TAG_WRITE_STREAM];
			
            // Release unneeded resources
			[auth release];
			[tempPassword release]; tempPassword = nil;
            
			// Update state
			state = STATE_AUTH_3;
		}
	} else {
        [super handleAuth1:response];
    }
}    

#pragma mark -
#pragma mark FBRequestDelegate

/**
 * Called when an error prevents the request from completing successfully.
 */
- (void)request:(FBRequest*)request didFailWithError:(NSError*)error{
    
    // Revert back to connected state (from authenticating state)
    state = STATE_CONNECTED;
    
    [multicastDelegate xmppStream:self didNotAuthenticate:nil];
}

/**
 * Called when a request returns and its response has been parsed into an object.
 * The resulting object may be a dictionary, an array, a string, or a number, depending
 * on thee format of the API response.
 */
- (void)request:(FBRequest*)request didLoad:(id)result {
    if ([result isKindOfClass:[NSData class]]) {
        NSString *resultStr = [[[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding] autorelease];
        
        // finish authenticating
        NSError *error;
        if (![self authenticateWithPassword:[resultStr stringByReplacingOccurrencesOfString:@"\"" 
                                                                                 withString:@""] error:&error]) {
            NSLog(@"authenticateWithPassword: %@ error: %@",resultStr,error);
            
            // Revert back to connected state (from authenticating state)
            state = STATE_CONNECTED;
            
            [multicastDelegate xmppStream:self didNotAuthenticate:nil];
        }        
    }
}

#pragma mark -
#pragma mark Getters/setters

@synthesize facebook;   

@end

@implementation XMPPXFacebookPlatformAuthentication

- (id)initWithChallenge:(NSXMLElement *)challenge
{
    if(self = [super init])
    {
		// Convert the base 64 encoded data into a string
		NSData *base64Data = [[challenge stringValue]
							  dataUsingEncoding:NSASCIIStringEncoding];
		NSData *decodedData = [base64Data base64Decoded];
		
        NSString *authStr = [[[NSString alloc] initWithData:decodedData 
                                                   encoding:NSUTF8StringEncoding] autorelease];
		
        DDLogVerbose(@"decoded challenge: %@", authStr);
		
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
    [accessToken release];
    [nonce release];
    [method release];
    [sessionSecret release];
    
	[super dealloc];
}

- (NSString *)base64EncodedFullResponse
{
    if (self.accessToken == nil || 
        self.sessionSecret == nil || 
        self.method == nil || 
        self.nonce == nil) {
        return nil;
    }
    
	srand([[NSDate date] timeIntervalSince1970]);
	
    NSMutableString *buffer = [NSMutableString stringWithCapacity:250];
	[buffer appendFormat:@"api_key=%@&", self.appId];
    [buffer appendFormat:@"call_id=%d&", rand()];
	[buffer appendFormat:@"method=%@&", self.method];
	[buffer appendFormat:@"nonce=%@&", self.nonce];
	[buffer appendFormat:@"session_key=%@&", self.sessionKey];
    [buffer appendFormat:@"v=%@&",@"1.0"];
	
    // Make the "sig" hash
    NSString* sig = [buffer stringByReplacingOccurrencesOfString:@"&"
													  withString:@""];
    
    sig = [sig stringByAppendingString:self.sessionSecret];
	
    NSString* sigMD5 =  [[[sig dataUsingEncoding:NSUTF8StringEncoding] md5Digest] hexStringValue];
    [buffer appendFormat:@"sig=%@", sigMD5];
	
    DDLogVerbose(@"sig for facebook: %@", sig);
    DDLogVerbose(@"response for facebook: %@", buffer);
	
    NSData *utf8data = [buffer dataUsingEncoding:NSUTF8StringEncoding];
	
    return [utf8data base64Encoded];
}

@synthesize nonce;
@synthesize method;
@synthesize accessToken;
@synthesize sessionSecret;

- (NSString *)appId {
    NSArray *parts = [self.accessToken componentsSeparatedByString:@"|"];
    if ([parts count] < 3) {
        return nil;
    }
    return [parts objectAtIndex:0];    
}

- (NSString *)sessionKey {
    NSArray *parts = [self.accessToken componentsSeparatedByString:@"|"];
    if ([parts count] < 3) {
        return nil;
    }
    return [parts objectAtIndex:1];
}

@end 
