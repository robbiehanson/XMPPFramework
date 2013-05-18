//
//  XMPPMessage+XEP_0066.m
//
//  Created by Kay Tsar on 5/14/13.

#import "XMPPMessage.h"

@interface XMPPMessage (XEP_0066)
+ (NSXMLElement *) addOobElement : (NSString *) uri : (NSXMLElement *) messageStanza;
+ (NSXMLElement *)addOobElement: (NSString *) uri : (NSString *) description : (NSXMLElement *) messageStanza;
@end
