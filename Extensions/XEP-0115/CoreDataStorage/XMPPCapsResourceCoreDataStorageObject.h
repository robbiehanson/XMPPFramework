#import <CoreData/CoreData.h>

@class XMPPCapsCoreDataStorageObject;


@interface XMPPCapsResourceCoreDataStorageObject : NSManagedObject

@property (nonatomic, retain) NSString * jidStr;
@property (nonatomic, retain) NSString * streamBareJidStr;

@property (nonatomic, assign) BOOL haveFailed;
@property (nonatomic, retain) NSNumber * failed;

@property (nonatomic, retain) NSString * node;
@property (nonatomic, retain) NSString * ver;
@property (nonatomic, retain) NSString * ext;

@property (nonatomic, retain) NSString * hashStr;
@property (nonatomic, retain) NSString * hashAlgorithm;

@property (nonatomic, retain) XMPPCapsCoreDataStorageObject * caps;

@end
