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

// Methods....
- (NSMutableArray *) fileSystemSynchronizedGroups;
- (void) setFileSystemSynchronizedGroups: (NSMutableArray *)object;

- (NSMutableArray *) packageProductDependencies;
- (void) setPackageProductDependencies: (NSMutableArray *)object;

- (NSMutableArray *) dependencies; // getter
- (void) setDependencies: (NSMutableArray *)object; // setter

- (XCConfigurationList *) buildConfigurationList; // getter
- (void) setBuildConfigurationList: (XCConfigurationList *)object; // setter

- (NSString *) productName; // getter
- (void) setProductName: (NSString *)object; // setter

- (NSMutableArray *) buildPhases; // getter
- (void) setBuildPhases: (NSMutableArray *)object; // setter

- (NSString *) name; // getter
- (void) setName: (NSString *)object; // setter

- (PBXProject *) project;
- (void) setProject: (PBXProject *)project;

- (GSXCBuildDatabase *) database;
- (void) setDatabase: (GSXCBuildDatabase *)db;

- (NSString *) productType; // getter
- (void) setProductType: (NSString *)object; // setter

// Utility methods...
- (NSArray *) synchronizedSources;
- (NSArray *) synchronizedHeaders;
- (NSArray *) synchronizedResources;

// build
- (BOOL) build;
- (BOOL) clean;
- (BOOL) install;
- (BOOL) generate;
- (BOOL) link;

@end
