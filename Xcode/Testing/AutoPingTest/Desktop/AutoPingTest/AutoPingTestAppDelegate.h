//
//  AutoPingTestAppDelegate.h
//  AutoPingTest
//
//  Created by Robbie Hanson on 4/13/11.
//  Copyright 2011 Deusty, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "XMPP.h"
#import "XMPPAutoPing.h"


@interface AutoPingTestAppDelegate : NSObject <NSApplicationDelegate> {
@private
	XMPPStream *xmppStream;
	XMPPAutoPing *xmppAutoPing;
	
	__unsafe_unretained NSWindow *window;
}

@property (unsafe_unretained) IBOutlet NSWindow *window;

@end
