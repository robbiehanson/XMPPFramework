//
//  XMPPMessage+XEP_0066.m
//  Blabbling
//
//  Created by Kay Tsar on 5/14/13.
//  www.mingism.com 
//  www.blabbling.com

#import "XMPPMessage+XEP_0066.h"

@implementation XMPPMessage (XEP_0066)
+ (NSXMLElement *) addOobElement : (NSString *) uri : (NSXMLElement *) messageStanza
{
    //Description is optional
    return [self addOobElement: uri: Nil : messageStanza];
}

+ (NSXMLElement *) addOobElement : (NSString *) uri : (NSString *) description : (NSXMLElement *) messageStanza
{
	// Example:
	//
    //    <message from='stpeter@jabber.org/work' to='MaineBoy@jabber.org/home'>
    //      <body>Yeah, but do you have a license to Jabber?</body>
    //      <x xmlns='jabber:x:oob'>
    //          <url>http://www.jabber.org/images/psa-license.jpg</url>
    //      </x>
    //    </message>
    
    static NSString *const xmlns_outofband = @"jabber:x:oob";
    
	NSXMLElement *oobUriElement = [NSXMLElement elementWithName:@"x" xmlns: xmlns_outofband];
    
	if (uri)
	{
        NSXMLElement *urlElement = [NSXMLElement elementWithName:@"url"];
		[urlElement setStringValue: uri];
        [oobUriElement addChild:urlElement];
	}
    
    if (description)
	{
        NSXMLElement *descElement = [NSXMLElement elementWithName:@"desc"];
		[descElement setStringValue: description];
        [oobUriElement addChild:descElement];
	}
	
	[messageStanza addChild:oobUriElement];
	
	return messageStanza;
}
@end
