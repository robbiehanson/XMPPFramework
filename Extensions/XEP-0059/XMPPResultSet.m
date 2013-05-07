#import "XMPPResultSet.h"
#import "NSXMLElement+XMPP.h"

#import <objc/runtime.h>

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#define XMLNS_XMPP_RESULT_SET @"http://jabber.org/protocol/rsm"
#define NAME_XMPP_RESULT_SET @"set"

@implementation XMPPResultSet

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
	size_t ourSize   = class_getInstanceSize([XMPPResultSet class]);
	
	if (superSize != ourSize)
	{
		NSLog(@"Adding instance variables to XMPPResultSet is not currently supported!");
		exit(15);
	}
}

+ (XMPPResultSet *)resultSetFromElement:(NSXMLElement *)element
{
	object_setClass(element, [XMPPResultSet class]);
	
	return (XMPPResultSet *)element;
}

+ (XMPPResultSet *)resultSet
{
    return [[XMPPResultSet alloc] init];
}

+ (XMPPResultSet *)resultSetWithMax:(NSInteger)max
{
    return [[XMPPResultSet alloc] initWithMax:max];
}

+ (XMPPResultSet *)resultSetWithMax:(NSInteger)max
                         firstIndex:(NSInteger)firstIndex
{
    return [[XMPPResultSet alloc] initWithMax:max firstIndex:firstIndex];
}

+ (XMPPResultSet *)resultSetWithMax:(NSInteger)max
                              after:(NSString *)after
{
    return [[XMPPResultSet alloc] initWithMax:max after:after];
}

+ (XMPPResultSet *)resultSetWithMax:(NSInteger)max
                             before:(NSString *)before
{
    return [[XMPPResultSet alloc] initWithMax:max before:before];
}

+ (XMPPResultSet *)resultSetWithMax:(NSInteger)max
                         firstIndex:(NSInteger)firstIndex
                              after:(NSString *)after
                             before:(NSString *)before
{
    return [[XMPPResultSet alloc] initWithMax:max
                                   firstIndex:firstIndex
                                        after:after
                                       before:before];
}

- (id)init
{
    return [self initWithMax:NSNotFound firstIndex:NSNotFound after:nil before:nil];
}

- (id)initWithMax:(NSInteger)max
{
    return [self initWithMax:max firstIndex:NSNotFound after:nil before:nil];
}

- (id)initWithMax:(NSInteger)max
       firstIndex:(NSInteger)firstIndex
{
    return [self initWithMax:max firstIndex:firstIndex after:nil before:nil];
}

- (id)initWithMax:(NSInteger)max
            after:(NSString *)after
{
    return [self initWithMax:max firstIndex:NSNotFound after:after before:nil];
}

- (id)initWithMax:(NSInteger)max
           before:(NSString *)before
{
    return [self initWithMax:max firstIndex:NSNotFound after:nil before:before];
}

- (id)initWithMax:(NSInteger)max
       firstIndex:(NSInteger)firstIndex
            after:(NSString *)after
           before:(NSString *)before
{
    if ((self = [super initWithName:NAME_XMPP_RESULT_SET xmlns:XMLNS_XMPP_RESULT_SET]))
	{
        if(max != NSNotFound)
        {
            NSXMLElement *maxElement = [NSXMLElement elementWithName:@"max" stringValue:[[NSNumber numberWithInteger:max] stringValue]];
            [self addChild:maxElement];
        }
        
        if(firstIndex != NSNotFound)
        {
            NSXMLElement *maxElement = [NSXMLElement elementWithName:@"index" stringValue:[[NSNumber numberWithInteger:firstIndex] stringValue]];
            [self addChild:maxElement];
        }
        
        if(after != nil)
        {
            if([after length])
            {
                NSXMLElement *afterElement = [NSXMLElement elementWithName:@"after" stringValue:after];
                [self addChild:afterElement];
            }
            else
            {
                NSXMLElement *afterElement = [NSXMLElement elementWithName:@"after"];
                [self addChild:afterElement];
            }
        }
        
        if(before != nil)
        {
            if([before length])
            {
                NSXMLElement *beforeElement = [NSXMLElement elementWithName:@"before" stringValue:before];
                [self addChild:beforeElement];
            }
            else
            {
                NSXMLElement *beforeElement = [NSXMLElement elementWithName:@"before"];
                [self addChild:beforeElement];
            }
        }
	}
    
	return self;
}

- (id)initWithXMLString:(NSString *)string error:(NSError *__autoreleasing *)error
{
	if((self = [super initWithXMLString:string error:error]))
    {
		self = [XMPPResultSet resultSetFromElement:self];
	}
	return self;
}

- (NSInteger)max
{
    if([self elementForName:@"max"])
    {
        return [[[self elementForName:@"max"] stringValue] intValue];
    }else{
        return NSNotFound;
    }
}

- (NSInteger)firstIndex
{
    if([[self elementForName:@"first"] attributeForName:@"index"])
    {
        return [[self elementForName:@"first"] attributeIntegerValueForName:@"index"];
    }
    else if([self elementForName:@"index"])
    {
        return [[[self elementForName:@"index"] stringValue] intValue];
    }
    else
    {
        return NSNotFound;
    }
}


- (NSString *)after
{
    return [[self elementForName:@"after"] stringValue];
}

- (NSString *)before
{
    return [[self elementForName:@"before"] stringValue];
}

- (NSInteger)count
{
    if([self elementForName:@"count"])
    {
        return [[[self elementForName:@"count"] stringValue] intValue];
    }
    else
    {
        return NSNotFound;
    }
}

- (NSString *)first
{
    return [[self elementForName:@"first"] stringValue];
}

- (NSString *)last
{
    return [[self elementForName:@"last"] stringValue];
}

@end
