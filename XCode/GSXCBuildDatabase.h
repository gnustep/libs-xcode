/*
   Copyright (C) 2022 Free Software Foundation, Inc.

   Written by: Gregory John Casamento <greg.casamento@gmail.com>
   Date: Nov 2022
   
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

#ifndef GSXCBuildDatabase_H_INCLUDE
#define GSXCBuildDatabase_H_INCLUDE

#import <Foundation/NSObject.h>

@class NSMutableDictionary, NSMutableArray, PBXTarget;
@class NSDate, PBXBuildFile, PBXFileReference;

@interface GSXCRecord : NSObject <NSCopying>
{
  NSMutableDictionary *_dictionary;
}

+ (instancetype) recordWithContentsOfFile: (NSString *)path;

- (instancetype) initWithContentsOfFile: (NSString *)path;
- (instancetype) initWithDictionary: (NSDictionary *)dict;

- (NSDictionary *) dictionary;

@end

@interface GSXCFileRecord : GSXCRecord
{
  NSString *_fileName;
  NSDate *_dateModified;
  NSDate *_dateBuilt;
  PBXBuildFile *_buildFile;
  PBXFileReference *_fileReference;
}

- (instancetype) initWithDictonary: (NSDictionary *)dict;
- (instancetype) initWithFile: (PBXBuildFile *)f path: (NSString *)path;
+ (instancetype) recordWithBuildFile: (PBXBuildFile *)f path: (NSString *)path;

- (void) setFileName: (NSString *)fn;
- (NSString *) fileName;

- (void) setDateModified: (NSDate *)d;
- (NSDate *) dateModified;

- (void) setDateBuilt: (NSDate *)d;
- (NSDate *) dateBuilt;

- (PBXFileReference *) fileReference;

@end

@interface GSXCBuildDatabase : NSObject
{
  NSMutableArray *_records;
  PBXTarget *_target;
}

+ (instancetype) buildDatabaseWithTarget: (PBXTarget *)target;
- (instancetype) initWithTarget: (PBXTarget *)target;

- (void) setTarget: (PBXTarget *)t;
- (PBXTarget *) target;

- (void) addRecord: (GSXCRecord *)record;

- (NSArray *) files;

- (BOOL) isEmpty;

@end

#endif // GSXCBuildDatabase_H_INCLUDE
