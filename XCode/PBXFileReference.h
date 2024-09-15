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

+ (NSString *) fileTypeFromPath: (NSString *)path;
+ (NSString *) extForFileType: (NSString *)type;
- (instancetype) initWithPath: (NSString *)path;

- (void) setTotalFiles: (NSUInteger)t;
- (void) setCurrentFile: (NSUInteger)n;

- (NSString *) sourceTree; // getter
- (void) setSourceTree: (NSString *)object; // setter
- (NSString *) lastKnownFileType; // getter
- (void) setLastKnownFileType: (NSString *)object; // setter
- (NSString *) path; // getter
- (void) setPath: (NSString *)object; // setter
- (NSString *) fileEncoding; // getter
- (void) setFileEncoding: (NSString *)object; // setter
- (NSString *) explicitFileType;
- (void) setExplicitFileType: (NSString *)object;
- (NSString *) name;
- (void) setName: (NSString *)object;
- (void) setPlistStructureDefinitionIdentifier: (NSString *)object;
- (NSString *) xcLanguageSpecificationIdentifier;
- (void) setXcLanguageSpecificationIdentifier: (NSString *)object;
- (NSString *) lineEnding;
- (void) setLineEnding: (NSString *)object;
- (void) setTarget: (PBXNativeTarget *)t;
- (void) setWrapsLines: (NSString *)o;
- (NSString *) includeInIndex;
- (void) setIncludeInIndex: (NSString *)includeInIndex;
- (NSString *) productName;

// Build methods...
- (NSString *) buildPath;
- (BOOL) build;
- (BOOL) generate;

@end

#endif
