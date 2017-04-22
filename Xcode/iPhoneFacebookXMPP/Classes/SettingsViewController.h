//
//  SettingsViewController.h
//  iPhoneFacebookXMPP
//
//  Created by Josh Benjamin on 3/27/12.
//  Copyright 2012 Monkey Inferno. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SettingsViewController : UIViewController 
@property (strong, nonatomic) IBOutlet UILabel *statusLabel;
@property (strong, nonatomic) IBOutlet UIButton *loginButton;

- (IBAction)done:(id)sender;
- (IBAction)login:(id)sender;
- (IBAction)disconnect:(id)sender;
@end
