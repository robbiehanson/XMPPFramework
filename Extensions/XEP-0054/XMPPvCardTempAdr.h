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

NS_ASSUME_NONNULL_BEGIN
@interface XMPPvCardTempAdr : XMPPvCardTempAdrTypes

+ (XMPPvCardTempAdr *)vCardAdrFromElement:(NSXMLElement *)elem;

@property (nonatomic, strong, nullable) NSString *pobox;
@property (nonatomic, strong, nullable) NSString *extendedAddress;
@property (nonatomic, strong, nullable) NSString *street;
@property (nonatomic, strong, nullable) NSString *locality;
@property (nonatomic, strong, nullable) NSString *region;
@property (nonatomic, strong, nullable) NSString *postalCode;
@property (nonatomic, strong, nullable) NSString *country;

@end
NS_ASSUME_NONNULL_END
