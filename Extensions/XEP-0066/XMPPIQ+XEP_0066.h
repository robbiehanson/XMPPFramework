//
//  XMPPMessage+XEP_0066.m
//
//  Created by Kay Tsar on 5/14/13.


#import "XMPPIQ.h"

@interface XMPPIQ (XEP_0066)
+ (NSXMLElement *)  createIqOobStanza       :
                    (NSString *) from       :
                    (NSString *) to         :
                    (NSString *) stanzaId   :
                    (NSString *) uri        :
                    (NSString *) description;
+ (NSXMLElement *) addOobElement : (NSString *) uri : (NSXMLElement *) iqStanza;
+ (NSXMLElement *) addOobElement : (NSString *) uri : (NSString *) desc : (NSXMLElement *) iqStanza;
- (BOOL *) oobIsSuccesfull;
- (NSInteger *) getOobHttpErrorCode;
@end
