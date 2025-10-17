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

/**
 * Creates a record from the contents of the given file.
 */
+ (instancetype) recordWithContentsOfFile: (NSString *)path;

/**
 * Initializes the record with the contents of the given file.
 */
- (instancetype) initWithContentsOfFile: (NSString *)path;

/**
 * Initializes the record with the given dictionary.
 */
- (instancetype) initWithDictionary: (NSDictionary *)dict;

/**
 * Returns the dictionary for this record.
 */
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

/**
 * Initializes the file record with the given dictionary.
 */
- (instancetype) initWithDictonary: (NSDictionary *)dict;

/**
 * Initializes the file record with the given build file and path.
 */
- (instancetype) initWithFile: (PBXBuildFile *)f path: (NSString *)path;

/**
 * Creates a file record with the given build file and path.
 */
+ (instancetype) recordWithBuildFile: (PBXBuildFile *)f path: (NSString *)path;

/**
 * Sets the file name for this record.
 */
- (void) setFileName: (NSString *)fn;

/**
 * Returns the file name for this record.
 */
- (NSString *) fileName;

/**
 * Sets the date modified for this file.
 */
- (void) setDateModified: (NSDate *)d;

/**
 * Returns the date modified for this file.
 */
- (NSDate *) dateModified;

/**
 * Sets the date built for this file.
 */
- (void) setDateBuilt: (NSDate *)d;

/**
 * Returns the date built for this file.
 */
- (NSDate *) dateBuilt;

/**
 * Returns the file reference for this record.
 */
- (PBXFileReference *) fileReference;

@end

@interface GSXCBuildDatabase : NSObject
{
  NSMutableArray *_records;
  PBXTarget *_target;
}

/**
 * Creates a build database for the given target.
 */
+ (instancetype) buildDatabaseWithTarget: (PBXTarget *)target;

/**
 * Initializes the build database with the given target.
 */
- (instancetype) initWithTarget: (PBXTarget *)target;

/**
 * Sets the target for this database.
 */
- (void) setTarget: (PBXTarget *)t;

/**
 * Returns the target for this database.
 */
- (PBXTarget *) target;

/**
 * Adds a record to the database.
 */
- (void) addRecord: (GSXCRecord *)record;

/**
 * Returns all files in the database.
 */
- (NSArray *) files;

/**
 * Returns whether the database is empty.
 */
- (BOOL) isEmpty;

@end

#endif // GSXCBuildDatabase_H_INCLUDE
