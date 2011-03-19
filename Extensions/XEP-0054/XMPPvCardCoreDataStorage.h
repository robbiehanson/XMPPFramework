//
//  XMPPvCardCoreDataStorage.h
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/18/11.
//  Copyright (c) 2011 RF.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@class XMPPJID;
@class XMPPvCardAvatarCoreDataStorage;
@class XMPPvCardTempCoreDataStorage;
@class XMPPvCardTemp;


@interface XMPPvCardCoreDataStorage : NSManagedObject {
@private
}


@property (nonatomic, retain) NSString * jidStr;
@property (nonatomic, retain, readonly) NSString * photoHash;
@property (nonatomic, retain) NSDate * lastUpdated;
@property (nonatomic, retain) NSNumber * waitingForFetch;
@property (nonatomic, retain) XMPPvCardTempCoreDataStorage * vCardTempRel;
@property (nonatomic, retain) XMPPvCardAvatarCoreDataStorage * vCardAvatarRel;

@property (nonatomic, retain) NSData *photoData;
@property (nonatomic, retain) XMPPvCardTemp *vCardTemp;


+ (XMPPvCardCoreDataStorage *)fetchOrInsertvCardForJID:(XMPPJID *)jid
                                inManagedObjectContext:(NSManagedObjectContext *)moc;


@end
