/*
   Copyright (C) 2018, 2019, 2020, 2021 Free Software Foundation, Inc.

   Written by: Gregory John Casament <greg.casamento@gmail.com>
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
#import "XCConfigurationList.h"
#import "PBXGroup.h"
#import "PBXGroup.h"

@class PBXContainer;
@protocol GSXCBuildDelegate;

@interface PBXProject : NSObject
{
  NSString *developmentRegion;
  NSMutableArray *knownRegions;
  NSString *compatibilityVersion;
  NSMutableArray *projectReferences;
  NSMutableArray *_targets;
  NSString *projectDirPath;
  NSString *projectRoot;
  XCConfigurationList *buildConfigurationList;
  PBXGroup *mainGroup;
  NSString *hasScannedForEncodings;
  PBXGroup *productRefGroup;
  PBXContainer *container;
  NSDictionary *attributes;
  NSDictionary *ctx;

  NSString *_filename;
  NSMutableArray *_arrangedTargets;
  id<GSXCBuildDelegate> _delegate;
}

- (id<GSXCBuildDelegate>) delegate;
- (void) setDelegate: (id<GSXCBuildDelegate>) delegate;

// Methods....
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
- (void) setFilename: (NSString *)fn;
- (NSString *) filename;

// calculate dependencies
- (void) plan;

// build
- (BOOL) build;
- (BOOL) clean;
- (BOOL) install;
- (BOOL) generate;
@end
