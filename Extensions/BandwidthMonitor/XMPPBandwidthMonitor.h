/**
 * Simple XMPP module that tracks average bandwidth of the xmpp stream.
 * 
 * For now, this is a really simple module.
 * But perhaps in the future, as developers adapt this module,
 * they will open source their additions and improvements.
**/

#import <Foundation/Foundation.h>
#import "XMPP.h"

#define _XMPP_BANDWIDTH_MONITOR_H

@interface XMPPBandwidthMonitor : XMPPModule

@property (readonly) double outgoingBandwidth;
@property (readonly) double incomingBandwidth;

@end
