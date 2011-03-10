//
//  XMPPvCardLabel.h
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/9/11.
//  Copyright 2011 RF.com. All rights reserved.
//  Copyright 2010 Martin Morrison. All rights reserved.
//


#import <Foundation/Foundation.h>

#import "XMPPvCardAdrTypes.h"


@interface XMPPvCardLabel : XMPPvCardAdrTypes


@property (nonatomic, assign) NSArray *lines;


+ (XMPPvCardLabel *)vCardLabelFromElement:(NSXMLElement *)elem;


@end
