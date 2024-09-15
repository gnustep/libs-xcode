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

#import "PBXCommon.h"
#import "PBXBuildPhase.h"

@implementation PBXBuildPhase

- (instancetype) initWithFiles: (NSMutableArray *)files
	       buildActionMask: (NSString *)buildActionMask
	  runOnlyForDeployment: (NSString *)runOnlyForDeployment
			target: (PBXNativeTarget *)target
			  name: (NSString *)name
{
  self = [super init];
  if (self != nil)
    {
      [self setFiles: files];
      [self setBuildActionMask: buildActionMask];
      [self setRunOnlyForDeploymentPostprocessing: runOnlyForDeployment];
      [self setTarget: target];
      [self setName: name];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_files);
  RELEASE(_buildActionMask);
  RELEASE(_runOnlyForDeploymentPostprocessing);
  RELEASE(_target);
  RELEASE(_name);
  [super dealloc];
}

// Methods....
- (NSMutableArray *) files // getter
{
  return _files;
}

- (void) setFiles: (NSMutableArray *)object; // setter
{
  ASSIGN(_files,object);
}

- (NSString *) buildActionMask // getter
{
  return _buildActionMask;
}

- (void) setBuildActionMask: (NSString *)object; // setter
{
  ASSIGN(_buildActionMask,object);
}

- (NSString *) runOnlyForDeploymentPostprocessing // getter
{
  return _runOnlyForDeploymentPostprocessing;
}

- (void) setRunOnlyForDeploymentPostprocessing: (NSString *)object; // setter
{
  ASSIGN(_runOnlyForDeploymentPostprocessing,object);
}

- (BOOL) showEnvVarsInLog; // setter
{
  return _showEnvVarsInLog;
}

- (void) setShowEnvVarsInLog: (BOOL)flag
{
  _showEnvVarsInLog = flag;
}

- (void) setTarget: (PBXNativeTarget *)t
{
  _target = t;
}

- (PBXNativeTarget *) target
{
  return _target;
}

- (void) setName: (NSString *)n
{
  ASSIGN(_name, n);
}

- (NSString *) name
{
  return _name;
}

- (BOOL) build
{
  NSDebugLog(@"Abstract build... %@, %@", self, _files);
  return YES;
}

- (BOOL) generate
{
  NSLog(@"Abstract generate... %@, %@", self, _files);
  return YES;
}

- (BOOL) link
{
  NSLog(@"Abstract link... %@, %@", self, _files);
  return YES;
}

@end
