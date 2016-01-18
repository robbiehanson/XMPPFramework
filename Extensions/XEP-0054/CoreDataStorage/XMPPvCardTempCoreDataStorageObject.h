//
//  XMPPvCardTempCoreDataStorageObject.h
//  XEP-0054 vCard-temp
//
//  Oringally created by Eric Chamberlain on 3/18/11.
//
//  This class is so that we don't load the vCardTemp each time we need to touch the XMPPvCardCoreDataStorageObject.
//  The vCardTemp abstraction also makes it easier to eventually add support for vCard4 over XMPP (XEP-0292).

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "XMPPvCardTemp.h"

@class XMPPvCardCoreDataStorageObject;


@interface XMPPvCardTempCoreDataStorageObject : NSManagedObject

@property (nonatomic, strong) XMPPvCardTemp * vCardTemp;
@property (nonatomic, strong) XMPPvCardCoreDataStorageObject * vCard;

@end
