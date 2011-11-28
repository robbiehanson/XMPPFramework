#import <CoreData/CoreData.h>

@class XMPPCapsCoreDataStorageObject;


@interface XMPPCapsResourceCoreDataStorageObject : NSManagedObject

@property (nonatomic, strong) NSString * jidStr;
@property (nonatomic, strong) NSString * streamBareJidStr;

@property (nonatomic, assign) BOOL haveFailed;
@property (nonatomic, strong) NSNumber * failed;

@property (nonatomic, strong) NSString * node;
@property (nonatomic, strong) NSString * ver;
@property (nonatomic, strong) NSString * ext;

@property (nonatomic, strong) NSString * hashStr;
@property (nonatomic, strong) NSString * hashAlgorithm;

@property (nonatomic, strong) XMPPCapsCoreDataStorageObject * caps;

@end
