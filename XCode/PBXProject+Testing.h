/*
   Copyright (C) 2026 Free Software Foundation, Inc.

   Written by: Daniel Boyd <danieljboyd@icloud.com>
   Date: 2026
   
   This file is part of the GNUstep XCode Library

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 USA.
*/

#import <Foundation/Foundation.h>

#import "PBXProject.h"

/**
 * Running a project's unit tests, as `buildtool test` (like `xcodebuild
 * test`): builds the project, then runs each unit-test target's bundle
 * with xctest (tools-xctest).
 */
@interface PBXProject (Testing)

/**
 * Builds the project, then runs its test targets. Options (all optional):
 * "target" (a test target's name), "scheme" (an .xcscheme in the project:
 * its testables, skipped and selected tests), "only" and "skip" (arrays of
 * xcodebuild identifiers, TestTarget[/TestClass[/testMethod]]). Without a
 * target or scheme, every unit-test target runs. A target whose
 * TEST_HOST names an application in the project runs inside it (xctest
 * -host). The XCTEST environment variable chooses the xctest program and
 * XCTEST_FLAGS adds options to it. Returns YES if every test passed.
 */
- (BOOL) testWithOptions: (NSDictionary *)options;

@end
