#import <Foundation/Foundation.h>
#import "XMPPModule.h"

extern NSString *const XMPPSharedStatusShow;
extern NSString *const XMPPSharedStatusInvisible;
extern NSString *const XMPPSharedStatusStatus;

extern NSString *const XMPPSharedStatusShowAvailable;
extern NSString *const XMPPSharedStatusShowBusy;
extern NSString *const XMPPSharedStatusShowIdle;

@protocol XMPPSharedStatusDelegate;

@interface XMPPSharedStatus : XMPPModule

@property (nonatomic, assign) BOOL sharedStatusSupported;
@property (nonatomic, strong) NSDictionary *sharedStatus;

// Determines if the user is idle based on last received HID
// event, and sends the presence as away, if the user is idle.
@property (nonatomic, assign) BOOL assumeIdleUpdateResponsibility;

@property (nonatomic, strong) NSString *status;
@property (nonatomic, strong) NSString *show;
@property (nonatomic, assign) BOOL invisible;

// Convenience auto-updater for presence status.
// Does not use XMPPSharedStatus.
@property (nonatomic, copy) NSString *statusMessage;
@property (nonatomic, copy) NSString *statusAvailability;

- (void)updateSharedStatus:(NSString *)status
  				  show:(NSString *)show
				 invisible:(BOOL)invisible;

- (void)refreshSharedStatus;

@end

@protocol XMPPSharedStatusDelegate

@optional

// This delegate method is called when the server updates the shared
// status module with new status information, or upon manual refresh.
- (void)xmppSharedStatus:(XMPPSharedStatus *)sender didRecieveUpdatedStatus:(NSDictionary *)sharedStatus;

@end
