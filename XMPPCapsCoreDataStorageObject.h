#import <CoreData/CoreData.h>

@class XMPPCapsResourceCoreDataStorageObject;
@class XMPPIQ;


@interface XMPPCapsCoreDataStorageObject : NSManagedObject

@property (nonatomic, retain) XMPPIQ *capabilities;

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
