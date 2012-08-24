//
//  XMPPIQ+JabberRPC.h
//  XEP-0009
//
//  Created by Eric Chamberlain on 5/16/10.
//

#import <Foundation/Foundation.h>

#import "XMPPIQ.h"


@interface XMPPIQ(JabberRPC)

/**
 * Creates and returns a new autoreleased XMPPIQ.
 * This is the only method you normally need to call.
 **/
+ (XMPPIQ *)rpcTo:(XMPPJID *)jid methodName:(NSString *)method parameters:(NSArray *)parameters;

#pragma mark -
#pragma mark Element helper methods

// returns a Jabber-RPC query elelement
//		<query xmlns='jabber:iq:rpc'>
+(NSXMLElement *)elementRpcQuery;

// returns a Jabber-RPC methodCall element
//			<methodCall>
+(NSXMLElement *)elementMethodCall;

// returns a Jabber-RPC methodName element
//				<methodName>method</methodName>
+(NSXMLElement *)elementMethodName:(NSString *)method;

// returns a Jabber-RPC params element
//				<params>
+(NSXMLElement *)elementParams;

#pragma mark -
#pragma mark Disco elements

// returns the Disco query identity element
//   <identity category='automation' type='rpc'/>
+(NSXMLElement *)elementRpcIdentity;

// returns the Disco query feature element
//	 <feature var='jabber:iq:rpc'/>
+(NSXMLElement *)elementRpcFeature;

#pragma mark -
#pragma mark Conversion methods

// encode any object into JabberRPC formatted element
// this method calls the others
+(NSXMLElement *)paramElementFromObject:(id)object;

+(NSXMLElement *)valueElementFromObject:(id)object;

+(NSXMLElement *)valueElementFromArray:(NSArray *)array;
+(NSXMLElement *)valueElementFromDictionary:(NSDictionary *)dictionary;

+(NSXMLElement *)valueElementFromBoolean:(CFBooleanRef)boolean;
+(NSXMLElement *)valueElementFromNumber:(NSNumber *)number;
+(NSXMLElement *)valueElementFromString:(NSString *)string;
+(NSXMLElement *)valueElementFromDate:(NSDate *)date;
+(NSXMLElement *)valueElementFromData:(NSData *)data;

+(NSXMLElement *)valueElementFromElementWithName:(NSString *)elementName value:(NSString *)value;


#pragma mark Wrapper methods

+(NSXMLElement *)wrapElement:(NSString *)elementName aroundElement:(NSXMLElement *)element;
+(NSXMLElement *)wrapValueElementAroundElement:(NSXMLElement *)element;

@end
