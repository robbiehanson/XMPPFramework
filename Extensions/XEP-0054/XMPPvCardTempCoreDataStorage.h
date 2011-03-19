//
//  XMPPvCardTempCoreDataStorage.h
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/18/11.
//  Copyright (c) 2011 RF.com. All rights reserved.
//
//  This class is so that we don't load the vCardTemp each time we need to touch the XMPPvCardCoreDataStorage object.
//  The vCardTemp abstraction also makes it easier to eventually add support vCard4 over XMPP (XEP-0292).

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "XMPPvcardTemp.h"

@class XMPPvCardCoreDataStorage;

@interface XMPPvCardTempCoreDataStorage : NSManagedObject {
@private
}
@property (nonatomic, retain) XMPPvCardTemp * vCardTemp;
@property (nonatomic, retain) XMPPvCardCoreDataStorage * vCard;

@end
