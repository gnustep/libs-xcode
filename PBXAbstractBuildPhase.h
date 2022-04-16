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
*/ #import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"
#import "PBXNativeTarget.h"

@interface PBXAbstractBuildPhase : NSObject
{
  NSMutableArray *_files;
  NSString *_buildActionMask;
  NSString *runOnlyForDeploymentPostprocessing;
  BOOL showEnvVarsInLog;
  PBXNativeTarget *target;
  NSString *_name;
}

// Methods....
- (NSMutableArray *) files; // getter
- (void) setFiles: (NSMutableArray *)object; // setter

- (NSString *) buildActionMask; // getter
- (void) setBuildActionMask: (NSString *)object; // setter

- (NSString *) runOnlyForDeploymentPostprocessing; // getter
- (void) setRunOnlyForDeploymentPostprocessing: (NSString *)object; // setter

- (BOOL) showEnvVarsInLog; // setter
- (void) setEnvVarsInLog: (BOOL)flag;

- (void) setTarget: (PBXNativeTarget *)t;
- (PBXNativeTarget *) target;

- (void) setName: (NSString *)n;
- (NSString *) name;

// build
- (BOOL) build;
- (BOOL) generate;

@end
