//
//  XMPPStanzaIdModule.h
//  XMPPFramework
//
//  Created by Chris Ballinger on 10/14/17.
//  Copyright © 2017 Chris Ballinger. All rights reserved.
//

#import "XMPPModule.h"
#import "XMPPMessage.h"

NS_ASSUME_NONNULL_BEGIN
@interface XMPPStanzaIdModule : XMPPModule

/**
 * Automatically add origin-id to outgoing messages.
 * If there is already an originId present, we will keep that one.
 *
 * Default: YES
 */
@property (atomic, readwrite) BOOL autoAddOriginId;

/**
 * Copy elementId to originId if present, otherwise generate new UUID
 * Disable this if your elementIds aren't globally unique.
 * Has no effect if autoAddOriginId is disabled.
 *
 * Default: YES
 */
@property (atomic, readwrite) BOOL copyElementIdIfPresent;


/**
 * Return NO in this block to prevent origin-id from being added to a specific message.
 */
@property (atomic, nullable, copy) BOOL (^filterBlock)(XMPPStream *stream, XMPPMessage* message);

@end

@protocol XMPPStanzaIdDelegate <NSObject>
- (void) stanzaIdModule:(XMPPStanzaIdModule*)sender
         didAddOriginId:(NSString*)originId
              toMessage:(XMPPMessage*)message;
@end
NS_ASSUME_NONNULL_END
