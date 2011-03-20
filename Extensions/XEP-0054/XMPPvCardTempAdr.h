//
//  XMPPvCardTempAdr.h
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/9/11.
//  Copyright 2011 RF.com. All rights reserved.
//  Copyright 2010 Martin Morrison. All rights reserved.
//


#import <Foundation/Foundation.h>

#import "XMPPvCardTempAdrTypes.h"


@interface XMPPvCardTempAdr : XMPPvCardTempAdrTypes


@property (nonatomic, assign) NSString *pobox;
@property (nonatomic, assign) NSString *extendedAddress;
@property (nonatomic, assign) NSString *street;
@property (nonatomic, assign) NSString *locality;
@property (nonatomic, assign) NSString *region;
@property (nonatomic, assign) NSString *postalCode;
@property (nonatomic, assign) NSString *country;


+ (XMPPvCardTempAdr *)vCardAdrFromElement:(NSXMLElement *)elem;


@end
