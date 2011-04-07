#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "XMPPUser.h"

#if TARGET_OS_IPHONE
  #import "DDXML.h"
#endif

@class XMPPStream;
@class XMPPGroupCoreDataStorageObject;
@class XMPPResourceCoreDataStorageObject;


@interface XMPPUserCoreDataStorageObject : NSManagedObject <XMPPUser>
{
  NSInteger section;
}

@property (nonatomic, retain) XMPPJID *jid;
@property (nonatomic, retain) NSString * jidStr;
@property (nonatomic, retain) NSString * streamBareJidStr;

@property (nonatomic, retain) NSString * nickname;
@property (nonatomic, retain) NSString * displayName;
@property (nonatomic, retain) NSString * subscription;
@property (nonatomic, retain) NSString * ask;
@property (nonatomic, retain) NSNumber * unreadMessages;

#if TARGET_OS_IPHONE
@property (nonatomic, retain) UIImage *photo;
#else
@property (nonatomic, retain) NSImage *photo;
#endif

@property (nonatomic, assign) NSInteger section;
@property (nonatomic, retain) NSString * sectionName;
@property (nonatomic, retain) NSNumber * sectionNum;

@property (nonatomic, retain) NSSet * groups;
@property (nonatomic, retain) XMPPResourceCoreDataStorageObject * primaryResource;
@property (nonatomic, retain) NSSet * resources;

+ (id)insertInManagedObjectContext:(NSManagedObjectContext *)moc
                          withItem:(NSXMLElement *)item
                  streamBareJidStr:(NSString *)streamBareJidStr;

- (void)updateWithItem:(NSXMLElement *)item;
- (void)updateWithPresence:(XMPPPresence *)presence streamBareJidStr:(NSString *)streamBareJidStr;

@end

@interface XMPPUserCoreDataStorageObject (CoreDataGeneratedAccessors)

- (void)addResourcesObject:(XMPPResourceCoreDataStorageObject *)value;
- (void)removeResourcesObject:(XMPPResourceCoreDataStorageObject *)value;
- (void)addResources:(NSSet *)value;
- (void)removeResources:(NSSet *)value;

- (void)addGroupsObject:(XMPPGroupCoreDataStorageObject *)value;
- (void)removeGroupsObject:(XMPPGroupCoreDataStorageObject *)value;
- (void)addGroups:(NSSet *)value;
- (void)removeGroups:(NSSet *)value;

@end
