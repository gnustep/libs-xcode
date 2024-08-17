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

@class XCAbstractDelegate;

@interface PBXCoder : NSObject
{
  // Objects...
  NSString *_fileName;
  NSString *_projectRoot;
  NSMutableDictionary *_dictionary;
  NSMutableDictionary *_objects;
  NSMutableDictionary *_objectCache;
  NSMutableDictionary *_parents;

  XCAbstractDelegate *_delegate;
  
  // Archiving...
  id _rootObject;
}

// Unarchiving...
+ (instancetype) unarchiveWithProjectFile: (NSString *)name;

- (instancetype) initWithProjectFile: (NSString *)name;

- (instancetype) initWithContentsOfFile: (NSString *)name;

- (id) unarchive;

- (id) unarchiveObjectForKey: (NSString *)key;

- (id) unarchiveFromDictionary: (NSDictionary *)dictionary;

- (NSMutableArray *) resolveArrayMembers: (NSMutableArray *)array;

- (id) applyKeysAndValuesFromDictionary: (NSDictionary *)dictionary
                               toObject: (id)object;
- (NSString *) projectRoot;

// Delegate
- (XCAbstractDelegate *) delegate;

- (void) setDelegate: (XCAbstractDelegate *)delegate;

// Archiving...
+ (instancetype) archiveWithRootObject: (id)obj;

- (instancetype) initWithRootObject: (id)obj;

- (id) archive;

@end
