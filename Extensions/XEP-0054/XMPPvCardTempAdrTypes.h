//
//  XMPPvCardTempAdrTypes.h
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/9/11.
//  Copyright 2011 RF.com. All rights reserved.
//  Copyright 2010 Martin Morrison. All rights reserved.
//


#import <Foundation/Foundation.h>

#import "XMPPvCardTempBase.h"


@interface XMPPvCardTempAdrTypes : XMPPvCardTempBase


@property (nonatomic, assign, setter=setHome:) BOOL isHome;
@property (nonatomic, assign, setter=setWork:) BOOL isWork;
@property (nonatomic, assign, setter=setParcel:) BOOL isParcel;
@property (nonatomic, assign, setter=setPostal:) BOOL isPostal;
@property (nonatomic, assign, setter=setDomestic:) BOOL isDomestic;
@property (nonatomic, assign, setter=setInternational:) BOOL isInternational;
@property (nonatomic, assign, setter=setPreferred:) BOOL isPreferred;


@end
