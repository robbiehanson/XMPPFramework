//
//  XMPPvCardTempEmail.h
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/9/11.
//  Copyright 2011 RF.com. All rights reserved.
//  Copyright 2010 Martin Morrison. All rights reserved.
//


#import <Foundation/Foundation.h>

#import "XMPPvCardTempBase.h"


@interface XMPPvCardTempEmail : XMPPvCardTempBase


@property (nonatomic, assign, setter=setHome:) BOOL isHome;
@property (nonatomic, assign, setter=setWork:) BOOL isWork;
@property (nonatomic, assign, setter=setInternet:) BOOL isInternet;
@property (nonatomic, assign, setter=setX400:) BOOL isX400;
@property (nonatomic, assign, setter=setPreferred:) BOOL isPreferred;
@property (nonatomic, assign) NSString *userid;


+ (XMPPvCardTempEmail *)vCardEmailFromElement:(NSXMLElement *)elem;


@end
