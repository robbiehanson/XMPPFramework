//
//  XMPPvCardAvatarCoreDataStorage.h
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/18/11.
//  Copyright (c) 2011 RF.com. All rights reserved.
//
//  This class is so that we don't load the photo data into memory each time we touch the XMPPvCardCoreDataStorage object.

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class XMPPvCardCoreDataStorage;

@interface XMPPvCardAvatarCoreDataStorage : NSManagedObject {
@private
}
@property (nonatomic, retain) NSData * photoData;
@property (nonatomic, retain) XMPPvCardCoreDataStorage * vCard;

@end
