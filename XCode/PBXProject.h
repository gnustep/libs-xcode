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

#ifndef __PBXProject_h_GNUSTEP_INCLUDE
#define __PBXProject_h_GNUSTEP_INCLUDE

#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"
#import "XCConfigurationList.h"
#import "PBXGroup.h"
#import "PBXGroup.h"

@class PBXContainer;

@interface PBXProject : NSObject
{
  NSString *_developmentRegion;
  NSMutableArray *_knownRegions;
  NSString *_compatibilityVersion;
  NSMutableArray *_projectReferences;
  NSMutableArray *_targets;
  NSString *_projectDirPath;
  NSString *_projectRoot;
  XCConfigurationList *_buildConfigurationList;
  PBXGroup *_mainGroup;
  NSString *_hasScannedForEncodings;
  PBXGroup *_productRefGroup;
  PBXContainer *_container;
  NSDictionary *_attributes;
  NSDictionary *_ctx;

  NSString *_filename;
  NSMutableArray *_arrangedTargets;
  BOOL _minimizedProjectReferenceProxies;
  NSString *_preferredProjectObjectVersion;
}

// Methods....
- (BOOL) minimizedProjectReferenceProxies; // getter
- (void) setMinimizedProjectReferenceProxies: (BOOL)flag; // setter

- (NSString *) preferredProjectObjectVersion; // getter
- (void) setPreferredProjectObjectVersion: (NSString *)object; // setter

- (NSString *) developmentRegion; // getter
- (void) setDevelopmentRegion: (NSString *)object; // setter

- (NSMutableArray *) knownRegions; // getter
- (void) setKnownRegions: (NSMutableArray *)object; // setter

- (NSString *) compatibilityVersion; // getter
- (void) setCompatibilityVersion: (NSString *)object; // setter

- (NSMutableArray *) projectReferences; // getter
- (void) setProjectReferences: (NSMutableArray *)object; // setter

- (NSMutableArray *) targets; // getter
- (void) setTargets: (NSMutableArray *)object; // setter

- (NSString *) projectDirPath; // getter
- (void) setProjectDirPath: (NSString *)object; // setter

- (NSString *) projectRoot; // getter
- (void) setProjectRoot: (NSString *)object; // setter

- (XCConfigurationList *) buildConfigurationList; // getter
- (void) setBuildConfigurationList: (XCConfigurationList *)object; // setter

- (PBXGroup *) mainGroup; // getter
- (void) setMainGroup: (PBXGroup *)object; // setter

- (NSString *) hasScannedForEncodings; // getter
- (void) setHasScannedForEncodings: (NSString *)object; // setter

- (PBXGroup *) productRefGroup; // getter
- (void) setProductRefGroup: (PBXGroup *)object; // setter

- (PBXContainer *) container;
- (void) setContainer: (PBXContainer *)container;

- (void) setContext: (NSDictionary *)ctx;
- (NSDictionary *) context;

- (void) setFilename: (NSString *)fn;
- (NSString *) filename;

// calculate dependencies
- (void) plan;

// build
- (BOOL) build;
- (BOOL) clean;
- (BOOL) install;
- (BOOL) generate;
- (BOOL) save;
@end

#endif
