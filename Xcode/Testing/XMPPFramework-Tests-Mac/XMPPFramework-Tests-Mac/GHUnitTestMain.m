//
//  GHUnitTestMain.m
//  GHUnit
//
//  Created by Gabriel Handford on 2/22/09.
//  Copyright 2009. All rights reserved.
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

#import <Foundation/Foundation.h>

#import <GHUnit/GHUnit.h>
#import <GHUnit/GHTestApp.h>

int main(int argc, char *argv[]) {
  @autoreleasepool {
  
  // Register any special test case classes
  //[[GHTesting sharedInstance] registerClassName:@"GHSpecialTestCase"];  
  
    int retVal = 0;
    // If GHUNIT_CLI is set we are using the command line interface and run the tests
    // Otherwise load the GUI app
    if (getenv("GHUNIT_CLI")) {
      retVal = [GHTestRunner run];
    } else {
      // To run all tests (from ENV)
      (void)[[GHTestApp alloc] init];
      // To run a different test suite:
      //GHTestSuite *suite = [GHTestSuite suiteWithTestFilter:@"GHSlowTest,GHAsyncTestCaseTest"];
      //GHTestApp *app = [[GHTestApp alloc] initWithSuite:suite];
      // Or set global:
      //GHUnitTest = @"GHSlowTest";
      [NSApp run];
    }
    return retVal;
  }
}
