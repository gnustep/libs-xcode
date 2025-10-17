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

#ifndef __PBXFileReference_h_GNUSTEP_INCLUDE
#define __PBXFileReference_h_GNUSTEP_INCLUDE

#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"

@class PBXNativeTarget;

@interface PBXFileReference : NSObject
{
  NSString *_sourceTree;
  NSString *_lastKnownFileType;
  NSString *_path;
  NSString *_fileEncoding;
  NSString *_explicitFileType;
  NSString *_usesTabs;
  NSString *_indentWidth;
  NSString *_tabWidth;
  NSString *_name;
  NSString *_includeInIndex;
  NSString *_comments;
  NSString *_plistStructureDefinitionIdentifier;
  NSString *_xcLanguageSpecificationIdentifier;
  NSString *_lineEnding;
  NSString *_wrapsLines;
  PBXNativeTarget *_target;

  NSUInteger _totalFiles;
  NSUInteger _currentFile;
}

/**
 * Returns the file type determined from the given path.
 */
+ (NSString *) fileTypeFromPath: (NSString *)path;

/**
 * Returns the file extension for the given file type.
 */
+ (NSString *) extForFileType: (NSString *)type;

/**
 * Initializes the file reference with the given path.
 */
- (instancetype) initWithPath: (NSString *)path;

/**
 * Sets the total number of files.
 */
- (void) setTotalFiles: (NSUInteger)t;

/**
 * Sets the current file number.
 */
- (void) setCurrentFile: (NSUInteger)n;

/**
 * Returns the source tree for this file reference.
 */
- (NSString *) sourceTree;

/**
 * Sets the source tree for this file reference.
 */
- (void) setSourceTree: (NSString *)object;

/**
 * Returns the last known file type.
 */
- (NSString *) lastKnownFileType;

/**
 * Sets the last known file type.
 */
- (void) setLastKnownFileType: (NSString *)object;

/**
 * Returns the path of this file reference.
 */
- (NSString *) path;

/**
 * Sets the path of this file reference.
 */
- (void) setPath: (NSString *)object;

/**
 * Returns the file encoding.
 */
- (NSString *) fileEncoding;

/**
 * Sets the file encoding.
 */
- (void) setFileEncoding: (NSString *)object;

/**
 * Returns the explicit file type.
 */
- (NSString *) explicitFileType;

/**
 * Sets the explicit file type.
 */
- (void) setExplicitFileType: (NSString *)object;

/**
 * Returns the name of this file reference.
 */
- (NSString *) name;

/**
 * Sets the name of this file reference.
 */
- (void) setName: (NSString *)object;

/**
 * Sets the plist structure definition identifier.
 */
- (void) setPlistStructureDefinitionIdentifier: (NSString *)object;

/**
 * Returns the Xcode language specification identifier.
 */
- (NSString *) xcLanguageSpecificationIdentifier;

/**
 * Sets the Xcode language specification identifier.
 */
- (void) setXcLanguageSpecificationIdentifier: (NSString *)object;

/**
 * Returns the line ending style.
 */
- (NSString *) lineEnding;

/**
 * Sets the line ending style.
 */
- (void) setLineEnding: (NSString *)object;

/**
 * Sets the target associated with this file reference.
 */
- (void) setTarget: (PBXNativeTarget *)t;

/**
 * Sets whether lines should wrap.
 */
- (void) setWrapsLines: (NSString *)o;

/**
 * Returns whether this file should be included in the index.
 */
- (NSString *) includeInIndex;

/**
 * Sets whether this file should be included in the index.
 */
- (void) setIncludeInIndex: (NSString *)includeInIndex;

/**
 * Returns the product name.
 */
- (NSString *) productName;

/**
 * Returns the build path for this file reference.
 */
- (NSString *) buildPath;

/**
 * Builds the file reference.
 */
- (BOOL) build;

/**
 * Generates the file reference.
 */
- (BOOL) generate;

@end

#endif
