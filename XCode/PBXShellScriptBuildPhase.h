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
#import "PBXBuildPhase.h"

@interface PBXShellScriptBuildPhase : PBXBuildPhase
{
  NSString *_shellPath;
  NSString *_shellScript;
  NSMutableArray *_inputPaths;
  NSMutableArray *_outputPaths;
  NSMutableArray *_inputFileListPaths;
  NSMutableArray *_outputFileListPaths;
}

/**
 * Returns the shell path for this shell script build phase.
 */
- (NSString *) shellPath;

/**
 * Sets the shell path for this shell script build phase.
 */
- (void) setShellPath: (NSString *)object;

/**
 * Returns the shell script for this build phase.
 */
- (NSString *) shellScript;

/**
 * Sets the shell script for this build phase.
 */
- (void) setShellScript: (NSString *)object;

/**
 * Returns the input paths for this build phase.
 */
- (NSMutableArray *) inputPaths;

/**
 * Sets the input paths for this build phase.
 */
- (void) setInputPaths: (NSMutableArray *)object;

/**
 * Returns the output paths for this build phase.
 */
- (NSMutableArray *) outputPaths;

/**
 * Sets the output paths for this build phase.
 */
- (void) setOutputPaths: (NSMutableArray *)object;

/**
 * Returns the input file list paths for this build phase.
 */
- (NSMutableArray *) inputFileListPaths;

/**
 * Sets the input file list paths for this build phase.
 */
- (void) setInputFileListPaths: (NSMutableArray *)object;

/**
 * Returns the output file list paths for this build phase.
 */
- (NSMutableArray *) outputFileListPaths;

/**
 * Sets the output file list paths for this build phase.
 */
- (void) setOutputFileListPaths: (NSMutableArray *)object;

/**
 * Builds the shell script build phase.
 */
- (BOOL) build;

@end
