//
//  XMPPvCardTempTel.h
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/9/11.
//  Copyright 2011 RF.com. All rights reserved.
//  Copyright 2010 Martin Morrison. All rights reserved.
//


#import <Foundation/Foundation.h>

#import "XMPPvCardTempBase.h"

NS_ASSUME_NONNULL_BEGIN
@interface XMPPvCardTempTel : XMPPvCardTempBase


+ (XMPPvCardTempTel *)vCardTelFromElement:(NSXMLElement *)elem;

@property (nonatomic, assign)   BOOL isHome;
@property (nonatomic, assign)   BOOL isWork;
@property (nonatomic, assign)   BOOL isVoice;
@property (nonatomic, assign)   BOOL isFax;
@property (nonatomic, assign)   BOOL isPager;
@property (nonatomic, assign)   BOOL hasMessaging;
@property (nonatomic, assign)   BOOL isCell;
@property (nonatomic, assign)   BOOL isVideo;
@property (nonatomic, assign)   BOOL isBBS;
@property (nonatomic, assign)   BOOL isModem;
@property (nonatomic, assign)   BOOL isISDN;
@property (nonatomic, assign)   BOOL isPCS;
@property (nonatomic, assign)   BOOL isPreferred;

@property (nonatomic, nullable) NSString *number;

@end
NS_ASSUME_NONNULL_END
