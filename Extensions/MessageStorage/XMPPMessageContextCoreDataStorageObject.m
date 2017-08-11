#import "XMPPMessageContextCoreDataStorageObject.h"
#import "XMPPMessageContextCoreDataStorageObject+Protected.h"

@interface XMPPMessageContextCoreDataStorageObject ()

@property (nonatomic, strong, nullable) XMPPMessageCoreDataStorageObject *message;
@property (nonatomic, copy, nullable) NSSet<XMPPMessageContextJIDItemCoreDataStorageObject *> *jidItems;
@property (nonatomic, copy, nullable) NSSet<XMPPMessageContextMarkerItemCoreDataStorageObject *> *markerItems;
@property (nonatomic, copy, nullable) NSSet<XMPPMessageContextStringItemCoreDataStorageObject *> *stringItems;
@property (nonatomic, copy, nullable) NSSet<XMPPMessageContextTimestampItemCoreDataStorageObject *> *timestampItems;

@end

@implementation XMPPMessageContextCoreDataStorageObject

@dynamic message, jidItems, markerItems, stringItems, timestampItems;

@end
