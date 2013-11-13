#import "NSXMLElement+XEP_0335.h"
#import "NSXMLElement+XMPP.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#define XEP_0335_NAME @"json"
#define XEP_0335_XMLNS @"urn:xmpp:json:0"

@implementation NSXMLElement (XEP_0335)

- (NSXMLElement *)JSONContainer
{
    if([self isJSONContainer])
    {
        return self;
    }
    else
    {
        return [self elementForName:XEP_0335_NAME xmlns:XEP_0335_XMLNS];
    }
}

- (BOOL)isJSONContainer
{
    if([[self name] isEqualToString:XEP_0335_NAME] && [[self xmlns] isEqualToString:XEP_0335_XMLNS])
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

- (BOOL)hasJSONContainer
{
    return [self elementForName:XEP_0335_NAME xmlns:XEP_0335_XMLNS] != nil;
}

- (NSString *)JSONContainerString
{
    return [[self JSONContainer] stringValue];
}

- (NSData *)JSONContainerData
{
    NSString *JSONContainerString = [self JSONContainerString];
    return [JSONContainerString dataUsingEncoding:NSUTF8StringEncoding];
}

- (id)JSONContainerObject
{
    NSData *JSONData = [self JSONContainerData];
    return [NSJSONSerialization JSONObjectWithData:JSONData options:0 error:nil];
}

- (void)addJSONContainerWithString:(NSString *)JSONContainerString
{
    if([JSONContainerString length])
    {
        NSXMLElement *container = [NSXMLElement elementWithName:XEP_0335_NAME xmlns:XEP_0335_XMLNS];
        [container setStringValue:JSONContainerString];
        [self addChild:container];
    }
}

- (void)addJSONContainerWithData:(NSData *)JSONContainerData
{
    if([JSONContainerData length])
    {
        NSString *JSONContainerString = [[NSString alloc] initWithData:JSONContainerData encoding:NSUTF8StringEncoding];
        [self addJSONContainerWithString:JSONContainerString];
    }
}

- (void)addJSONContainerWithObject:(id)JSONContainerObject
{
    if([NSJSONSerialization isValidJSONObject:JSONContainerObject])
    {
        NSData *JSONContainerData = [NSJSONSerialization dataWithJSONObject:JSONContainerObject options:0 error:nil];
        [self addJSONContainerWithData:JSONContainerData];
    }
}

@end
