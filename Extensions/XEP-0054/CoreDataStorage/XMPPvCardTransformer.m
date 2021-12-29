//
//  XMPPvCardTransformer.m
//  XMPPFramework
//
//  Created by Tobias Ottenweller on 26.10.20.
//  Copyright © 2020 XMPPFramework. All rights reserved.
//

#import "XMPPvCardTransformer.h"
#import "XMPPvCardTemp.h"

@implementation XMPPvCardTransformer

+ (void)initialize
{
    [XMPPvCardTransformer registerTransformer];
}

+ (NSArray<Class> *)allowedTopLevelClasses
{
    return @[[XMPPvCardTemp class]];
}

+ (void)registerTransformer {
    NSString* name = @"XMPPvCardTransformer";
    XMPPvCardTransformer* transformer = [[XMPPvCardTransformer alloc] init];
    [NSValueTransformer setValueTransformer:transformer forName:name];
}

@end
