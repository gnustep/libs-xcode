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


@interface PBXBuildRule : NSObject
{
  NSString *_fileType;
  NSString *_isEditable;
  NSMutableArray *_outputFiles;
  NSString *_compilerSpec;
  NSString *_script;
  NSMutableArray *_inputFiles;
  NSString *_filePatterns;
}

/**
 * Returns the file type for this build rule.
 */
- (NSString *) fileType;

/**
 * Sets the file type for this build rule.
 */
- (void) setFileType: (NSString *)object;

/**
 * Returns whether this build rule is editable.
 */
- (NSString *) isEditable;

/**
 * Sets whether this build rule is editable.
 */
- (void) setIsEditable: (NSString *)object;

/**
 * Returns the output files for this build rule.
 */
- (NSMutableArray *) outputFiles;

/**
 * Sets the output files for this build rule.
 */
- (void) setOutputFiles: (NSMutableArray *)object;

/**
 * Returns the input files for this build rule.
 */
- (NSMutableArray *) inputFiles;

/**
 * Sets the input files for this build rule.
 */
- (void) setInputFiles: (NSMutableArray *)object;

/**
 * Returns the compiler specification for this build rule.
 */
- (NSString *) compilerSpec;

/**
 * Sets the compiler specification for this build rule.
 */
- (void) setCompilerSpec: (NSString *)object;

/**
 * Returns the script for this build rule.
 */
- (NSString *) script;

/**
 * Sets the script for this build rule.
 */
- (void) setScript: (NSString *)object;

/**
 * Returns the file patterns for this build rule.
 */
- (NSString *) filePatterns;

/**
 * Sets the file patterns for this build rule.
 */
- (void) setFilePatterns: (NSString *)object;

@end
