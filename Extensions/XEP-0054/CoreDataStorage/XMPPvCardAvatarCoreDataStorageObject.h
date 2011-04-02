//
//  XMPPvCardAvatarCoreDataStorageObject.h
//  XEP-0054 vCard-temp
//
//  Originally created by Eric Chamberlain on 3/18/11.
//
//  This class is so that we don't load the photoData each time we need to touch the XMPPvCardCoreDataStorageObject.

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class XMPPvCardCoreDataStorageObject;


@interface XMPPvCardAvatarCoreDataStorageObject : NSManagedObject

@property (nonatomic, retain) NSData * photoData;
@property (nonatomic, retain) XMPPvCardCoreDataStorageObject * vCard;

@end
