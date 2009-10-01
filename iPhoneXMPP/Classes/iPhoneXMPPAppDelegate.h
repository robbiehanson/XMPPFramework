//
//  iPhoneXMPPAppDelegate.h
//  iPhoneXMPP
//
//  Created by Robbie Hanson on 5/26/09.
//  Copyright Deusty Designs, LLC. 2009. All rights reserved.
//

#import <UIKit/UIKit.h>

@class XMPPClient;


@interface iPhoneXMPPAppDelegate : NSObject <UIApplicationDelegate>
{
	XMPPClient *xmppClient;
    
    UIWindow *window;
    UINavigationController *navigationController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UINavigationController *navigationController;

@end

