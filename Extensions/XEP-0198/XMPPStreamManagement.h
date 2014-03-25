//
//  XMPPStream+StreamManagement.h
//  iPhoneXMPP
//
//  Created by Vitaly on 03.03.14.
//
//
#import "XMPP.h"

@interface XMPPStreamManagement : XMPPModule<XMPPStreamDelegate>

@property(nonatomic, assign) BOOL allowResumeSession;

@end