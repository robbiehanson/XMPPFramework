#import "XMPPMessage.h"

@interface XMPPMessage (XEP_0333)

- (BOOL)hasChatMarker;

- (BOOL)hasMarkableChatMarker;
- (BOOL)hasReceivedChatMarker;
- (BOOL)hasDisplayedChatMarker;
- (BOOL)hasAcknowledgedChatMarker;

- (NSString *)chatMarker;
- (NSString *)chatMarkerID;

- (void)addMarkableChatMarker;
- (void)addReceivedChatMarkerWithID:(NSString *)elementID;
- (void)addDisplayedChatMarkerWithID:(NSString *)elementID;
- (void)addAcknowledgedChatMarkerWithID:(NSString *)elementID;

- (XMPPMessage *)generateReceivedChatMarker;
- (XMPPMessage *)generateDisplayedChatMarker;
- (XMPPMessage *)generateAcknowledgedChatMarker;

- (XMPPMessage *)generateReceivedChatMarkerIncludingThread:(BOOL)includingThread;
- (XMPPMessage *)generateDisplayedChatMarkerIncludingThread:(BOOL)includingThread;
- (XMPPMessage *)generateAcknowledgedChatMarkerIncludingThread:(BOOL)includingThread;

@end
