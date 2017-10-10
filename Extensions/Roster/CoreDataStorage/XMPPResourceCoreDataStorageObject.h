#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "XMPPResource.h"

@class XMPPStream;
@class XMPPPresence;
@class XMPPUserCoreDataStorageObject;


@interface XMPPResourceCoreDataStorageObject : NSManagedObject <XMPPResource>

@property (nonatomic, strong) XMPPJID *jid;
@property (nonatomic, strong) XMPPPresence *presence;

@property (nonatomic, assign) NSInteger priority;
@property (nonatomic, assign) XMPPPresenceShow intShow;

@property (nonatomic, strong) NSString * jidStr;
@property (nonatomic, strong) NSString * presenceStr;

@property (nonatomic, strong) NSString * streamBareJidStr;

@property (nonatomic, strong) NSString * type;
@property (nonatomic, strong) NSString * show;
@property (nonatomic, strong) NSString * status;

@property (nonatomic, strong) NSDate * presenceDate;

@property (nonatomic, strong) NSNumber * priorityNum;
@property (nonatomic, strong) NSNumber * showNum;

@property (nonatomic, strong) XMPPUserCoreDataStorageObject * user;

+ (id)insertInManagedObjectContext:(NSManagedObjectContext *)moc
                      withPresence:(XMPPPresence *)presence
                  streamBareJidStr:(NSString *)streamBareJidStr;

- (void)updateWithPresence:(XMPPPresence *)presence;

- (NSComparisonResult)compare:(id <XMPPResource>)another;

@end
