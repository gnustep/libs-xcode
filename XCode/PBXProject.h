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

/**
 * Returns whether project reference proxies are minimized.
 */
- (BOOL) minimizedProjectReferenceProxies;

/**
 * Sets whether project reference proxies are minimized.
 */
- (void) setMinimizedProjectReferenceProxies: (BOOL)flag;

/**
 * Returns the preferred project object version.
 */
- (NSString *) preferredProjectObjectVersion;

/**
 * Sets the preferred project object version.
 */
- (void) setPreferredProjectObjectVersion: (NSString *)object;

/**
 * Returns the development region for this project.
 */
- (NSString *) developmentRegion;

/**
 * Sets the development region for this project.
 */
- (void) setDevelopmentRegion: (NSString *)object;

/**
 * Returns the known regions for this project.
 */
- (NSMutableArray *) knownRegions;

/**
 * Sets the known regions for this project.
 */
- (void) setKnownRegions: (NSMutableArray *)object;

/**
 * Returns the compatibility version for this project.
 */
- (NSString *) compatibilityVersion;

/**
 * Sets the compatibility version for this project.
 */
- (void) setCompatibilityVersion: (NSString *)object;

/**
 * Returns the project references for this project.
 */
- (NSMutableArray *) projectReferences;

/**
 * Sets the project references for this project.
 */
- (void) setProjectReferences: (NSMutableArray *)object;

/**
 * Returns the targets for this project.
 */
- (NSMutableArray *) targets;

/**
 * Sets the targets for this project.
 */
- (void) setTargets: (NSMutableArray *)object;

/**
 * Returns the project directory path.
 */
- (NSString *) projectDirPath;

/**
 * Sets the project directory path.
 */
- (void) setProjectDirPath: (NSString *)object;

/**
 * Returns the project root.
 */
- (NSString *) projectRoot;

/**
 * Sets the project root.
 */
- (void) setProjectRoot: (NSString *)object;

/**
 * Returns the build configuration list for this project.
 */
- (XCConfigurationList *) buildConfigurationList;

/**
 * Sets the build configuration list for this project.
 */
- (void) setBuildConfigurationList: (XCConfigurationList *)object;

/**
 * Returns the main group for this project.
 */
- (PBXGroup *) mainGroup;

/**
 * Sets the main group for this project.
 */
- (void) setMainGroup: (PBXGroup *)object;

/**
 * Returns whether the project has scanned for encodings.
 */
- (NSString *) hasScannedForEncodings;

/**
 * Sets whether the project has scanned for encodings.
 */
- (void) setHasScannedForEncodings: (NSString *)object;

/**
 * Returns the product reference group for this project.
 */
- (PBXGroup *) productRefGroup;

/**
 * Sets the product reference group for this project.
 */
- (void) setProductRefGroup: (PBXGroup *)object;

/**
 * Returns the container for this project.
 */
- (PBXContainer *) container;

/**
 * Sets the container for this project.
 */
- (void) setContainer: (PBXContainer *)container;

/**
 * Sets the context for this project.
 */
- (void) setContext: (NSDictionary *)ctx;

/**
 * Returns the context for this project.
 */
- (NSDictionary *) context;

/**
 * Sets the filename for this project.
 */
- (void) setFilename: (NSString *)fn;

/**
 * Returns the filename for this project.
 */
- (NSString *) filename;

/**
 * Plans the build by calculating dependencies.
 */
- (void) plan;

/**
 * Builds the project.
 */
- (BOOL) build;

/**
 * Cleans the project.
 */
- (BOOL) clean;

/**
 * Installs the project.
 */
- (BOOL) install;

/**
 * Generates the project.
 */
- (BOOL) generate;

/**
 * Saves the project.
 */
- (BOOL) save;

@end

#endif
