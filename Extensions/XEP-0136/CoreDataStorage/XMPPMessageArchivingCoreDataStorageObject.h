#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "XMPP.h"


@interface XMPPMessageArchivingCoreDataStorageObject : NSManagedObject

@property (nonatomic, retain) XMPPMessage * message;  // Transient (proper type, not on disk)
@property (nonatomic, retain) NSString * messageStr;  // Shadow (binary data, written to disk)

@property (nonatomic, retain) XMPPJID * bareJid;      // Transient (proper type, not on disk)
@property (nonatomic, retain) NSString * bareJidStr;  // Shadow (binary data, written to disk)

@property (nonatomic, strong) NSString * thread;

@property (nonatomic, strong) NSNumber * outgoing;    // Use isOutgoing
@property (nonatomic, assign) BOOL isOutgoing;

@property (nonatomic, strong) NSString * streamBareJidStr;

@end
