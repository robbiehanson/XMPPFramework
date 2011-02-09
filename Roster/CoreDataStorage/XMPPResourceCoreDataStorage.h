#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "XMPPResource.h"

@class XMPPUserCoreDataStorage;
@class XMPPPresence;


@interface XMPPResourceCoreDataStorage : NSManagedObject <XMPPResource>

@property (nonatomic, retain) XMPPJID *jid;
@property (nonatomic, retain) XMPPPresence *presence;

@property (nonatomic, assign) int priority;
@property (nonatomic, assign) int intShow;

@property (nonatomic, retain) NSString * jidStr;
@property (nonatomic, retain) NSString * presenceStr;

@property (nonatomic, retain) NSString * type;
@property (nonatomic, retain) NSString * show;
@property (nonatomic, retain) NSString * status;

@property (nonatomic, retain) NSDate * presenceDate;

@property (nonatomic, retain) NSNumber * priorityNum;
@property (nonatomic, retain) NSNumber * showNum;

@property (nonatomic, retain) XMPPUserCoreDataStorage * user;

+ (id)insertInManagedObjectContext:(NSManagedObjectContext *)moc withPresence:(XMPPPresence *)presence;

- (void)updateWithPresence:(XMPPPresence *)presence;

@end
