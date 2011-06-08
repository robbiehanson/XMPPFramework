//
//  XMPPIQ+JabberRPC.m
//  XEP-0009
//
//  Created by Eric Chamberlain on 5/16/10.
//

#import "XMPPIQ+JabberRPC.h"

#import "NSData+XMPP.h"
#import "XMPP.h"


@implementation XMPPIQ(JabberRPC)

+(XMPPIQ *)rpcTo:(XMPPJID *)jid methodName:(NSString *)method parameters:(NSArray *)parameters {
	// Send JabberRPC element
	// 
	//	<iq to="fullJID" type="set" id="elementID">
	//		<query xmlns='jabber:iq:rpc'>
	//			<methodCall>
	//				<methodName>method</methodName>
	//				<params>
	//					<param>
	//						<value><string>example</string></value>
	//					</param>
	//					...
	//				</params>
	//			</methodCall>
	//		</query>
	//	</iq>
	
	XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:jid elementID:[XMPPStream generateUUID]];
	
	NSXMLElement *jabberRPC = [self elementRpcQuery];
	NSXMLElement *methodCall = [self elementMethodCall];
	NSXMLElement *methodName = [self elementMethodName:method];
	NSXMLElement *params = [self elementParams];
	
	for (id parameter in parameters) {
		[params addChild:[self paramElementFromObject:parameter]];
	}
	
	[methodCall addChild:methodName];
	[methodCall addChild:params];
	[jabberRPC addChild:methodCall];
	[iq addChild:jabberRPC];
	return iq;
}

#pragma mark Element helper methods

+(NSXMLElement *)elementRpcQuery {
	return [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:rpc"];
}

+(NSXMLElement *)elementMethodCall {
	return [NSXMLElement elementWithName:@"methodCall"];
}

+(NSXMLElement *)elementMethodName:(NSString *)method {
	return [NSXMLElement elementWithName:@"methodName" stringValue:method];
}

+(NSXMLElement *)elementParams {
	return [NSXMLElement elementWithName:@"params"];
}


#pragma mark -
#pragma mark Disco elements

+(NSXMLElement *)elementRpcIdentity {
	NSXMLElement *identity = [NSXMLElement elementWithName:@"identity"];
	[identity addAttributeWithName:@"category" stringValue:@"automation"];
	[identity addAttributeWithName:@"type" stringValue:@"rpc"];
	return identity;
}

// returns the Disco query feature element
//	 <feature var='jabber:iq:rpc'/>
+(NSXMLElement *)elementRpcFeature {
	NSXMLElement *feature = [NSXMLElement elementWithName:@"feature"];
	[feature addAttributeWithName:@"var" stringValue:@"jabber:iq:rpc"];
	return feature;
}
#pragma mark Conversion methods

+(NSXMLElement *)paramElementFromObject:(id)object {
	if (!object) {
		return nil;
	}
	return [self wrapElement:@"param" aroundElement:[self valueElementFromObject:object]];
}

+(NSXMLElement *)valueElementFromObject:(id)object {
	if (!object) {
		return nil;
	}
	
	if ([object isKindOfClass: [NSArray class]]) {
        return [self valueElementFromArray: object];
    } else if ([object isKindOfClass: [NSDictionary class]]) {
        return [self valueElementFromDictionary: object];
    } else if (((CFBooleanRef)object == kCFBooleanTrue) || ((CFBooleanRef)object == kCFBooleanFalse)) {
        return [self valueElementFromBoolean: (CFBooleanRef)object];
    } else if ([object isKindOfClass: [NSNumber class]]) {
        return [self valueElementFromNumber: object];
    } else if ([object isKindOfClass: [NSString class]]) {
        return [self valueElementFromString: object];
    } else if ([object isKindOfClass: [NSDate class]]) {
        return [self valueElementFromDate: object];
    } else if ([object isKindOfClass: [NSData class]]) {
        return [self valueElementFromData: object];
    } else {
        return [self valueElementFromString: object];
    }
	
}


+(NSXMLElement *)valueElementFromArray:(NSArray *)array {
	NSXMLElement *data = [NSXMLElement elementWithName:@"data"];
	
	for (id object in array) {
		[data addChild:[self valueElementFromObject:object]];
	}
	return [self wrapValueElementAroundElement:data];
}


+(NSXMLElement *)valueElementFromDictionary:(NSDictionary *)dictionary {
	NSXMLElement *structElement = [NSXMLElement elementWithName:@"struct"];
	
	NSXMLElement *member;
	NSXMLElement *name;
	
	for (NSString *key in dictionary) {
		member = [NSXMLElement elementWithName:@"member"];
		name = [NSXMLElement elementWithName:@"name" stringValue:key];
		[member addChild:name];
		[member addChild:[self valueElementFromObject:[dictionary objectForKey:key]]];
	}
	
	return [self wrapValueElementAroundElement:structElement];
}


+(NSXMLElement *)valueElementFromBoolean:(CFBooleanRef)boolean {
	if (boolean == kCFBooleanTrue) {
		return [self valueElementFromElementWithName:@"boolean" value:@"1"];
	} else {
		return [self valueElementFromElementWithName:@"boolean" value:@"0"];
	}
}


+(NSXMLElement *)valueElementFromNumber:(NSNumber *)number {
	// what type of NSNumber is this?
    if ([[NSString stringWithCString: [number objCType] 
							encoding: NSUTF8StringEncoding] isEqualToString: @"d"]) {
        return [self valueElementFromElementWithName:@"double" value:[number stringValue]];
    } else {
        return [self valueElementFromElementWithName:@"i4" value:[number stringValue]];
    }
}


+(NSXMLElement *)valueElementFromString:(NSString *)string {
	return [self valueElementFromElementWithName:@"string" value:string];
}


+(NSXMLElement *)valueElementFromDate:(NSDate *)date {
	unsigned calendarComponents =	kCFCalendarUnitYear | 
	kCFCalendarUnitMonth | 
	kCFCalendarUnitDay | 
	kCFCalendarUnitHour | 
	kCFCalendarUnitMinute | 
	kCFCalendarUnitSecond;
    NSDateComponents *dateComponents = [[NSCalendar currentCalendar] components:calendarComponents fromDate:date];
    NSString *dateString = [NSString stringWithFormat: @"%.4d%.2d%.2dT%.2d:%.2d:%.2d", 
							[dateComponents year], 
							[dateComponents month], 
							[dateComponents day], 
							[dateComponents hour], 
							[dateComponents minute], 
							[dateComponents second], 
							nil];
    
    return [self valueElementFromElementWithName:@"dateTime.iso8601" value: dateString];
}


+(NSXMLElement *)valueElementFromData:(NSData *)data {	
    return [self valueElementFromElementWithName:@"base64" value:[data base64Encoded]];
}

+(NSXMLElement *)valueElementFromElementWithName:(NSString *)elementName value:(NSString *)value {
	return [self wrapValueElementAroundElement:[NSXMLElement elementWithName:elementName stringValue:value]];
}


#pragma mark Wrapper methods

+(NSXMLElement *)wrapElement:(NSString *)elementName aroundElement:(NSXMLElement *)element {
	NSXMLElement *wrapper = [NSXMLElement elementWithName:elementName];
	[wrapper addChild:element];
	return wrapper;
}

+(NSXMLElement *)wrapValueElementAroundElement:(NSXMLElement *)element {
	return [self wrapElement:@"value" aroundElement:element];
}

@end
