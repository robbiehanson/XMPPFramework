#import "XMPPMessageContextItemCoreDataStorageObject.h"
#import "XMPPMessageContextItemCoreDataStorageObject+Protected.h"
#import "XMPPJID.h"
#import "NSManagedObject+XMPPCoreDataStorage.h"

@interface XMPPMessageContextItemCoreDataStorageObject ()

@property (nonatomic, strong, nullable) XMPPMessageContextCoreDataStorageObject *contextElement;

@end

@implementation XMPPMessageContextItemCoreDataStorageObject

@dynamic contextElement;

+ (NSPredicate *)tagPredicateWithValue:(NSString *)value
{
    return [NSPredicate predicateWithFormat:@"%K = %@", NSStringFromSelector(@selector(tag)), value];
}

@end

@interface XMPPMessageContextJIDItemCoreDataStorageObject ()

@property (nonatomic, copy, nullable) NSString *valueDomain;
@property (nonatomic, copy, nullable) NSString *valueResource;
@property (nonatomic, copy, nullable) NSString *valueUser;

@end

@interface XMPPMessageContextJIDItemCoreDataStorageObject (CoreDataGeneratedPrimitiveAccessors)

- (XMPPJID *)primitiveValue;
- (void)setPrimitiveValue:(XMPPJID *)value;
- (void)setPrimitiveValueDomain:(NSString *)value;
- (void)setPrimitiveValueResource:(NSString *)value;
- (void)setPrimitiveValueUser:(NSString *)value;

@end

@implementation XMPPMessageContextJIDItemCoreDataStorageObject

@dynamic tag, valueDomain, valueResource, valueUser;

#pragma mark - value transient property

- (XMPPJID *)value
{
    [self willAccessValueForKey:NSStringFromSelector(@selector(value))];
    XMPPJID *value = [self primitiveValue];
    [self didAccessValueForKey:NSStringFromSelector(@selector(value))];
    
    if (value) {
        return value;
    }
    
    XMPPJID *newValue = [XMPPJID jidWithUser:self.valueUser domain:self.valueDomain resource:self.valueResource];
    [self setPrimitiveValue:newValue];
    
    return newValue;
}

- (void)setValue:(XMPPJID *)value
{
    if ([self.value isEqualToJID:value]) {
        return;
    }
    
    [self willChangeValueForKey:NSStringFromSelector(@selector(value))];
    [self willChangeValueForKey:NSStringFromSelector(@selector(valueDomain))];
    [self willChangeValueForKey:NSStringFromSelector(@selector(valueResource))];
    [self willChangeValueForKey:NSStringFromSelector(@selector(valueUser))];
    [self setPrimitiveValue:value];
    [self setPrimitiveValueDomain:value.domain];
    [self setPrimitiveValueResource:value.resource];
    [self setPrimitiveValueUser:value.user];
    [self didChangeValueForKey:NSStringFromSelector(@selector(valueDomain))];
    [self didChangeValueForKey:NSStringFromSelector(@selector(valueResource))];
    [self didChangeValueForKey:NSStringFromSelector(@selector(valueUser))];
    [self didChangeValueForKey:NSStringFromSelector(@selector(value))];
}

- (void)setValueDomain:(NSString *)valueDomain
{
    if ([self.valueDomain isEqualToString:valueDomain]) {
        return;
    }
    
    [self willChangeValueForKey:NSStringFromSelector(@selector(valueDomain))];
    [self willChangeValueForKey:NSStringFromSelector(@selector(value))];
    [self setPrimitiveValueDomain:valueDomain];
    [self setPrimitiveValue:nil];
    [self didChangeValueForKey:NSStringFromSelector(@selector(value))];
    [self didChangeValueForKey:NSStringFromSelector(@selector(valueDomain))];
}

- (void)setValueResource:(NSString *)valueResource
{
    if ([self.valueResource isEqualToString:valueResource]) {
        return;
    }
    
    [self willChangeValueForKey:NSStringFromSelector(@selector(valueResource))];
    [self willChangeValueForKey:NSStringFromSelector(@selector(value))];
    [self setPrimitiveValueResource:valueResource];
    [self setPrimitiveValue:nil];
    [self didChangeValueForKey:NSStringFromSelector(@selector(value))];
    [self didChangeValueForKey:NSStringFromSelector(@selector(valueResource))];
}

- (void)setValueUser:(NSString *)valueUser
{
    if ([self.valueUser isEqualToString:valueUser]) {
        return;
    }
    
    [self willChangeValueForKey:NSStringFromSelector(@selector(valueUser))];
    [self willChangeValueForKey:NSStringFromSelector(@selector(value))];
    [self setPrimitiveValueUser:valueUser];
    [self setPrimitiveValue:nil];
    [self didChangeValueForKey:NSStringFromSelector(@selector(value))];
    [self didChangeValueForKey:NSStringFromSelector(@selector(valueUser))];
}

#pragma mark - Public

+ (NSPredicate *)tagPredicateWithValue:(XMPPMessageContextJIDItemTag)value
{
    return [super tagPredicateWithValue:value];
}

+ (NSPredicate *)jidPredicateWithValue:(XMPPJID *)value compareOptions:(XMPPJIDCompareOptions)compareOptions
{
    return [self xmpp_jidPredicateWithDomainKeyPath:NSStringFromSelector(@selector(valueDomain))
                                    resourceKeyPath:NSStringFromSelector(@selector(valueResource))
                                        userKeyPath:NSStringFromSelector(@selector(valueUser))
                                              value:value
                                     compareOptions:compareOptions];
}

@end

@implementation XMPPMessageContextMarkerItemCoreDataStorageObject

@dynamic tag;

+ (NSPredicate *)tagPredicateWithValue:(XMPPMessageContextMarkerItemTag)value
{
    return [super tagPredicateWithValue:value];
}

@end

@implementation XMPPMessageContextStringItemCoreDataStorageObject

@dynamic tag, value;

+ (NSPredicate *)tagPredicateWithValue:(XMPPMessageContextStringItemTag)value
{
    return [super tagPredicateWithValue:value];
}

+ (NSPredicate *)stringPredicateWithValue:(NSString *)value
{
    return [NSPredicate predicateWithFormat:@"%K = %@", NSStringFromSelector(@selector(value)), value];
}

@end

@implementation XMPPMessageContextTimestampItemCoreDataStorageObject

@dynamic tag, value;

+ (NSPredicate *)tagPredicateWithValue:(XMPPMessageContextTimestampItemTag)value
{
    return [super tagPredicateWithValue:value];
}

+ (NSPredicate *)timestampRangePredicateWithStartValue:(NSDate *)startValue endValue:(NSDate *)endValue
{
    NSMutableArray *subpredicates = [[NSMutableArray alloc] init];
    
    if (startValue) {
        [subpredicates addObject:[NSPredicate predicateWithFormat:@"%K >= %@", NSStringFromSelector(@selector(value)), startValue]];
    }
    
    if (endValue) {
        [subpredicates addObject:[NSPredicate predicateWithFormat:@"%K <= %@", NSStringFromSelector(@selector(value)), endValue]];
    }
    
    return subpredicates.count == 1 ? subpredicates.firstObject : [NSCompoundPredicate andPredicateWithSubpredicates:subpredicates];
}

@end
