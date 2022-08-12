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

// Methods....
- (PBXFileReference *) fileRef; // getter
- (void) setFileRef: (PBXFileReference *)object; // setter
- (NSMutableDictionary *) settings; // getter
- (void) setSettings: (NSMutableDictionary *)object; // setter
- (void) setPlatformFilter: (NSString *)f;
- (void) setTarget: (PBXNativeTarget *)t;

- (void) setTotalFiles: (NSUInteger)t;
- (void) setCurrentFile: (NSUInteger)n;

- (NSString *) path;
- (NSString *) buildPath;
- (BOOL) build;
- (BOOL) generate;

@end
