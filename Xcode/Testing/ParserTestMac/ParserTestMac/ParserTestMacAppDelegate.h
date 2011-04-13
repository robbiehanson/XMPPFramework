//
//  ParserTestMacAppDelegate.h
//  ParserTestMac
//
//  Created by Robbie Hanson on 4/13/11.
//  Copyright 2011 Deusty, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ParserTestMacAppDelegate : NSObject <NSApplicationDelegate> {
@private
	NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
