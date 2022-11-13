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

@class NSMutableDictionary, NSMutableArray;

@interface GSXCRecord : NSObject
{
  NSMutableDictionary *_dictionary;
}

+ (instancetype) recordWithContentsOfFile: (NSString *)path;

- (instancetype) initWithContentsOfFile: (NSString *)path;
- (instancetype) initWithDictionary: (NSDictionary *)dict;

- (NSDictionary *) dictionaryRepresentation;

@end

@interface GSXCFileRecord : GSXCRecord
{
  NSString *_fileName;
  NSDate *_dateModified;
  NSDate *_dateBuilt;
}

- (void) setFileName: (NSString *)fn;
- (NSString *) fileName;

- (void) setDateModified: (NSDate *)d;
- (NSDate *) dateModified;

- (void) setDateBuilt: (NSDate *)d;
- (NSDate *) dateBuilt;

@end

@interface GSXCBuildDatabase : NSObject
{
  NSMutableArray *_records;
}

- (void) addRecord: (GSXCRecord *)record;

@end

#endif // GSXCBuildDatabase_H_INCLUDE
