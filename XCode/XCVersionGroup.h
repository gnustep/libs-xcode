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


@interface XCVersionGroup : NSObject
{
  NSString *sourceTree;
  PBXFileReference *currentVersion;
  NSString *versionGroupType;
  NSString *path;
  NSMutableArray *children;
  NSUInteger _totalFiles;
}

/**
 * Returns the source tree for this version group.
 */
- (NSString *) sourceTree;

/**
 * Sets the source tree for this version group.
 */
- (void) setSourceTree: (NSString *)object;

/**
 * Returns the current version for this group.
 */
- (PBXFileReference *) currentVersion;

/**
 * Sets the current version for this group.
 */
- (void) setCurrentVersion: (PBXFileReference *)object;

/**
 * Returns the version group type.
 */
- (NSString *) versionGroupType;

/**
 * Sets the version group type.
 */
- (void) setVersionGroupType: (NSString *)object;

/**
 * Returns the path for this version group.
 */
- (NSString *) path;

/**
 * Sets the path for this version group.
 */
- (void) setPath: (NSString *)object;

/**
 * Returns the children of this version group.
 */
- (NSMutableArray *) children;

/**
 * Sets the children of this version group.
 */
- (void) setChildren: (NSMutableArray *)object;

/**
 * Sets the total number of files in this group.
 */
- (void) setTotalFiles: (NSUInteger)total;

/**
 * Returns the total number of files in this group.
 */
- (NSUInteger) totalFiles;

@end
