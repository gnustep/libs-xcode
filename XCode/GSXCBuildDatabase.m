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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSArray.h>

#import <XCode/GSXCBuildDatabase.h>


@implementation GSXCRecord : NSObject

+ (instancetype) recordWithContentsOfFile: (NSString *)path
{
  return [[self alloc] initWithContentsOfFile: path];
}

- (instancetype) initWithContentsOfFile: (NSString *)path
{
  return nil;
}

- (instancetype) initWithDictionary: (NSDictionary *)dict
{
  return nil;
}

- (NSDictionary *) dictionaryRepresentation
{
  return nil;
}

@end

@implementation GSXCFileRecord : GSXCRecord

- (void) setFileName: (NSString *)fn
{
  ASSIGN(_fileName, fn);
}

- (NSString *) fileName
{
  return _fileName;
}

- (void) setDateModified: (NSDate *)d
{
  ASSIGN(_dateModified, d);
}

- (NSDate *) dateModified
{
  return _dateModified;
}

- (void) setDateBuilt: (NSDate *)d
{
  ASSIGN(_dateBuilt, d);
}

- (NSDate *) dateBuilt
{
  return _dateBuilt;
}

@end

@implementation GSXCBuildDatabase : NSObject

- (void) addRecord: (GSXCRecord *)record
{
}

@end
