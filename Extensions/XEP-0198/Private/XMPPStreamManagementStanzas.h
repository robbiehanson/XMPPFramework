#import <Foundation/Foundation.h>
#import "XMPPElement.h"

/**
 * An outgoing stanza.
 *
 * The translation from element to stanzaId may be an asynchronous process,
 * so this structure is used to assist in the process.
**/
NS_ASSUME_NONNULL_BEGIN
@interface XMPPStreamManagementOutgoingStanza : NSObject <NSCopying, NSCoding>

- (instancetype)initAwaitingStanzaId;
- (instancetype)initWithStanzaId:(id)stanzaId;

@property (nonatomic, strong, readwrite, nullable) id stanzaId;
@property (nonatomic, assign, readwrite) BOOL awaitingStanzaId;

@end

#pragma mark -

/**
 * An incoming stanza.
 * 
 * The translation from element to stanzaId may be an asynchronous process,
 * so this structure is used to assist in the process.
**/
@interface XMPPStreamManagementIncomingStanza : NSObject

- (instancetype)initWithStanzaId:(nullable id)stanzaId isHandled:(BOOL)isHandled;

@property (nonatomic, strong, readwrite, nullable) id stanzaId;
@property (nonatomic, assign, readwrite) BOOL isHandled;

@end
NS_ASSUME_NONNULL_END
