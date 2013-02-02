//
//  GHTestOutlineViewModel.h
//  GHUnit
//
//  Created by Gabriel Handford on 7/17/09.
//  Copyright 2009. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GHTestViewModel.h"
@class GHTestOutlineViewModel;

#define MIN_WINDOW_WIDTH (635.0)

@protocol GHTestOutlineViewModelDelegate <NSObject>
- (void)testOutlineViewModelDidChangeSelection:(GHTestOutlineViewModel *)testOutlineViewModel;
@end



@interface GHTestOutlineViewModel : GHTestViewModel 
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1060 // on lines like this to not confuse IB
  <NSOutlineViewDelegate, NSOutlineViewDataSource> 	
#endif
{	
  __unsafe_unretained id<GHTestOutlineViewModelDelegate> delegate_;
	NSButtonCell *editCell_;
}

@property (unsafe_unretained, nonatomic) id<GHTestOutlineViewModelDelegate> delegate;

@end
