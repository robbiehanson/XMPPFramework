#import <CoreData/CoreData.h>

#if TARGET_OS_IPHONE
  #import "DDXML.h"
#endif

@class XMPPCapsResourceCoreDataStorageObject;


@interface XMPPCapsCoreDataStorageObject : NSManagedObject

@property (nonatomic, retain) NSXMLElement *capabilities;

@property (nonatomic, retain) NSString * hashStr;
@property (nonatomic, retain) NSString * hashAlgorithm;
@property (nonatomic, retain) NSString * capabilitiesStr;

@property (nonatomic, retain) NSSet * resources;

@end


@interface XMPPCapsCoreDataStorageObject (CoreDataGeneratedAccessors)

- (void)addResourcesObject:(XMPPCapsResourceCoreDataStorageObject *)value;
- (void)removeResourcesObject:(XMPPCapsResourceCoreDataStorageObject *)value;
- (void)addResources:(NSSet *)value;
- (void)removeResources:(NSSet *)value;

@end
