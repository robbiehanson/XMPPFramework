#import "XMPPMessageCoreDataStorageObject.h"

@interface XMPPMessageCoreDataStorageObject (XEP_0245)

/**
 Returns the actual /me command action phrase.
 
 The action phrase is the result of stripping the "/me " body prefix.
 This method returns nil if the body cannot be interpreted as a /me command.
 */
- (nullable NSString *)meCommandText;

/**
 Returns the JID of the action subject.
 
 The relevant JID is either the value of the "from" attribute or, for outgoing messages,
 the stream JID associated with the message.
 This method returns nil if the body cannot be interpreted as a /me command.
 */
- (nullable XMPPJID *)meCommandSubjectJID;

@end
