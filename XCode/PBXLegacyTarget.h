/*
   Copyright (C) 2018, 2019, 2020, 2021 Free Software Foundation, Inc.

   Written by: Gregory John Casamento <greg.casamento@gmail.com>
   Date: 2022
   
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

#import "PBXTarget.h"

@class NSString;
@class NSMutableArray;

@interface PBXLegacyTarget : PBXTarget
{
  NSString *_buildArgumentsString;
  NSString *_buildToolPath;
  //  NSMutableArray *_dependencies;
  BOOL _passBuildSettingsInEnvironment;
}

/**
 * Returns the build arguments string for this legacy target.
 */
- (NSString *) buildArgumentsString;

/**
 * Sets the build arguments string for this legacy target.
 */
- (void) setBuildArgumentsString: (NSString *)string;

/**
 * Returns the build tool path for this legacy target.
 */
- (NSString *) buildToolPath;

/**
 * Sets the build tool path for this legacy target.
 */
- (void) setBuildToolPath: (NSString *)path;

/**
 * Returns whether to pass build settings in the environment.
 */
- (BOOL) passBuildSettingsInEnvironment;

/**
 * Sets whether to pass build settings in the environment.
 */
- (void) setPassBuildSettingsInEnvironment: (BOOL)f;

@end
