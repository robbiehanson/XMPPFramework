#import "XMPPStringPrep.h"
@import libidn;


@implementation XMPPStringPrep

+ (NSString *)prepNode:(NSString *)node
{
    if (!node) { return nil; }
    return [NSString idn_prepNode:node];
}

+ (NSString *)prepDomain:(NSString *)domain
{
    if (!domain) { return nil; }
    return [NSString idn_prepDomain:domain];
}

+ (NSString *)prepResource:(NSString *)resource
{
    if (!resource) { return nil; }
    return [NSString idn_prepResource:resource];
}

+ (NSString *)prepPassword:(NSString *)password
{
    if (!password) { return nil; }
    return [NSString idn_prepPassword:password];
}

@end
