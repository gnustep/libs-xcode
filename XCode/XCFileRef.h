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

#import <Foundation/NSObject.h>

@class NSString;

@interface XCFileRef : NSObject
{
  NSString *_location;
  NSString *_workspaceLink;
  NSString *_workspaceIncludes;
  NSString *_workspaceLibs;
}

/**
 * Creates a new file reference instance.
 */
+ (instancetype) fileRef;

/**
 * Returns the workspace includes path.
 */
- (NSString *) workspaceIncludes;

/**
 * Sets the workspace includes path.
 */
- (void) setWorkspaceIncludes: (NSString *)wsInc;

/**
 * Returns the workspace link.
 */
- (NSString *) workspaceLink;

/**
 * Sets the workspace link.
 */
- (void) setWorkspaceLink: (NSString *)wsLink;

/**
 * Returns the workspace libraries path.
 */
- (NSString *) workspaceLibs;

/**
 * Sets the workspace libraries path.
 */
- (void) setWorkspaceLibs: (NSString *)wsLibs;

/**
 * Returns the location for this file reference.
 */
- (NSString *) location;

/**
 * Sets the location for this file reference.
 */
- (void) setLocation: (NSString *)loc;

/**
 * Returns the targets associated with this file reference.
 */
- (NSArray *) targets;

/**
 * Builds the file reference.
 */
- (BOOL) build;

/**
 * Cleans the file reference.
 */
- (BOOL) clean;

/**
 * Installs the file reference.
 */
- (BOOL) install;

/**
 * Links the file reference.
 */
- (BOOL) link;

@end
