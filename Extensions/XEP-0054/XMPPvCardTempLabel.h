//
//  XMPPvCardTempLabel.h
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/9/11.
//  Copyright 2011 RF.com. All rights reserved.
//  Copyright 2010 Martin Morrison. All rights reserved.
//


#import <Foundation/Foundation.h>

#import "XMPPvCardTempAdrTypes.h"


@interface XMPPvCardTempLabel : XMPPvCardTempAdrTypes


@property (nonatomic, assign) NSArray *lines;


+ (XMPPvCardTempLabel *)vCardLabelFromElement:(NSXMLElement *)elem;


@end
