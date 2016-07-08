//
//  ParserTestMacAppDelegate.h
//  ParserTestMac
//
//  Created by Robbie Hanson on 11/22/09.
//  Copyright 2009 Deusty Designs, LLC.. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ParserTestMacAppDelegate : NSObject <NSApplicationDelegate>
{
    __unsafe_unretained NSWindow *window;
}

@property (unsafe_unretained) IBOutlet NSWindow *window;

@end
