//
//  XMPPMessage+XEP_0066.m
//  Blabbling
//
//  Created by Kay Tsar on 5/14/13.
//  www.mingism.com
//  www.blabbling.com

#import "XMPPMessage.h"

@interface XMPPMessage (XEP_0066)
+ (NSXMLElement *) addOobElement : (NSString *) uri : (NSXMLElement *) messageStanza;
+ (NSXMLElement *)addOobElement: (NSString *) uri : (NSString *) description : (NSXMLElement *) messageStanza;
@end
