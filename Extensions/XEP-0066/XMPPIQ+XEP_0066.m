//
//  XMPPMessage+XEP_0066.m
//  Blabbling
//
//  Created by Kay Tsar on 5/14/13.
//  www.mingism.com
//  www.blabbling.com

#import "XMPPIQ+XEP_0066.h"

@implementation XMPPIQ (XEP_0066)
+ (NSXMLElement *)  createIqOobStanza       :
                    (NSString *) from       :
                    (NSString *) to         :
                    (NSString *) stanzaId   :
                    (NSString *) uri        :
                    (NSString *) description
{
    NSXMLElement *iqStanza = [NSXMLElement elementWithName:@"iq"];

    [iqStanza addAttributeWithName:@"type" stringValue:@"set"];
    [iqStanza addAttributeWithName:@"from" stringValue:from];
    [iqStanza addAttributeWithName:@"to" stringValue:to];
    [iqStanza addAttributeWithName:@"id" stringValue:stanzaId];
    
    if (uri){
        iqStanza = [XMPPIQ addOobElement : uri : description : iqStanza ];
    };

    return iqStanza;
}

+ (NSXMLElement *) addOobElement : (NSString *) uri : (NSXMLElement *) iqStanza
{
    //Description is optional
    return [self addOobElement: uri: Nil : iqStanza];
}

+ (NSXMLElement *)addOobElement: (NSString *) uri : (NSString *) description :(NSXMLElement *) iqStanza
{
	// Full example of an IQ stanza with an OOB element:
    //    <iq type='set' from='stpeter@jabber.org/work' to='MaineBoy@jabber.org/home' id='oob1'>
    //      <query xmlns='jabber:iq:oob'>
    //          <url>http://www.jabber.org/images/psa-license.jpg</url>
    //          <desc>A license to Jabber!</desc>
    //      </query>
    //    </iq>
    
    static NSString *const xmlns_outofband = @"jabber:iq:oob";
    
	NSXMLElement *oobUriElement = [NSXMLElement elementWithName:@"query" xmlns: xmlns_outofband];

    
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
	
	[iqStanza addChild:oobUriElement];
	
	return iqStanza;
}

- (BOOL *) oobIsSuccesfull
{
    NSInteger *errorcode = [self getOobHttpErrorCode];
    if (errorcode > 0){
        return false;
    }
    else {
        return true;
    }
}

- (NSInteger *) getOobHttpErrorCode
{
	NSXMLElement *errorElement = [self elementForName:@"error"];
	NSString *errorCode = [errorElement attributeStringValueForName:@"code"];
	
    if (errorCode)
    {
        NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
        [f setNumberStyle:NSNumberFormatterDecimalStyle];
        return [f numberFromString:errorCode].intValue;
    }
    else
    {
        return nil;
    }
}
@end
