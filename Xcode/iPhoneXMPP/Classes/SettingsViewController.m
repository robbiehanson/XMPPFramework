//
//  SettingsViewController.m
//  iPhoneXMPP
//
//  Created by Eric Chamberlain on 3/18/11.
//  Copyright 2011 RF.com. All rights reserved.
//

#import "SettingsViewController.h"


NSString *const kXMPPmyJID = @"kXMPPmyJID";
NSString *const kXMPPmyPassword = @"kXMPPmyPassword";


@implementation SettingsViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
      self.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
    }
    return self;
}

- (void)awakeFromNib {
  self.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
}

- (void)dealloc
{
  [_jidField release];
  [_passwordField release];
  [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  
  self.jidField.text = [[NSUserDefaults standardUserDefaults] stringForKey:kXMPPmyJID];
  self.passwordField.text = [[NSUserDefaults standardUserDefaults] stringForKey:kXMPPmyPassword];
}

- (void)viewWillDisappear:(BOOL)animated {
  if (self.jidField.text != nil) {
    [[NSUserDefaults standardUserDefaults] setObject:self.jidField.text forKey:kXMPPmyJID];
  } else {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kXMPPmyJID];
  }
  
  if (self.passwordField.text != nil) {
    [[NSUserDefaults standardUserDefaults] setObject:self.passwordField.text forKey:kXMPPmyPassword];
  } else {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kXMPPmyPassword];
  }
  
  [super viewWillDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Actions

- (IBAction)done:(id)sender
{
  [self dismissModalViewControllerAnimated:YES];
}

- (IBAction)hideKeyboard:(id)sender {
  [sender resignFirstResponder];
  [self done:sender];
}


#pragma mark - Getter/setter methods


@synthesize jidField = _jidField;
@synthesize passwordField = _passwordField;

@end
