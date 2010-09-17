#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "XMPPUser.h"

#if TARGET_OS_IPHONE
  #import "DDXML.h"
#endif

@class XMPPResourceCoreDataStorage;


@interface XMPPUserCoreDataStorage : NSManagedObject <XMPPUser>

@property (nonatomic, retain) XMPPJID *jid;
@property (nonatomic, assign) int section;

@property (nonatomic, retain) NSString * jidStr;
@property (nonatomic, retain) NSString * nickname;
@property (nonatomic, retain) NSString * displayName;
@property (nonatomic, retain) NSString * subscription;
@property (nonatomic, retain) NSString * ask;

@property (nonatomic, retain) NSNumber * sectionNum;

@property (nonatomic, retain) XMPPResourceCoreDataStorage * primaryResource;
@property (nonatomic, retain) NSSet * resources;

+ (id)insertInManagedObjectContext:(NSManagedObjectContext *)moc withItem:(NSXMLElement *)item;

- (void)updateWithItem:(NSXMLElement *)item;
- (void)updateWithPresence:(XMPPPresence *)presence;

@end

@interface XMPPUserCoreDataStorage (CoreDataGeneratedAccessors)

- (void)addResourcesObject:(XMPPResourceCoreDataStorage *)value;
- (void)removeResourcesObject:(XMPPResourceCoreDataStorage *)value;
- (void)addResources:(NSSet *)value;
- (void)removeResources:(NSSet *)value;

@end
