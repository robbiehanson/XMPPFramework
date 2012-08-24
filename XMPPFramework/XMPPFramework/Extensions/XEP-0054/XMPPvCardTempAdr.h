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

+ (XMPPvCardTempAdr *)vCardAdrFromElement:(NSXMLElement *)elem;

@property (nonatomic, weak) NSString *pobox;
@property (nonatomic, weak) NSString *extendedAddress;
@property (nonatomic, weak) NSString *street;
@property (nonatomic, weak) NSString *locality;
@property (nonatomic, weak) NSString *region;
@property (nonatomic, weak) NSString *postalCode;
@property (nonatomic, weak) NSString *country;

@end
