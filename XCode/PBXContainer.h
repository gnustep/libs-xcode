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

#ifndef __PBXContainer_h_GNUSTEP_INCLUDE
#define __PBXContainer_h_GNUSTEP_INCLUDE

#import <Foundation/Foundation.h>
#import "PBXCoder.h"

@interface PBXContainer : NSObject
{
  NSString *_archiveVersion;
  NSMutableDictionary *_classes;
  NSString *_objectVersion;
  NSMutableDictionary *_objects;
  id _rootObject;

  NSString *_filename;
  NSString *_parameter;
  NSString *_workspaceLink;
  NSString *_workspaceLibs;
  NSString *_workspaceIncludes;
}

/**
 * Initializes the container with the given root object.
 */
- (instancetype) initWithRootObject: (id)object;

/**
 * Sets the workspace includes path.
 */
- (void) setWorkspaceIncludes: (NSString *)i;

/**
 * Returns the workspace includes path.
 */
- (NSString *) workspaceIncludes;

/**
 * Sets the workspace libraries path.
 */
- (void) setWorkspaceLibs: (NSString *)l;

/**
 * Returns the workspace libraries path.
 */
- (NSString *) workspaceLibs;

/**
 * Sets the workspace link.
 */
- (void) setWorkspaceLink: (NSString *)w;

/**
 * Returns the workspace link.
 */
- (NSString *) workspaceLink;

/**
 * Sets the parameter for this container.
 */
- (void) setParameter: (NSString *)p;

/**
 * Returns the parameter for this container.
 */
- (NSString *) parameter;

/**
 * Sets the archive version for this container.
 */
- (void) setArchiveVersion: (NSString *)version;

/**
 * Returns the archive version for this container.
 */
- (NSString *) archiveVersion;

/**
 * Sets the classes dictionary for this container.
 */
- (void) setClasses: (NSMutableDictionary *)dict;

/**
 * Returns the classes dictionary for this container.
 */
- (NSMutableDictionary *) classes;

/**
 * Sets the object version for this container.
 */
- (void) setObjectVersion: (NSString *)version;

/**
 * Returns the object version for this container.
 */
- (NSString *) objectVersion;

/**
 * Sets the objects dictionary for this container.
 */
- (void) setObjects: (NSMutableDictionary *)dict;

/**
 * Returns the objects dictionary for this container.
 */
- (NSMutableDictionary *) objects;

/**
 * Sets the root object for this container.
 */
- (void) setRootObject: (id)object;

/**
 * Returns the root object for this container.
 */
- (id) rootObject;

/**
 * Sets the filename for this container.
 */
- (void) setFilename: (NSString *)fn;

/**
 * Returns the filename for this container.
 */
- (NSString *) filename;

/**
 * Builds the container.
 */
- (BOOL) build;

/**
 * Cleans the container.
 */
- (BOOL) clean;

/**
 * Installs the container.
 */
- (BOOL) install;

/**
 * Generates the container.
 */
- (BOOL) generate;

/**
 * Links the container.
 */
- (BOOL) link;

/**
 * Saves the container.
 */
- (BOOL) save;

@end

#endif
