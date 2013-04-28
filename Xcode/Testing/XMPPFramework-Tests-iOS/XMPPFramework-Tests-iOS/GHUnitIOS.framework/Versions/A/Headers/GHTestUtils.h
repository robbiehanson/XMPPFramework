//
//  GHTestUtils.h
//  GHUnitIOS
//
//  Created by John Boiles on 10/22/12.
//  Copyright 2012. All rights reserved.
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

#define GHRunWhile(__CONDITION__) GHRunUntilTimeoutWhileBlock(10.0, ^BOOL{ return (__CONDITION__); })

/*!
 Run the main run loop for a period of time. This is useful to give views time to
 render any asynchronously rendered views. However when possible, GHRunUntilTimeoutWhileBlock
 should be used instead since it will provide more determinate output.

 @param interval Interval for the main loop to run
 */
void GHRunForInterval(CFTimeInterval interval);

/*!
 Keep running the main runloop until whileBlock returns NO or timeout is reached.
 This is useful for waiting until certain parts of views render. This method should be
 used instead of putting GHRunForInterval in a while loop.

 @param timeout Maximum time to run the main loop before giving up
 @param whileBlock Block that returns YES if the main runloop should keep running
 */
void GHRunUntilTimeoutWhileBlock(CFTimeInterval timeout, BOOL(^whileBlock)());
