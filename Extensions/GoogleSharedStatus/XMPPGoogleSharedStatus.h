#import <Foundation/Foundation.h>
#import "XMPPModule.h"

extern NSString *const XMPPGoogleSharedStatusShow;
extern NSString *const XMPPGoogleSharedStatusInvisible;
extern NSString *const XMPPGoogleSharedStatusStatus;

extern NSString *const XMPPGoogleSharedStatusShowAvailable;
extern NSString *const XMPPGoogleSharedStatusShowBusy;
extern NSString *const XMPPGoogleSharedStatusShowIdle;

@protocol XMPPGoogleSharedStatusDelegate;


#define _XMPP_GOOGLE_SHARED_STATUS_H

@interface XMPPGoogleSharedStatus : XMPPModule

@property (nonatomic, assign) BOOL sharedStatusSupported;
@property (nonatomic, strong) NSDictionary *sharedStatus;

// Determines if the user is idle based on last received HID
// event, and sends the presence as away, if the user is idle.
@property (nonatomic, assign) BOOL assumeIdleUpdateResponsibility;

@property (nonatomic, strong) NSString *status;
@property (nonatomic, strong) NSString *show;
@property (nonatomic, assign) BOOL invisible;

// Convenience auto-updater for presence status.
// Does not use XMPPGoogleSharedStatus.
@property (nonatomic, copy) NSString *statusMessage;
@property (nonatomic, copy) NSString *statusAvailability;

- (void)updateSharedStatus:(NSString *)status
					  show:(NSString *)show
				 invisible:(BOOL)invisible;

- (void)refreshSharedStatus;

@end

@protocol XMPPGoogleSharedStatusDelegate

@optional

// This delegate method is called when the server updates the shared
// status module with new status information, or upon manual refresh.
- (void)xmppGoogleSharedStatus:(XMPPGoogleSharedStatus *)sender didReceiveUpdatedStatus:(NSDictionary *)sharedStatus;

@end
