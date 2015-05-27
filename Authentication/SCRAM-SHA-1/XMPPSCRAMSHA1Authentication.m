//
//  XMPPSCRAMSHA1Authentication.m
//  iPhoneXMPP
//
//  Created by David Chiles on 3/21/14.
//
//

#import "XMPPSCRAMSHA1Authentication.h"
#import "XMPP.h"
#import "XMPPLogging.h"
#import "XMPPStream.h"
#import "XMPPInternal.h"
#import "NSData+XMPP.h"
#import "XMPPStringPrep.h"

#import <CommonCrypto/CommonKeyDerivation.h>


#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
#if DEBUG
static const int xmppLogLevel = XMPP_LOG_LEVEL_INFO; // | XMPP_LOG_FLAG_TRACE;
#else
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

@interface XMPPSCRAMSHA1Authentication ()
{
    #if __has_feature(objc_arc_weak)
        __weak XMPPStream *xmppStream;
    #else
        __unsafe_unretained XMPPStream *xmppStream;
    #endif
}

@property (nonatomic) BOOL awaitingChallenge;
@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSString *password;
@property (nonatomic, strong) NSString *clientNonce;
@property (nonatomic, strong) NSString *combinedNonce;
@property (nonatomic, strong) NSString *salt;
@property (nonatomic, strong) NSNumber *count;
@property (nonatomic, strong) NSString *serverMessage1;
@property (nonatomic, strong) NSString *clientFirstMessageBare;
@property (nonatomic, strong) NSData *serverSignatureData;
@property (nonatomic, strong) NSData *clientProofData;
@property (nonatomic) CCHmacAlgorithm hashAlgorithm;

@end

///////////RFC5802 http://tools.ietf.org/html/rfc5802 //////////////

//Channel binding not yet supported

@implementation XMPPSCRAMSHA1Authentication

+ (NSString *)mechanismName
{
	return @"SCRAM-SHA-1";
}

- (id)initWithStream:(XMPPStream *)stream password:(NSString *)password
{
	return [self initWithStream:stream username:nil password:password];
}

- (id)initWithStream:(XMPPStream *)stream username:(NSString *)username password:(NSString *)password
{
    if ((self = [super init])) {
        xmppStream = stream;
        if (username)
        {
            _username = username;
        }
        else
        {
            _username = [XMPPStringPrep prepNode:[xmppStream.myJID user]];
        }
        _password = [XMPPStringPrep prepPassword:password];
        _hashAlgorithm = kCCHmacAlgSHA1;
    }
    return self;
}

- (BOOL)start:(NSError **)errPtr
{
	XMPPLogTrace();

    if(self.username.length || self.password.length) {
        
        NSXMLElement *auth = [NSXMLElement elementWithName:@"auth" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
        [auth addAttributeWithName:@"mechanism" stringValue:@"SCRAM-SHA-1"];
        [auth setStringValue:[self clientMessage1]];
        
        [xmppStream sendAuthElement:auth];
        self.awaitingChallenge = YES;
        
        return YES;
    }
    else {
        return NO;
    }
}

- (XMPPHandleAuthResponse)handleAuth1:(NSXMLElement *)authResponse
{
    XMPPLogTrace();
	
	// We're expecting a challenge response.
	// If we get anything else we're going to assume it's some kind of failure response.
	
	if (![[authResponse name] isEqualToString:@"challenge"])
	{
		return XMPP_AUTH_FAIL;
	}
    
    NSDictionary *auth = [self dictionaryFromChallenge:authResponse];
    
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
    
    self.combinedNonce = auth[@"r"];
    self.salt = auth[@"s"];
    self.count = [numberFormatter numberFromString:auth[@"i"]];
    
    //We have all the necessary information to calculate client proof and server signature
    if ([self calculateProofs]) {
        NSXMLElement *response = [NSXMLElement elementWithName:@"response" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
        [response setStringValue:[self clientMessage2]];
        
        [xmppStream sendAuthElement:response];
        self.awaitingChallenge = NO;
        
        return XMPP_AUTH_CONTINUE;
    }
    else {
        return XMPP_AUTH_FAIL;
    }
}

- (XMPPHandleAuthResponse)handleAuth2:(NSXMLElement *)authResponse
{
    XMPPLogTrace();
    
    NSDictionary *auth = [self dictionaryFromChallenge:authResponse];
    
    if ([[authResponse name] isEqual:@"success"]) {
        NSString *receivedServerSignature = auth[@"v"];
        
        if([self.serverSignatureData isEqualToData:[[receivedServerSignature dataUsingEncoding:NSUTF8StringEncoding] xmpp_base64Decoded]]){
            return XMPP_AUTH_SUCCESS;
        }
        else {
            return XMPP_AUTH_FAIL;
        }
    }
    else {
        return XMPP_AUTH_FAIL;
    }
}

- (XMPPHandleAuthResponse)handleAuth:(NSXMLElement *)auth
{
	XMPPLogTrace();
	
	if (self.awaitingChallenge) {
		return [self handleAuth1:auth];
	}
	else {
		return [self handleAuth2:auth];
	}
}

- (NSString *)clientMessage1
{
    self.clientNonce = [XMPPStream generateUUID];
    
    self.clientFirstMessageBare = [NSString stringWithFormat:@"n=%@,r=%@",self.username,self.clientNonce];
    
    NSData *message1Data = [[NSString stringWithFormat:@"n,,%@",self.clientFirstMessageBare] dataUsingEncoding:NSUTF8StringEncoding];
    
    return [message1Data xmpp_base64Encoded];
}

- (NSString *)clientMessage2
{
    NSString *clientProofString = [self.clientProofData xmpp_base64Encoded];
    NSData *message2Data = [[NSString stringWithFormat:@"c=biws,r=%@,p=%@",self.combinedNonce,clientProofString] dataUsingEncoding:NSUTF8StringEncoding];
    
    return [message2Data xmpp_base64Encoded];
}

- (BOOL)calculateProofs
{
    //Check to see that we have a password, salt and iteration count above 4096 (from RFC5802)
    if (!self.password.length || !self.salt.length || self.count.unsignedIntegerValue < 4096) {
        return NO;
    }
    
    NSData *passwordData = [self.password dataUsingEncoding:NSUTF8StringEncoding];
    NSData *saltData = [[self.salt dataUsingEncoding:NSUTF8StringEncoding] xmpp_base64Decoded];
    
    NSData *saltedPasswordData = [self HashWithAlgorithm:self.hashAlgorithm password:passwordData salt:saltData iterations:[self.count unsignedIntValue]];
    
    NSData *clientKeyData = [self HashWithAlgorithm:self.hashAlgorithm data:[@"Client Key" dataUsingEncoding:NSUTF8StringEncoding] key:saltedPasswordData];
    NSData *serverKeyData = [self HashWithAlgorithm:self.hashAlgorithm data:[@"Server Key" dataUsingEncoding:NSUTF8StringEncoding] key:saltedPasswordData];

    NSData *storedKeyData = [clientKeyData xmpp_sha1Digest];
    
    NSData *authMessageData = [[NSString stringWithFormat:@"%@,%@,c=biws,r=%@",self.clientFirstMessageBare,self.serverMessage1,self.combinedNonce] dataUsingEncoding:NSUTF8StringEncoding];
    
    NSData *clientSignatureData = [self HashWithAlgorithm:self.hashAlgorithm data:authMessageData key:storedKeyData];
    
    self.serverSignatureData = [self HashWithAlgorithm:self.hashAlgorithm data:authMessageData key:serverKeyData];
    self.clientProofData = [self xorData:clientKeyData withData:clientSignatureData];
    
    //check to see that we caclulated some client proof and server signature
    if (self.clientProofData && self.serverSignatureData) {
        return YES;
    }
    else {
        return NO;
    }
}

- (NSData *)HashWithAlgorithm:(CCHmacAlgorithm) algorithm password:(NSData *)passwordData salt:(NSData *)saltData iterations:(NSUInteger)rounds
{
    NSMutableData *mutableSaltData = [saltData mutableCopy];
    UInt8 zeroHex= 0x00;
    UInt8 oneHex= 0x01;
    NSData *zeroData = [[NSData alloc] initWithBytes:&zeroHex length:sizeof(zeroHex)];
    NSData *oneData = [[NSData alloc] initWithBytes:&oneHex length:sizeof(oneHex)];
    
    [mutableSaltData appendData:zeroData];
    [mutableSaltData appendData:zeroData];
    [mutableSaltData appendData:zeroData];
    [mutableSaltData appendData:oneData];
    
    NSData *result = [self HashWithAlgorithm:algorithm data:mutableSaltData key:passwordData];
    NSData *previous = [result copy];
    
    for (int i = 1; i < rounds; i++) {
        previous = [self HashWithAlgorithm:algorithm data:previous key:passwordData];
        result = [self xorData:result withData:previous];
    }
    
    return result;
}

- (NSData *)HashWithAlgorithm:(CCHmacAlgorithm) algorithm data:(NSData *)data key:(NSData *)key
{
    unsigned char cHMAC[CC_SHA1_DIGEST_LENGTH];
    
    CCHmac(algorithm, [key bytes], [key length], [data bytes], [data length], cHMAC);
    
    return [[NSData alloc] initWithBytes:cHMAC length:sizeof(cHMAC)];
}

- (NSData *)xorData:(NSData *)data1 withData:(NSData *)data2
{
    NSMutableData *result = data1.mutableCopy;
    
    char *dataPtr = (char *)result.mutableBytes;
    
    char *keyData = (char *)data2.bytes;
    
    char *keyPtr = keyData;
    int keyIndex = 0;
    
    for (int x = 0; x < data1.length; x++) {
        *dataPtr = *dataPtr ^ *keyPtr;
        dataPtr++;
        keyPtr++;
        
        if (++keyIndex == data2.length) {
            keyIndex = 0;
			keyPtr = keyData;
		}
	}
    return result;
}

- (NSDictionary *)dictionaryFromChallenge:(NSXMLElement *)challenge
{
	// The value of the challenge stanza is base 64 encoded.
	// Once "decoded", it's just a string of key=value pairs separated by commas.
	
	NSData *base64Data = [[challenge stringValue] dataUsingEncoding:NSASCIIStringEncoding];
	NSData *decodedData = [base64Data xmpp_base64Decoded];
	
	self.serverMessage1 = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
	
	XMPPLogVerbose(@"%@: Decoded challenge: %@", THIS_FILE, self.serverMessage1);
	
	NSArray *components = [self.serverMessage1 componentsSeparatedByString:@","];
	NSMutableDictionary *auth = [NSMutableDictionary dictionaryWithCapacity:5];
	
	for (NSString *component in components)
	{
		NSRange separator = [component rangeOfString:@"="];
		if (separator.location != NSNotFound)
		{
			NSMutableString *key = [[component substringToIndex:separator.location] mutableCopy];
			NSMutableString *value = [[component substringFromIndex:separator.location+1] mutableCopy];
			
			if(key) CFStringTrimWhitespace((__bridge CFMutableStringRef)key);
			if(value) CFStringTrimWhitespace((__bridge CFMutableStringRef)value);
			
			if ([value hasPrefix:@"\""] && [value hasSuffix:@"\""] && [value length] > 2)
			{
				// Strip quotes from value
				[value deleteCharactersInRange:NSMakeRange(0, 1)];
				[value deleteCharactersInRange:NSMakeRange([value length]-1, 1)];
			}
			
            if(key && value)
            {
                auth[key] = value;
            }
		}
	}
	
	return auth;
}
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPStream (XMPPSCRAMSHA1Authentication)

- (BOOL)supportsSCRAMSHA1Authentication
{
	return [self supportsAuthenticationMechanism:[XMPPSCRAMSHA1Authentication mechanismName]];
}

@end
