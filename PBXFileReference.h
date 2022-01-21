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

@class PBXNativeTarget;

@interface PBXFileReference : NSObject
{
  NSString *sourceTree;
  NSString *lastKnownFileType;
  NSString *path;
  NSString *fileEncoding;
  NSString *explicitFileType;
  NSString *usesTabs;
  NSString *indentWidth;
  NSString *tabWidth;
  NSString *name;
  NSString *includeInIndex;
  NSString *comments;
  NSString *plistStructureDefinitionIdentifier;
  NSString *xcLanguageSpecificationIdentifier;
  NSString *lineEnding;
  NSString *wrapsLines;
  PBXNativeTarget *target;

  NSUInteger totalFiles;
  NSUInteger currentFile;
}

- (void) setTotalFiles: (NSUInteger)t;
- (void) setCurrentFile: (NSUInteger)n;


// Methods....
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

- (NSString *) productName;

// Build methods...
- (NSString *) buildPath;
- (BOOL) build;
- (BOOL) generate;

@end
