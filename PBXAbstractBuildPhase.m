/*
   Copyright (C) 2018, 2019, 2020, 2021 Free Software Foundation, Inc.

   Written by: Gregory John Casament <greg.casamento@gmail.com>
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
#import "PBXAbstractBuildPhase.h"

@implementation PBXAbstractBuildPhase

- (void) dealloc
{
  RELEASE(files);
  RELEASE(buildActionMask);
  RELEASE(runOnlyForDeploymentPostprocessing);
  RELEASE(target);
  RELEASE(_name);
  [super dealloc];
}

// Methods....
- (NSMutableArray *) files // getter
{
  return files;
}

- (void) setFiles: (NSMutableArray *)object; // setter
{
  ASSIGN(files,object);
}

- (NSString *) buildActionMask // getter
{
  return buildActionMask;
}

- (void) setBuildActionMask: (NSString *)object; // setter
{
  ASSIGN(buildActionMask,object);
}

- (NSString *) runOnlyForDeploymentPostprocessing // getter
{
  return runOnlyForDeploymentPostprocessing;
}

- (void) setRunOnlyForDeploymentPostprocessing: (NSString *)object; // setter
{
  ASSIGN(runOnlyForDeploymentPostprocessing,object);
}

- (BOOL) showEnvVarsInLog; // setter
{
  return showEnvVarsInLog;
}

- (void) setEnvVarsInLog: (BOOL)flag
{
  showEnvVarsInLog = flag;
}

- (void) setTarget: (PBXNativeTarget *)t
{
  target = t;
}

- (PBXNativeTarget *) target
{
  return target;
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
  NSDebugLog(@"Abstract build... %@, %@",self, files);
  return YES;
}

- (BOOL) generate
{
  NSLog(@"Abstract generate... %@, %@",self,files);
  return YES;
}

@end
