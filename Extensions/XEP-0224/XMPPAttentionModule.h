#import "XMPPModule.h"
#import "XMPPMessage+XEP_0224.h"

#define _XMPP_ATTENTION_MODULE_H

NS_ASSUME_NONNULL_BEGIN
@interface XMPPAttentionModule : XMPPModule

/**
 * Whether or not the module should respond to incoming attention request queries.
 * It you create multiple instances of this module, only one instance should respond to queries.
 * 
 * It is recommended you set this (if needed) before you activate the module.
 * The default value is YES.
 **/
@property (readwrite) BOOL respondsToQueries;

@end

@protocol XMPPAttentionDelegate
@optional
- (void)xmppAttention:(XMPPAttentionModule *)sender didReceiveAttentionHeadlineMessage:(XMPPMessage *)attentionRequest;
@end
NS_ASSUME_NONNULL_END
