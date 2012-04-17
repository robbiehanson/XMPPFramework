//
//  TestElementReceiptAppDelegate.h
//  TestElementReceipt
//
//  Created by Robbie Hanson on 8/5/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TestElementReceiptAppDelegate : NSObject <NSApplicationDelegate> {
	__unsafe_unretained NSWindow *window;
}

@property (unsafe_unretained) IBOutlet NSWindow *window;

@end
