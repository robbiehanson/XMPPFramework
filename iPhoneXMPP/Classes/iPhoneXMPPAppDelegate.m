//
//  iPhoneXMPPAppDelegate.m
//  iPhoneXMPP
//
//  Created by Robbie Hanson on 5/26/09.
//  Copyright Deusty Designs, LLC. 2009. All rights reserved.
//

#import "iPhoneXMPPAppDelegate.h"
#import "RootViewController.h"


@implementation iPhoneXMPPAppDelegate

@synthesize window;
@synthesize navigationController;


- (void)applicationDidFinishLaunching:(UIApplication *)application {
	
	// Configure and show the window
	[window addSubview:[navigationController view]];
	[window makeKeyAndVisible];
}


- (void)applicationWillTerminate:(UIApplication *)application {
	// Save data if appropriate
}


- (void)dealloc {
	[navigationController release];
	[window release];
	[super dealloc];
}

@end
