#import "XMPPIQ+XEP_0066.h"
#import "NSXMLElement+XMPP.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#define NAME_OUT_OF_BAND @"query"
#define XMLNS_OUT_OF_BAND @"jabber:iq:oob"

@implementation XMPPIQ (XEP_0066)


+ (XMPPIQ *)outOfBandDataRequestTo:(XMPPJID *)jid
						 elementID:(NSString *)eid
							   URL:(NSURL *)URL
							  desc:(NSString *)desc
{
	return [[XMPPIQ alloc] initOutOfBandDataRequestTo:jid
											elementID:eid
												  URL:URL
												 desc:desc];
}

+ (XMPPIQ *)outOfBandDataRequestTo:(XMPPJID *)jid
						 elementID:(NSString *)eid
							   URI:(NSString *)URI
							  desc:(NSString *)desc
{
	return [[XMPPIQ alloc] initOutOfBandDataRequestTo:jid
											elementID:eid
												  URI:URI
												 desc:desc];
}


- (id)initOutOfBandDataRequestTo:(XMPPJID *)jid
					   elementID:(NSString *)eid
							 URL:(NSURL *)URL
							desc:(NSString *)desc
{
	if((self = [self initWithType:@"set" to:jid elementID:eid]))
	{
		[self addOutOfBandURL:URL desc:desc];
	}
	
	return self;
}

- (id)initOutOfBandDataRequestTo:(XMPPJID *)jid
					   elementID:(NSString *)eid
							 URI:(NSString *)URI
							desc:(NSString *)desc
{
	if((self = [self initWithType:@"set" to:jid elementID:eid]))
	{
		[self addOutOfBandURI:URI desc:desc];
	}
	
	return self;
}

- (void)addOutOfBandURL:(NSURL *)URL desc:(NSString *)desc
{
	NSXMLElement *outOfBand = [NSXMLElement elementWithName:NAME_OUT_OF_BAND xmlns:XMLNS_OUT_OF_BAND];
	
	if([[URL path] length])
	{
		NSXMLElement *URLElement = [NSXMLElement elementWithName:@"url" stringValue:[URL path]];
		[outOfBand addChild:URLElement];
	}
	
	if([desc length])
	{
		NSXMLElement *descElement = [NSXMLElement elementWithName:@"desc" stringValue:desc];
		[outOfBand addChild:descElement];
	}
	
	[self addChild:outOfBand];
}

- (void)addOutOfBandURI:(NSString *)URI desc:(NSString *)desc
{
	NSXMLElement *outOfBand = [NSXMLElement elementWithName:NAME_OUT_OF_BAND xmlns:XMLNS_OUT_OF_BAND];
	
	if([URI length])
	{
		NSXMLElement *URLElement = [NSXMLElement elementWithName:@"url" stringValue:URI];
		[outOfBand addChild:URLElement];
	}
	
	if([desc length])
	{
		NSXMLElement *descElement = [NSXMLElement elementWithName:@"desc" stringValue:desc];
		[outOfBand addChild:descElement];
	}
	
	[self addChild:outOfBand];
}

- (XMPPIQ *)generateOutOfBandDataSuccessResponse
{
	return [XMPPIQ iqWithType:@"result" to:[self from] elementID:[self elementID]];
}

- (XMPPIQ *)generateOutOfBandDataFailureResponse
{
	XMPPIQ *outOfBandDataFailureResponse = [XMPPIQ iqWithType:@"error" to:[self from] elementID:[self elementID]];
	
	[outOfBandDataFailureResponse addOutOfBandURI:[self outOfBandURI] desc:[self outOfBandDesc]];
	
	NSXMLElement *errorElement = [NSXMLElement elementWithName:@"error"];
	[errorElement addAttributeWithName:@"code" stringValue:@"404"];
	[errorElement addAttributeWithName:@"type" stringValue:@"cancel"];
	
	NSXMLElement *itemNotFoundElement = [NSXMLElement elementWithName:@"item-not-found" xmlns:@"rn:ietf:params:xml:ns:xmpp-stanzas"];
	[errorElement addChild:itemNotFoundElement];
	
	[outOfBandDataFailureResponse addChild:errorElement];

	
	return outOfBandDataFailureResponse;
}

- (XMPPIQ *)generateOutOfBandDataRejectResponse
{
	XMPPIQ *outOfBandDataRejectResponse = [XMPPIQ iqWithType:@"error" to:[self from] elementID:[self elementID]];
	
	[outOfBandDataRejectResponse addOutOfBandURI:[self outOfBandURI] desc:[self outOfBandDesc]];

	NSXMLElement *errorElement = [NSXMLElement elementWithName:@"error"];
	[errorElement addAttributeWithName:@"code" stringValue:@"406"];
	[errorElement addAttributeWithName:@"type" stringValue:@"modify"];
	
	NSXMLElement *notAcceptableElement = [NSXMLElement elementWithName:@"not-acceptable" xmlns:@"rn:ietf:params:xml:ns:xmpp-stanzas"];
	[errorElement addChild:notAcceptableElement];
	
	[outOfBandDataRejectResponse addChild:errorElement];
	
	return outOfBandDataRejectResponse;
}

- (BOOL)isOutOfBandDataRequest
{
	if([self hasOutOfBandData] && [self isSetIQ])
	{
		return YES;
	}else{
		return NO;
	}
}

- (BOOL)isOutOfBandDataFailureResponse
{
	NSXMLElement *errorElement = [self elementForName:@"error"];

	NSUInteger errorCode = [errorElement attributeIntegerValueForName:@"code"];
	NSString *errorType = [errorElement attributeStringValueForName:@"type"];
	
	if([self hasOutOfBandData] && [self isErrorIQ] && errorCode == 404 && [errorType isEqualToString:@"cancel"])
	{
		return YES;
	}else{
		return NO;
	}
}

- (BOOL)isOutOfBandDataRejectResponse
{
	NSXMLElement *errorElement = [self elementForName:@"error"];
	
	NSUInteger errorCode = [errorElement attributeIntegerValueForName:@"code"];
	NSString *errorType = [errorElement attributeStringValueForName:@"type"];
	
	if([self hasOutOfBandData] && [self isErrorIQ] && errorCode == 406 && [errorType isEqualToString:@"modify"])
	{
		return YES;
	}else{
		return NO;
	}
}

- (BOOL)hasOutOfBandData
{
	return ([self elementForName:NAME_OUT_OF_BAND xmlns:XMLNS_OUT_OF_BAND] ? YES : NO);
}

- (NSURL *)outOfBandURL
{
	NSURL *URL = nil;
	
	NSXMLElement *outOfBand = [self elementForName:NAME_OUT_OF_BAND xmlns:XMLNS_OUT_OF_BAND];
	
	NSXMLElement *URLElement = [outOfBand elementForName:@"url"];
	
	NSString *URLString = [URLElement stringValue];
	
	if([URLString length])
	{
		URL = [NSURL URLWithString:URLString];
	}
	
	return URL;
	
}

- (NSString *)outOfBandURI
{
	NSXMLElement *outOfBand = [self elementForName:NAME_OUT_OF_BAND xmlns:XMLNS_OUT_OF_BAND];
	
	NSXMLElement *URLElement = [outOfBand elementForName:@"url"];
	
	NSString *URI= [URLElement stringValue];
	
	return URI;
}

- (NSString *)outOfBandDesc
{
	NSXMLElement *outOfBand = [self elementForName:NAME_OUT_OF_BAND xmlns:XMLNS_OUT_OF_BAND];
	
	NSXMLElement *descElement = [outOfBand elementForName:@"desc"];
	
	NSString *desc = [descElement stringValue];
	
	return desc;
}

@end
