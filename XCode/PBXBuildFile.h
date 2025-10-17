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

#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"
#import "PBXFileReference.h"

@class PBXNativeTarget;

@interface PBXBuildFile : NSObject
{
  PBXFileReference *_fileRef;
  NSMutableDictionary *_settings;
  PBXNativeTarget *_target;
  NSString *_platformFilter;

  NSUInteger _totalFiles;
  NSUInteger _currentFile;
}

/**
 * Returns the file reference for this build file.
 */
- (PBXFileReference *) fileRef;

/**
 * Sets the file reference for this build file.
 */
- (void) setFileRef: (PBXFileReference *)object;

/**
 * Returns the settings for this build file.
 */
- (NSMutableDictionary *) settings;

/**
 * Sets the settings for this build file.
 */
- (void) setSettings: (NSMutableDictionary *)object;

/**
 * Sets the platform filter for this build file.
 */
- (void) setPlatformFilter: (NSString *)f;

/**
 * Sets the target for this build file.
 */
- (void) setTarget: (PBXNativeTarget *)t;

/**
 * Sets the total number of files.
 */
- (void) setTotalFiles: (NSUInteger)t;

/**
 * Sets the current file number.
 */
- (void) setCurrentFile: (NSUInteger)n;

/**
 * Returns the path for this build file.
 */
- (NSString *) path;

/**
 * Returns the build path for this build file.
 */
- (NSString *) buildPath;

/**
 * Builds the build file.
 */
- (BOOL) build;

/**
 * Generates the build file.
 */
- (BOOL) generate;

@end
