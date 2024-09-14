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

#import "PBXLegacyTarget.h"

#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>

#import "xcsystem.h"

@implementation PBXLegacyTarget

- (void) dealloc
{
  RELEASE(_buildArgumentsString);
  RELEASE(_buildToolPath);
  //  RELEASE(_dependencies);
  [super dealloc];
}

- (NSString *) buildArgumentsString
{
  return _buildArgumentsString;
}

- (void) setBuildArgumentsString: (NSString *)string
{
  ASSIGN(_buildArgumentsString, string);
}

- (NSString *) buildToolPath
{
  return _buildToolPath;
}

- (void) setBuildToolPath: (NSString *)path
{
  ASSIGN(_buildToolPath, path);
}

/*
- (NSArray *) dependencies
{
  return _dependencies;
}

- (void) setDependencies: (NSArray *)deps
{
  ASSIGN(_dependencies, deps);
}
*/

- (BOOL) passBuildSettingsInEnvironment
{
  return _passBuildSettingsInEnvironment;
}

- (void) setPassBuildSettingsInEnvironment: (BOOL)f
{
  _passBuildSettingsInEnvironment = f;
}

- (BOOL) build
{
  return xcsystem(_buildToolPath);
}

- (BOOL) clean
{
  NSString *build_cmd = [_buildToolPath stringByAppendingString: @" clean"];
  return xcsystem(build_cmd);
}

- (BOOL) install
{
  NSString *build_cmd = [_buildToolPath stringByAppendingString: @" install"];
  return xcsystem(build_cmd);
}

@end
