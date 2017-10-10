#import "XMPPMessage.h"

NS_ASSUME_NONNULL_BEGIN
@interface XMPPMessage (XEP_0333)

@property (nonatomic, readonly) BOOL hasChatMarker;

@property (nonatomic, readonly) BOOL hasMarkableChatMarker;
@property (nonatomic, readonly) BOOL hasReceivedChatMarker;
@property (nonatomic, readonly) BOOL hasDisplayedChatMarker;
@property (nonatomic, readonly) BOOL hasAcknowledgedChatMarker;

@property (nonatomic, readonly, nullable) NSString *chatMarker;
@property (nonatomic, readonly, nullable) NSString *chatMarkerID;

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
NS_ASSUME_NONNULL_END
