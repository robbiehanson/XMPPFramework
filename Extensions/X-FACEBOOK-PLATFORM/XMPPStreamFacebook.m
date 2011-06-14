//
//  XMPPStreamFacebook.m
//
//  Created by Eric Chamberlain on 10/13/10.
//  Copyright 2010 RF.com. All rights reserved.
//

#import "XMPPStreamFacebook.h"
#import "XMPPInternal.h"
#import "XMPPLogging.h"
#import "GCDAsyncSocket.h"
#import "NSData+XMPP.h"
#import "NSXMLElement+XMPP.h"

/**
 * Seeing a return statements within an inner block
 * can sometimes be mistaken for a return point of the enclosing method.
 * This makes inline blocks a bit easier to read.
**/
#define return_from_block  return

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_INFO | XMPP_LOG_FLAG_SEND_RECV; // | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARNING | XMPP_LOG_FLAG_SEND_RECV;
#endif


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

#pragma mark -

@implementation XMPPStreamFacebook

@dynamic facebook;

- (Facebook *)facebook
{
	if (dispatch_get_current_queue() == xmppQueue)
	{
		return facebook;
	}
	else
	{
		__block Facebook *result;
		
		dispatch_sync(xmppQueue, ^{
			result = [facebook retain];
		});
		
		return [result autorelease];
	}
}

- (void)setFacebook:(Facebook *)newFacebook
{
	dispatch_block_t block = ^{
		
		if (facebook != newFacebook)
		{
			[facebook release];
			facebook = [newFacebook retain];
		}
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_async(xmppQueue, block);
}

- (void)dealloc
{
	[facebook release];
	[super dealloc];
}

#pragma mark Public class methods

+ (NSArray *)permissions
{
	return [NSArray arrayWithObjects:@"offline_access", @"xmpp_login", nil];
}

#pragma mark Public instance methods

/**
 * This method checks the stream features of the connected server to
 * determine if X-FACEBOOK-PLATFORM authentication is supported.
 * If we are not connected to a server, this method simply returns NO.
 *
 * This is the preferred authentication technique, and will be used if
 * the server supports it.
**/
- (BOOL)supportsXFacebookPlatform
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		
		// The root element can be properly queried for authentication mechanisms anytime after the
		// stream:features are received, and TLS has been setup (if required)
		if (state >= STATE_XMPP_POST_NEGOTIATION)
		{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			NSXMLElement *features = [rootElement elementForName:@"stream:features"];
			NSXMLElement *mech = [features elementForName:@"mechanisms" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
			
			NSArray *mechanisms = [mech elementsForName:@"mechanism"];
			
			for (NSXMLElement *mechanism in mechanisms)
			{
				if ([[mechanism stringValue] isEqualToString:@"X-FACEBOOK-PLATFORM"])
				{
					result = YES;
					break;
				}
			}
			
			[pool drain];
		}
	};
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	return result;
}

/**
 * This method attemts to sign-in to Facebook using the access token.
**/
- (BOOL)authenticateWithAppId:(NSString *)appId 
                  accessToken:(NSString *)accessToken 
                        error:(NSError **)errPtr
{
	// Hard coding expiration date, because we use offline_access in the permissions
	return [self authenticateWithAppId:appId 
	                       accessToken:accessToken 
	                    expirationDate:[NSDate distantFuture] 
	                             error:errPtr];
}

- (BOOL)authenticateWithAppId:(NSString *)appId 
                  accessToken:(NSString *)accessToken 
               expirationDate:(NSDate *)expirationDate 
                        error:(NSError **)errPtr
{
	XMPPLogTrace();
	
	__block BOOL result = YES;
	__block NSError *err = nil;
	
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		if (state != STATE_XMPP_CONNECTED)
		{
			NSString *errMsg = @"Please wait until the stream is connected.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
			
			[err retain];
			[pool drain];
			
			result = NO;
			return_from_block;
		}
		
		if (![self supportsXFacebookPlatform])
		{
			NSString *errMsg = @"The server does not support X-FACEBOOK-PLATFORM authentication.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamUnsupportedAction userInfo:info];
				
			[err retain];
			[pool drain];
			
			result = NO;
			return_from_block;
		}
		
		if (accessToken == nil || expirationDate == nil)
		{
			NSString *errMsg = @"Facebook accessToken and expirationDate required.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidProperty userInfo:info];
			
			[err retain];
			[pool drain];
			
			result = NO;
			return_from_block;
		}
		
		[facebook release];
		
		facebook = [[Facebook alloc] initWithAppId:appId];
		facebook.accessToken = accessToken; 
		facebook.expirationDate = expirationDate;
		
		// Facebook uses NSURLConnection which is dependent on a RunLoop.
		// So we need to use the xmppUtilityThread.
		
		[self performSelector:@selector(sendFacebookRequest:)
		            onThread:xmppUtilityThread
		          withObject:facebook
		       waitUntilDone:NO];
		
		// Update state
		state = STATE_XMPP_AUTH_1;
		
		[pool drain];
	};
    
	
    if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	if (errPtr)
		*errPtr = [err autorelease];
	else
		[err release];
	
	return result;
}

- (BOOL)authenticateWithPassword:(NSString *)password error:(NSError **)errPtr
{
	XMPPLogTrace();
	
	__block BOOL result = YES;
	__block NSError *err = nil;
	
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		if (state != STATE_XMPP_CONNECTED)
		{
			NSString *errMsg = @"Please wait until the stream is connected.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			err = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
			
			[err retain];
			[pool drain];
			
			result = NO;
			return_from_block;
		}
		
		if (facebook != nil && [self supportsXFacebookPlatform])
		{
			NSString *auth = @"<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' mechanism='X-FACEBOOK-PLATFORM'/>";
			
			NSData *outgoingData = [auth dataUsingEncoding:NSUTF8StringEncoding];
			
			XMPPLogSend(@"SEND: %@", auth);
			numberOfBytesSent += [outgoingData length];
			
			[asyncSocket writeData:outgoingData
			           withTimeout:TIMEOUT_XMPP_WRITE
			                   tag:TAG_XMPP_WRITE_STREAM];
			
			// Save authentication information
			[tempPassword release];
			tempPassword = [password copy];
			
			// Update state
			state = STATE_XMPP_AUTH_1;
		}
		else
		{
			result = [super authenticateWithPassword:password error:&err];
		}
		
		[err retain];
		[pool drain];
	};
	
	
	if (dispatch_get_current_queue() == xmppQueue)
		block();
	else
		dispatch_sync(xmppQueue, block);
	
	if (errPtr)
		*errPtr = [err autorelease];
	else
		[err release];
	
	return result;
}

#pragma mark Private instance methods

- (void)handleAuth1:(NSXMLElement *)response
{
	NSAssert(dispatch_get_current_queue() == xmppQueue, @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	if (facebook != nil && [self supportsXFacebookPlatform])
	{
		if (![[response name] isEqualToString:@"challenge"])
		{
			// Revert back to connected state (from authenticating state)
			state = STATE_XMPP_CONNECTED;
			
			[multicastDelegate xmppStream:self didNotAuthenticate:response];
		}
		else
		{
			XMPPXFacebookPlatformAuthentication *auth;
			auth = [[XMPPXFacebookPlatformAuthentication alloc] initWithChallenge:response];
            
            [auth setAccessToken:facebook.accessToken];
            [auth setSessionSecret:tempPassword];
			
			// Create and send challenge response element
			NSXMLElement *cr = [NSXMLElement elementWithName:@"response" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
			[cr setStringValue:[auth base64EncodedFullResponse]];
			
			NSString *outgoingStr = [cr compactXMLString];
			NSData *outgoingData = [outgoingStr dataUsingEncoding:NSUTF8StringEncoding];
			
			XMPPLogSend(@"SEND: %@", outgoingStr);
			numberOfBytesSent += [outgoingData length];
			
			[asyncSocket writeData:outgoingData
			           withTimeout:TIMEOUT_XMPP_WRITE
			                   tag:TAG_XMPP_WRITE_STREAM];
			
			// Release unneeded resources
			[auth release];
			[tempPassword release]; tempPassword = nil;
            
			// Update state
			state = STATE_XMPP_AUTH_3;
		}
	}
	else
	{
		[super handleAuth1:response];
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
	[facebookRequest release];
	facebookRequest = nil;
	
	[facebook release];
	facebook = nil;
}

#pragma mark FBRequest

- (void)sendFacebookRequest:(Facebook *)fb
{
	// 
	// This method is run on the xmppUtilityThread.
	// 
	
	FBRequest *fbRequest = [fb requestWithMethodName:@"auth.promoteSession"
	                                       andParams:[NSMutableDictionary dictionaryWithCapacity:3]
	                                   andHttpMethod:@"GET"
	                                     andDelegate:self];
	
	dispatch_async(xmppQueue, ^{
		
		[facebookRequest release];
		facebookRequest = [fbRequest retain];
	});
}

/**
 * Called when an error prevents the request from completing successfully.
**/
- (void)request:(FBRequest *)sender didFailWithError:(NSError *)error
{
	XMPPLogTrace();
	
	// 
    // This method is invoked on the xmppUtilityThread.
	// 
	
	dispatch_async(xmppQueue, ^{
    	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		if (sender == facebookRequest)
		{
			XMPPLogWarn(@"%@: Facebook request failed - error: %@", THIS_FILE, error);
			
			// Revert back to connected state (from authenticating state)
			state = STATE_XMPP_CONNECTED;
			
			[multicastDelegate xmppStream:self didNotAuthenticate:nil];
		}
		
		[pool drain];
	});
}

/**
 * Called when a request returns and its response has been parsed into an object.
 * The resulting object may be a dictionary, an array, a string, or a number,
 * depending on thee format of the API response.
**/
- (void)request:(FBRequest *)sender didLoad:(id)result
{
	XMPPLogTrace();
	
	// 
    // This method is invoked on the xmppUtilityThread.
	// 
	
    if ([result isKindOfClass:[NSData class]])
	{
        NSString *resultStr = [[[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding] autorelease];
		NSString *pwd = [resultStr stringByReplacingOccurrencesOfString:@"\"" withString:@""];
		
		dispatch_async(xmppQueue, ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			if (sender == facebookRequest)
			{
				// Revert back to connected state (from authenticating state)
				state = STATE_XMPP_CONNECTED;
				
				// Finish authenticating
				
				NSError *error = nil;
				
				if (![self authenticateWithPassword:pwd error:&error])
				{
					XMPPLogWarn(@"%@: Facebook auth failed - resultStr(%@) error: %@", THIS_FILE, resultStr, error);
					
					[multicastDelegate xmppStream:self didNotAuthenticate:nil];
				}
			}
			
			[pool drain];
		});
    }
}
  
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@end

@implementation XMPPXFacebookPlatformAuthentication

- (id)initWithChallenge:(NSXMLElement *)challenge
{
    if ((self = [super init]))
    {
		// Convert the base 64 encoded data into a string
		NSData *base64Data = [[challenge stringValue]
							  dataUsingEncoding:NSASCIIStringEncoding];
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
	
    XMPPLogVerbose(@"XMPPXFacebookPlatformAuthentication: sig for facebook: %@", sig);
    XMPPLogVerbose(@"XMPPXFacebookPlatformAuthentication: response for facebook: %@", buffer);
	
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
