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

/**
 * Unarchives a project from the given file.
 */
+ (instancetype) unarchiveWithProjectFile: (NSString *)name;

/**
 * Initializes the coder with the given project file.
 */
- (instancetype) initWithProjectFile: (NSString *)name;

/**
 * Initializes the coder with the contents of the given file.
 */
- (instancetype) initWithContentsOfFile: (NSString *)name;

/**
 * Unarchives the project.
 */
- (id) unarchive;

/**
 * Unarchives an object for the given key.
 */
- (id) unarchiveObjectForKey: (NSString *)key;

/**
 * Unarchives an object from the given dictionary.
 */
- (id) unarchiveFromDictionary: (NSDictionary *)dictionary;

/**
 * Resolves array members for the given array.
 */
- (NSMutableArray *) resolveArrayMembers: (NSMutableArray *)array;

/**
 * Applies keys and values from the dictionary to the object.
 */
- (id) applyKeysAndValuesFromDictionary: (NSDictionary *)dictionary
                               toObject: (id)object;

/**
 * Returns the project root.
 */
- (NSString *) projectRoot;

/**
 * Returns the delegate for this coder.
 */
- (XCAbstractDelegate *) delegate;

/**
 * Sets the delegate for this coder.
 */
- (void) setDelegate: (XCAbstractDelegate *)delegate;

/**
 * Archives the project with the given root object.
 */
+ (instancetype) archiveWithRootObject: (id)obj;

/**
 * Initializes the coder with the given root object.
 */
- (instancetype) initWithRootObject: (id)obj;

/**
 * Archives the project.
 */
- (id) archive;

@end
