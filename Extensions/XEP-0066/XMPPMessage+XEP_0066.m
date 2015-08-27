#import "XMPPMessage+XEP_0066.h"
#import "NSXMLElement+XMPP.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#define NAME_OUT_OF_BAND @"x"
#define XMLNS_OUT_OF_BAND @"jabber:x:oob"

@implementation XMPPMessage (XEP_0066)

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
