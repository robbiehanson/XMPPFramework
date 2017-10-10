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

NS_ASSUME_NONNULL_BEGIN
@interface XMPPvCardTempEmail : XMPPvCardTempBase

+ (XMPPvCardTempEmail *)vCardEmailFromElement:(NSXMLElement *)elem;

@property (nonatomic, assign)   BOOL isHome;
@property (nonatomic, assign)   BOOL isWork;
@property (nonatomic, assign)   BOOL isInternet;
@property (nonatomic, assign)   BOOL isX400;
@property (nonatomic, assign)   BOOL isPreferred;

@property (nonatomic, strong, nullable) NSString *userid;


@end
NS_ASSUME_NONNULL_END
