#import "ParserTestMacAppDelegate.h"
#import "XMPPParser.h"

#define PRINT_ELEMENTS NO

@interface ParserTestMacAppDelegate (PrivateAPI)

- (void)nonParserTest;
- (void)parserTest;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation ParserTestMacAppDelegate

@synthesize window;

- (NSString *)stringToParse:(BOOL)full
{
	NSMutableString *mStr = [NSMutableString stringWithCapacity:500];
	
	if(full)
	{
		[mStr appendString:@"<stream:stream from='gmail.com' id='CA0CB0D98FE6FA62' version='1.0' "
		 "xmlns:stream='http://etherx.jabber.org/streams' xmlns='jabber:client'>"];
	}
	
	[mStr appendString:@"  <features>"];
	[mStr appendString:@"    <starttls xmlns='urn:ietf:params:xml:ns:xmpp-tls'>"];
	[mStr appendString:@"      <required/>"];
	[mStr appendString:@"    </starttls>"];
	[mStr appendString:@"    <mechanisms xmlns='urn:ietf:params:xml:ns:xmpp-sasl'>"];
	[mStr appendString:@"      <mechanism>X-GOOGLE-TOKEN</mechanism>"];
	[mStr appendString:@"    </mechanisms>"];
	[mStr appendString:@"  </features>"];
	
	[mStr appendString:@"  <proceed xmlns='urn:ietf:params:xml:ns:xmpp-tls'/>"];
	
	[mStr appendString:@"  <success xmlns='urn:ietf:params:xml:ns:xmpp-sasl'/>"];
	
	[mStr appendString:@"  <iq type='result'>"];
	[mStr appendString:@"    <bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'>"];
	[mStr appendString:@"      <jid>robbiehanson15@gmail.com/iPhoneTestBD221ED7</jid>"];
	[mStr appendString:@"    </bind>"];
	[mStr appendString:@"  </iq>"];
	
	[mStr appendString:@"  <team:deusty team:lead='robbie_hanson' xmlns:team='software'/>"];
	
	[mStr appendString:@"  <type><![CDATA[post]]></type>"];
	
	[mStr appendString:@"<menu>"];
	[mStr appendString:@"  <food>"];
	[mStr appendString:@"    <pizza />"];
	[mStr appendString:@"    <spaghetti />"];
	[mStr appendString:@"    <turkey />"];
	[mStr appendString:@"    <pie />"];
	[mStr appendString:@"    <potatoes />"];
	[mStr appendString:@"    <gravy />"];
	[mStr appendString:@"  </food>"];
	[mStr appendString:@"  <drinks>"];
	[mStr appendString:@"    <sprite />"];
	[mStr appendString:@"    <drPepper />"];
	[mStr appendString:@"    <pepsi />"];
	[mStr appendString:@"    <coke />"];
	[mStr appendString:@"    <mtdew />"];
	[mStr appendString:@"    <beer />"];
	[mStr appendString:@"    <wine />"];
	[mStr appendString:@"  </drinks>"];
	[mStr appendString:@"</menu>"];
	
	if(full)
	{
		[mStr appendString:@"</stream:stream>"];
	}
	
	return mStr;
}

- (NSData *)dataToParse:(BOOL)full
{
	return [[self stringToParse:full] dataUsingEncoding:NSUTF8StringEncoding];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[self nonParserTest];
	[self parserTest];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Non Parser
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSData *)nextTryFromData:(NSData *)data atOffset:(NSUInteger *)offset
{
	NSData *term = [@">" dataUsingEncoding:NSUTF8StringEncoding];
	NSUInteger termLength = [term length];
	
	NSUInteger index = *offset;
	while((index + termLength) <= [data length])
	{
		const void *dataBytes = (const void *)((void *)[data bytes] + index);
		
		if(memcmp(dataBytes, [term bytes], termLength) == 0)
		{
			NSUInteger length = (index - *offset) + termLength;
			NSRange range = NSMakeRange(*offset, length);
			
			*offset += length;
			return [data subdataWithRange:range];
		}
		else
		{
			index++;
		}
	}
	
	*offset = index;
	return nil;
}

- (void)nonParserTest
{
	NSData *dataToParse = [self dataToParse:NO];
	NSDate *start = [NSDate date];
	
	NSMutableData *mData = [NSMutableData data];
	
	NSUInteger offset = 0;
	NSData *subdata = [self nextTryFromData:dataToParse atOffset:&offset];
	while(subdata)
	{
	//	NSString *str = [[NSString alloc] initWithData:subdata encoding:NSUTF8StringEncoding];
	//	NSLog(@"str: %@", str);
	//	[str release];
		
		[mData appendData:subdata];
		
		NSXMLDocument *doc = [[NSXMLDocument alloc] initWithData:mData options:0 error:nil];
		if(doc)
		{
			if(PRINT_ELEMENTS)
			{
				NSLog(@"\n\n%@\n", [doc XMLStringWithOptions:(NSXMLNodeCompactEmptyElement | NSXMLNodePrettyPrint)]);
			}
			
			[mData setLength:0];
		}
		
		subdata = [self nextTryFromData:dataToParse atOffset:&offset];
	}
	
	NSTimeInterval ellapsed = [start timeIntervalSinceNow] * -1.0;
	NSLog(@"NonParser test = %f seconds", ellapsed);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Parser
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)parserTest
{
	NSData *dataToParse = [self dataToParse:YES];
	NSDate *start = [NSDate date];
	
	XMPPParser *parser = [[XMPPParser alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
	
	[parser parseData:dataToParse];
	
	NSTimeInterval ellapsed = [start timeIntervalSinceNow] * -1.0;
	NSLog(@"Parser test    = %f seconds", ellapsed);
}

- (void)xmppParser:(XMPPParser *)sender didReadRoot:(NSXMLElement *)root
{
	if(PRINT_ELEMENTS)
	{
		NSLog(@"xmppParser:didReadRoot: \n\n%@",
			  [root XMLStringWithOptions:(NSXMLNodeCompactEmptyElement | NSXMLNodePrettyPrint)]);
	}
}

- (void)xmppParser:(XMPPParser *)sender didReadElement:(NSXMLElement *)element
{
	if(PRINT_ELEMENTS)
	{
		NSLog(@"xmppParser:didReadElement: \n\n%@",
			  [element XMLStringWithOptions:(NSXMLNodeCompactEmptyElement | NSXMLNodePrettyPrint)]);
	}
}

- (void)xmppParserDidEnd:(XMPPParser *)sender
{
	if(PRINT_ELEMENTS)
	{
		NSLog(@"xmppParserDidEnd");
	}
}

- (void)xmppParser:(XMPPParser *)sender didFail:(NSError *)error
{
	if(PRINT_ELEMENTS)
	{
		NSLog(@"xmppParser:didFail: %@", error);
	}
}

@end
