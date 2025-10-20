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

#ifndef __PBXBuildPhase_h_GNUSTEP_INCLUDE
#define __PBXBuildPhase_h_GNUSTEP_INCLUDE

#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"
#import "PBXNativeTarget.h"

@interface PBXBuildPhase : NSObject
{
  NSMutableArray *_files;
  NSString *_buildActionMask;
  NSString *_runOnlyForDeploymentPostprocessing;
  BOOL _showEnvVarsInLog;
  PBXNativeTarget *_target;
  NSString *_name;
}

/**
 * Initializes the build phase with the given parameters.
 */
- (instancetype) initWithFiles: (NSMutableArray *)files
	       buildActionMask: (NSString *)buildActionMask
	  runOnlyForDeployment: (NSString *)runOnlyForDeployment
			target: (PBXNativeTarget *)target
                          name: (NSString *)name;

/**
 * Returns the files for this build phase.
 */
- (NSMutableArray *) files;

/**
 * Sets the files for this build phase.
 */
- (void) setFiles: (NSMutableArray *)object;

/**
 * Returns the build action mask for this build phase.
 */
- (NSString *) buildActionMask;

/**
 * Sets the build action mask for this build phase.
 */
- (void) setBuildActionMask: (NSString *)object;

/**
 * Returns whether to run only for deployment postprocessing.
 */
- (NSString *) runOnlyForDeploymentPostprocessing;

/**
 * Sets whether to run only for deployment postprocessing.
 */
- (void) setRunOnlyForDeploymentPostprocessing: (NSString *)object;

/**
 * Returns whether to show environment variables in the log.
 */
- (BOOL) showEnvVarsInLog;

/**
 * Sets whether to show environment variables in the log.
 */
- (void) setShowEnvVarsInLog: (BOOL)flag;

/**
 * Sets the target for this build phase.
 */
- (void) setTarget: (PBXNativeTarget *)t;

/**
 * Returns the target for this build phase.
 */
- (PBXNativeTarget *) target;

/**
 * Sets the name for this build phase.
 */
- (void) setName: (NSString *)n;

/**
 * Returns the name for this build phase.
 */
- (NSString *) name;

/**
 * Builds the build phase.
 */
- (BOOL) build;

/**
 * Generates the build phase.
 */
- (BOOL) generate;

/**
 * Links the build phase.
 */
- (BOOL) link;

/**
 * Returns all files including those from groups (like synchronized groups).
 * This method combines the regular files with files discovered from groups.
 */
- (NSArray *) allFiles;

/**
 * Returns files from groups that support the children method.
 * This includes PBXFileSystemSynchronizedRootGroup and other group types.
 */
- (NSArray *) filesFromGroups;

@end

#endif
