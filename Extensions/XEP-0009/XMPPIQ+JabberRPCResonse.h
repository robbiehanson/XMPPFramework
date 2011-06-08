//
//  XMPPIQ+JabberRPCResonse.h
//  XEP-0009
//
//  Created by Eric Chamberlain on 5/25/10.
//

#import "XMPPIQ.h"

typedef enum {
    JabberRPCElementTypeArray,
    JabberRPCElementTypeDictionary,
    JabberRPCElementTypeMember,
    JabberRPCElementTypeName,
    JabberRPCElementTypeInteger,
    JabberRPCElementTypeDouble,
    JabberRPCElementTypeBoolean,
    JabberRPCElementTypeString,
    JabberRPCElementTypeDate,
    JabberRPCElementTypeData
} JabberRPCElementType;


@interface XMPPIQ(JabberRPCResonse)

-(NSXMLElement *)methodResponseElement;

// is this a Jabber RPC method response
-(BOOL)isMethodResponse;

-(BOOL)isFault;

-(BOOL)isJabberRPC;

-(id)methodResponse:(NSError **)error;

-(id)objectFromElement:(NSXMLElement *)param;


#pragma mark -

-(NSArray *)parseArray:(NSXMLElement *)arrayElement;

-(NSDictionary *)parseStruct:(NSXMLElement *)structElement;

-(NSDictionary *)parseMember:(NSXMLElement *)memberElement;

#pragma mark -

- (NSDate *)parseDateString: (NSString *)dateString withFormat: (NSString *)format;

#pragma mark -

- (NSNumber *)parseInteger: (NSString *)value;

- (NSNumber *)parseDouble: (NSString *)value;

- (NSNumber *)parseBoolean: (NSString *)value;

- (NSString *)parseString: (NSString *)value;

- (NSDate *)parseDate: (NSString *)value;

- (NSData *)parseData: (NSString *)value;

@end
