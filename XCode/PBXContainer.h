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

- (instancetype) initWithRootObject: (id)object;

- (void) setWorkspaceIncludes: (NSString *)i;
- (NSString *) workspaceIncludes;

- (void) setWorkspaceLibs: (NSString *)l;
- (NSString *) workspaceLibs;

- (void) setWorkspaceLink: (NSString *)w;
- (NSString *) workspaceLink;

- (void) setParameter: (NSString *)p;
- (NSString *) parameter;

- (void) setArchiveVersion: (NSString *)version;
- (NSString *) archiveVersion;

- (void) setClasses: (NSMutableDictionary *)dict;
- (NSMutableDictionary *) classes;

- (void) setObjectVersion: (NSString *)version;
- (NSString *) objectVersion;

- (void) setObjects: (NSMutableDictionary *)dict;
- (NSMutableDictionary *) objects;

- (void) setRootObject: (id)object;
- (id) rootObject;

- (void) setFilename: (NSString *)fn;
- (NSString *) filename;

// Build...			  
- (BOOL) build;
- (BOOL) clean;
- (BOOL) install;
- (BOOL) generate;
- (BOOL) link;
- (BOOL) save;

@end

#endif
