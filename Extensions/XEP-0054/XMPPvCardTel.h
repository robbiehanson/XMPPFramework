//
//  XMPPvCardTel.h
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/9/11.
//  Copyright 2011 RF.com. All rights reserved.
//  Copyright 2010 Martin Morrison. All rights reserved.
//


#import <Foundation/Foundation.h>

#import "XMPPvCardBase.h"


@interface XMPPvCardTel : XMPPvCardBase


@property (nonatomic, assign, setter=setHome) BOOL isHome;
@property (nonatomic, assign, setter=setWork) BOOL isWork;
@property (nonatomic, assign, setter=setVoice) BOOL isVoice;
@property (nonatomic, assign, setter=setFax) BOOL isFax;
@property (nonatomic, assign, setter=setPager) BOOL isPager;
@property (nonatomic, assign, setter=setMessaging) BOOL hasMessaging;
@property (nonatomic, assign, setter=setCell) BOOL isCell;
@property (nonatomic, assign, setter=setVideo) BOOL isVideo;
@property (nonatomic, assign, setter=setBBS) BOOL isBBS;
@property (nonatomic, assign, setter=setModem) BOOL isModem;
@property (nonatomic, assign, setter=setISDN) BOOL isISDN;
@property (nonatomic, assign, setter=setPCS) BOOL isPCS;
@property (nonatomic, assign, setter=setPreferred) BOOL isPreferred;
@property (nonatomic, assign) NSString *number;


+ (XMPPvCardTel *)vCardTelFromElement:(NSXMLElement *)elem;


@end
