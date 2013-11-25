#import "XMPPMessage.h"
#import "XMPPJID.h"
#import "NSXMLElement+XMPP.h"

#import <objc/runtime.h>

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif


@implementation XMPPMessage

+ (void)initialize
{
	// We use the object_setClass method below to dynamically change the class from a standard NSXMLElement.
	// The size of the two classes is expected to be the same.
	//
	// If a developer adds instance methods to this class, bad things happen at runtime that are very hard to debug.
	// This check is here to aid future developers who may make this mistake.
	//
	// For Fearless And Experienced Objective-C Developers:
	// It may be possible to support adding instance variables to this class if you seriously need it.
	// To do so, try realloc'ing self after altering the class, and then initialize your variables.
	
	size_t superSize = class_getInstanceSize([NSXMLElement class]);
	size_t ourSize   = class_getInstanceSize([XMPPMessage class]);
	
	if (superSize != ourSize)
	{
		NSLog(@"Adding instance variables to XMPPMessage is not currently supported!");
		exit(15);
	}
}

+ (XMPPMessage *)messageFromElement:(NSXMLElement *)element
{
	object_setClass(element, [XMPPMessage class]);
	
	return (XMPPMessage *)element;
}

+ (XMPPMessage *)message
{
	return [[XMPPMessage alloc] init];
}

+ (XMPPMessage *)messageWithType:(NSString *)type
{
	return [[XMPPMessage alloc] initWithType:type to:nil];
}

+ (XMPPMessage *)messageWithType:(NSString *)type to:(XMPPJID *)to
{
	return [[XMPPMessage alloc] initWithType:type to:to];
}

+ (XMPPMessage *)messageWithType:(NSString *)type to:(XMPPJID *)jid elementID:(NSString *)eid
{
	return [[XMPPMessage alloc] initWithType:type to:jid elementID:eid];
}

+ (XMPPMessage *)messageWithType:(NSString *)type to:(XMPPJID *)jid elementID:(NSString *)eid child:(NSXMLElement *)childElement
{
	return [[XMPPMessage alloc] initWithType:type to:jid elementID:eid child:childElement];
}

+ (XMPPMessage *)messageWithType:(NSString *)type elementID:(NSString *)eid
{
	return [[XMPPMessage alloc] initWithType:type elementID:eid];
}

+ (XMPPMessage *)messageWithType:(NSString *)type elementID:(NSString *)eid child:(NSXMLElement *)childElement
{
	return [[XMPPMessage alloc] initWithType:type elementID:eid child:childElement];
}

+ (XMPPMessage *)messageWithType:(NSString *)type child:(NSXMLElement *)childElement
{
	return [[XMPPMessage alloc] initWithType:type child:childElement];
}

- (id)init
{
	return [self initWithType:nil to:nil elementID:nil child:nil];
}

- (id)initWithType:(NSString *)type
{
	return [self initWithType:type to:nil elementID:nil child:nil];
}

- (id)initWithType:(NSString *)type to:(XMPPJID *)jid
{
	return [self initWithType:type to:jid elementID:nil child:nil];
}

- (id)initWithType:(NSString *)type to:(XMPPJID *)jid elementID:(NSString *)eid
{
	return [self initWithType:type to:jid elementID:eid child:nil];
}

- (id)initWithType:(NSString *)type to:(XMPPJID *)jid elementID:(NSString *)eid child:(NSXMLElement *)childElement
{
	if ((self = [super initWithName:@"message"]))
	{
		if (type)
			[self addAttributeWithName:@"type" stringValue:type];
		
		if (jid)
			[self addAttributeWithName:@"to" stringValue:[jid full]];
		
		if (eid)
			[self addAttributeWithName:@"id" stringValue:eid];
		
		if (childElement)
			[self addChild:childElement];
	}
	return self;
}

- (id)initWithType:(NSString *)type elementID:(NSString *)eid
{
	return [self initWithType:type to:nil elementID:eid child:nil];
}

- (id)initWithType:(NSString *)type elementID:(NSString *)eid child:(NSXMLElement *)childElement
{
	return [self initWithType:type to:nil elementID:eid child:childElement];
}

- (id)initWithType:(NSString *)type child:(NSXMLElement *)childElement
{
	return [self initWithType:type to:nil elementID:nil child:childElement];
}

- (id)initWithXMLString:(NSString *)string error:(NSError *__autoreleasing *)error
{
	if((self = [super initWithXMLString:string error:error])){
		self = [XMPPMessage messageFromElement:self];
	}
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    NSXMLElement *element = [super copyWithZone:zone];
    return [XMPPMessage messageFromElement:element];
}

- (NSString *)type
{
    return [[self attributeForName:@"type"] stringValue];
}

- (NSString *)subject
{
	return [[self elementForName:@"subject"] stringValue];
}

- (NSString *)body
{
	return [[self elementForName:@"body"] stringValue];
}

- (NSString *)bodyForLanguage:(NSString *)language
{
    NSString *bodyForLanguage = nil;
    
    for (NSXMLElement *bodyElement in [self elementsForName:@"body"])
    {
        NSString *lang = [[bodyElement attributeForName:@"xml:lang"] stringValue];
        
        // Openfire strips off the xml prefix
        if (lang == nil)
        {
            lang = [[bodyElement attributeForName:@"lang"] stringValue];
        }
        
        if ([language isEqualToString:lang] || ([language length] == 0  && [lang length] == 0))
        {
            bodyForLanguage = [bodyElement stringValue];
            break;
        }
    }
    
    return bodyForLanguage;
}

- (NSString *)thread
{
	return [[self elementForName:@"thread"] stringValue];
}

- (void)addSubject:(NSString *)subject
{
    NSXMLElement *subjectElement = [NSXMLElement elementWithName:@"subject" stringValue:subject];
    [self addChild:subjectElement];
}

- (void)addBody:(NSString *)body
{
    NSXMLElement *bodyElement = [NSXMLElement elementWithName:@"body" stringValue:body];
    [self addChild:bodyElement];
}

- (void)addBody:(NSString *)body withLanguage:(NSString *)language
{
    NSXMLElement *bodyElement = [NSXMLElement elementWithName:@"body" stringValue:body];
    
    if ([language length])
    {
        [bodyElement addAttributeWithName:@"xml:lang" stringValue:language];
    }
    
    [self addChild:bodyElement];
}

- (void)addThread:(NSString *)thread
{
    NSXMLElement *threadElement = [NSXMLElement elementWithName:@"thread" stringValue:thread];
    [self addChild:threadElement];
}

- (BOOL)isChatMessage
{
	return [[[self attributeForName:@"type"] stringValue] isEqualToString:@"chat"];
}

- (BOOL)isChatMessageWithBody
{
	if ([self isChatMessage])
	{
		return [self isMessageWithBody];
	}
	
	return NO;
}

- (BOOL)isErrorMessage
{
    return [[[self attributeForName:@"type"] stringValue] isEqualToString:@"error"];
}

- (NSError *)errorMessage
{
    if (![self isErrorMessage]) {
        return nil;
    }
    
    NSXMLElement *error = [self elementForName:@"error"];
    return [NSError errorWithDomain:@"urn:ietf:params:xml:ns:xmpp-stanzas"
                               code:[error attributeIntValueForName:@"code"]
                           userInfo:[NSDictionary dictionaryWithObject:[error compactXMLString] forKey:NSLocalizedDescriptionKey]];
    
}

- (BOOL)isMessageWithBody
{
	return ([self elementForName:@"body"] != nil);
}

@end
