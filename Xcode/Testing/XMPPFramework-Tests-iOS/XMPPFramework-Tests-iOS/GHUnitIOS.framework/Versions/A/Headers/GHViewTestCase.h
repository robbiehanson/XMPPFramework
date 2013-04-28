//
//  GHViewTestCase.h
//  GHUnitIOS
//
//  Created by John Boiles on 10/20/11.
//  Copyright (c) 2011. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//

#import "GHTestCase.h"
#import <UIKit/UIKit.h>

/*!
 Assert that a view has not changed. Raises exception if the view has changed or if
 no image exists from previous test runs.

 @param view The view to verify
 */
#define GHVerifyView(view) \
do { \
if (![self isKindOfClass:[GHViewTestCase class]]) \
[[NSException ghu_failureWithName:@"GHInvalidTestException" \
inFile:[NSString stringWithUTF8String:__FILE__] \
atLine:__LINE__ \
reason:@"GHVerifyView can only be called from within a GHViewTestCase class"] raise]; \
[self verifyView:view filename:[NSString stringWithUTF8String:__FILE__] lineNumber:__LINE__]; \
} while (0)

/*!
 View verification test case.

 Supports GHVerifyView, which renders a view and compares it against a saved
 image from a previous test run.

     @interface MyViewTest : GHViewTestCase { }
     @end

     @implementation MyViewTest

     - (void)testMyView {
       MyView *myView = [[MyView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
       GHVerifyView(myView);
     }

     @end

 In order to record results across test runs, the PrepareUITests.sh script needs
 to be run as a build step. This script copies any test images (saved locally in
 $PROJECT_DIR/TestImages) to the app bundle so that calls to GHVerifyView have
 images from previous runs with which to compare.

 After changes to views are approved in the simulator, the CopyTestImages.sh script
 should be run manually in Terminal. This script copies any approved view changes
 back to the project directory. Images are saved with filenames of the following format:

     [test class name]-[test selector name]-[UIScreen scale]-[# of call to GHVerifyView in selector]-[view class name].png

 Note that because of differences in text rendering between retina and non-retina
 devices/simulators, different images are saved for test runs using retina then
 non-retina.

 Also note that there are commonly rendering differences across iOS versions.
 Therefore it is common for tests to fail when they are run using a different iOS
 version then the one that created the saved test image. This also applies to tests
 that are run at the command line (the xcodebuild flag '-sdk iphonesimulator'
 usually corresponds to the latest iOS simulator available).
 */
@interface GHViewTestCase : GHTestCase {
  NSInteger imageVerifyCount_;
}

/*!
 Clear all test images in the documents directory.
 */
+ (void)clearTestImages;

/*!
 Creates a UIImage from the passed in view. This can be useful for testing
 views that require images.

 @param view UIView to render
 @result UIImage of the rendered UIView
 */
+ (UIImage *)imageWithView:(UIView *)view;

/*!
 Save an approved view test image to the view test images directory.

 @param image Image to save
 @param filename Filename for the saved image
 */
+ (void)saveApprovedViewTestImage:(UIImage *)image filename:(NSString *)filename;

/*!
 Size for a given view. Subclasses can override this to provide custom sizes
 for views before rendering. The default implementation returns contentSize
 for scrollviews and returns self.frame.size for all other views.

 @param view View for which to calculate the size
 @result Size at which the view should be rendered
 */
- (CGSize)sizeForView:(UIView *)view;

/*!
 Called from the GHVerifyView macro. This method should not be called manually.
 Verifies that a view hasn't changed since the last time it was approved. Raises
 a GHViewChangeException if the view has changed. Raises a GHViewUnavailableException
 if there is no image from a previous run.

 @param view View to verify
 @param filename Filename of the call to GHVerifyView
 @param lineNumber Line number of the call to GHVerifyView
 */
- (void)verifyView:(UIView *)view filename:(NSString *)filename lineNumber:(int)lineNumber;

@end
