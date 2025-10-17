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
#import "XCConfigurationList.h"
#import "PBXFileReference.h"
#import "GSXCBuildContext.h"
#import "PBXBuildFile.h"
#import "PBXFileSystemSynchronizedRootGroup.h"

@class PBXProject, GSXCBuildDatabase;

@interface PBXTarget : NSObject
{
  NSMutableArray *_dependencies;
  XCConfigurationList *_buildConfigurationList;
  NSString *_productName;
  NSMutableArray *_buildPhases;
  NSString *_name;
  NSString *_productType;
  NSMutableArray *_fileSystemSynchronizedGroups;
  NSMutableArray *_packageProductDepedencies;
  
  PBXProject *_project;
  GSXCBuildDatabase *_database;
}

/**
 * Returns the file system synchronized groups for this target.
 */
- (NSMutableArray *) fileSystemSynchronizedGroups;

/**
 * Sets the file system synchronized groups for this target.
 */
- (void) setFileSystemSynchronizedGroups: (NSMutableArray *)object;

/**
 * Returns the package product dependencies for this target.
 */
- (NSMutableArray *) packageProductDependencies;

/**
 * Sets the package product dependencies for this target.
 */
- (void) setPackageProductDependencies: (NSMutableArray *)object;

/**
 * Returns the dependencies for this target.
 */
- (NSMutableArray *) dependencies;

/**
 * Sets the dependencies for this target.
 */
- (void) setDependencies: (NSMutableArray *)object;

/**
 * Returns the build configuration list for this target.
 */
- (XCConfigurationList *) buildConfigurationList;

/**
 * Sets the build configuration list for this target.
 */
- (void) setBuildConfigurationList: (XCConfigurationList *)object;

/**
 * Returns the product name for this target.
 */
- (NSString *) productName;

/**
 * Sets the product name for this target.
 */
- (void) setProductName: (NSString *)object;

/**
 * Returns the build phases for this target.
 */
- (NSMutableArray *) buildPhases;

/**
 * Sets the build phases for this target.
 */
- (void) setBuildPhases: (NSMutableArray *)object;

/**
 * Returns the name of this target.
 */
- (NSString *) name;

/**
 * Sets the name of this target.
 */
- (void) setName: (NSString *)object;

/**
 * Returns the project for this target.
 */
- (PBXProject *) project;

/**
 * Sets the project for this target.
 */
- (void) setProject: (PBXProject *)project;

/**
 * Returns the build database for this target.
 */
- (GSXCBuildDatabase *) database;

/**
 * Sets the build database for this target.
 */
- (void) setDatabase: (GSXCBuildDatabase *)db;

/**
 * Returns the product type for this target.
 */
- (NSString *) productType;

/**
 * Sets the product type for this target.
 */
- (void) setProductType: (NSString *)object;

/**
 * Returns the synchronized sources for this target.
 */
- (NSArray *) synchronizedSources;

/**
 * Returns the synchronized headers for this target.
 */
- (NSArray *) synchronizedHeaders;

/**
 * Returns the synchronized resources for this target.
 */
- (NSArray *) synchronizedResources;

/**
 * Builds the target.
 */
- (BOOL) build;

/**
 * Cleans the target.
 */
- (BOOL) clean;

/**
 * Installs the target.
 */
- (BOOL) install;

/**
 * Generates the target.
 */
- (BOOL) generate;

/**
 * Links the target.
 */
- (BOOL) link;

@end
