#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#if TARGET_OS_IPHONE
    #import <UIKit/UIKit.h>
#else
    #import <Cocoa/Cocoa.h>
#endif

#import "XMPPUser.h"
#import "XMPP.h"
#import "XMPPResourceCoreDataStorageObject.h"

@class XMPPGroupCoreDataStorageObject;


@interface XMPPUserCoreDataStorageObject : NSManagedObject <XMPPUser>
{
	NSInteger section;
}

@property (nonatomic, strong) XMPPJID *jid;
@property (nonatomic, strong) NSString * jidStr;
@property (nonatomic, strong) NSString * streamBareJidStr;

@property (nonatomic, strong) NSString * nickname;
@property (nonatomic, strong) NSString * displayName;
@property (nonatomic, strong) NSString * subscription;
@property (nonatomic, strong) NSString * ask;
@property (nonatomic, strong) NSNumber * unreadMessages;

#if TARGET_OS_IPHONE
@property (nonatomic, strong) UIImage *photo;
#else
@property (nonatomic, strong) NSImage *photo;
#endif

@property (nonatomic, assign) NSInteger section;
@property (nonatomic, strong) NSString * sectionName;
@property (nonatomic, strong) NSNumber * sectionNum;

@property (nonatomic, strong) NSSet * groups;
@property (nonatomic, strong) XMPPResourceCoreDataStorageObject * primaryResource;
@property (nonatomic, strong) NSSet * resources;

+ (id)insertInManagedObjectContext:(NSManagedObjectContext *)moc
                           withJID:(XMPPJID *)jid
                  streamBareJidStr:(NSString *)streamBareJidStr;

+ (id)insertInManagedObjectContext:(NSManagedObjectContext *)moc
                          withItem:(NSXMLElement *)item
                  streamBareJidStr:(NSString *)streamBareJidStr;

- (void)updateWithItem:(NSXMLElement *)item;
- (void)updateWithPresence:(XMPPPresence *)presence streamBareJidStr:(NSString *)streamBareJidStr;
- (void)recalculatePrimaryResource;

- (NSComparisonResult)compareByName:(XMPPUserCoreDataStorageObject *)another;
- (NSComparisonResult)compareByName:(XMPPUserCoreDataStorageObject *)another options:(NSStringCompareOptions)mask;

- (NSComparisonResult)compareByAvailabilityName:(XMPPUserCoreDataStorageObject *)another;
- (NSComparisonResult)compareByAvailabilityName:(XMPPUserCoreDataStorageObject *)another
                                        options:(NSStringCompareOptions)mask;

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
