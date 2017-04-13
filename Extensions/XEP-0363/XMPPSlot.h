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

/** Convenience property for putURL + putHeaders */
@property (nonatomic, readonly) NSURLRequest *putRequest;

/** HTTP headers, for example Authorization. name=value */
@property (nonatomic, readonly) NSDictionary<NSString*,NSString*> *putHeaders;
@property (nonatomic, readonly) NSURL *putURL;
@property (nonatomic, readonly) NSURL *getURL;

- (instancetype)initWithPutURL:(NSURL *)putURL getURL:(NSURL *)getURL putHeaders:(nullable NSDictionary<NSString*,NSString*>*)putHeaders NS_DESIGNATED_INITIALIZER;

/** Will return nil if iq does not contain slot */
- (nullable instancetype)initWithIQ:(XMPPIQ *)iq;

/** Not available, use designated initializer */
- (instancetype) init NS_UNAVAILABLE;

@property (nonatomic, readonly) NSString *put DEPRECATED_MSG_ATTRIBUTE("Use putURL instead.");
@property (nonatomic, readonly) NSString *get DEPRECATED_MSG_ATTRIBUTE("Use getURL instead.");
- (nullable instancetype)initWithPut:(NSString *)put andGet:(NSString *)get DEPRECATED_MSG_ATTRIBUTE("Use initWithPutURL:getURL:putHeaders: instead.");

@end
NS_ASSUME_NONNULL_END
