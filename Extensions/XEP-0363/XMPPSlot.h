//
//  XMPPSlot.h
//  Mangosta
//
//  Created by Andres Canal on 5/19/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XMPPJID.h"
#import "XMPPIQ.h"

@import KissXML;

NS_ASSUME_NONNULL_BEGIN
@interface XMPPSlot: NSObject

@property (nonatomic, copy, readonly) NSString *put;
@property (nonatomic, copy, readonly) NSString *get;

- (instancetype)initWithPut:(NSString *)put andGet:(NSString *)get NS_DESIGNATED_INITIALIZER;

/** Will return nil if iq does not contain slot */
- (nullable instancetype)initWithIQ:(XMPPIQ *)iq;

/** Not available, use designated initializer */
- (instancetype) init NS_UNAVAILABLE;

@end
NS_ASSUME_NONNULL_END
