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

NS_ASSUME_NONNULL_BEGIN
@interface XMPPvCardTempAdrTypes : XMPPvCardTempBase


@property (nonatomic, assign) BOOL isHome;
@property (nonatomic, assign) BOOL isWork;
@property (nonatomic, assign) BOOL isParcel;
@property (nonatomic, assign) BOOL isPostal;
@property (nonatomic, assign) BOOL isDomestic;
@property (nonatomic, assign) BOOL isInternational;
@property (nonatomic, assign) BOOL isPreferred;


@end
NS_ASSUME_NONNULL_END
