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

#import <stdlib.h>
#import "PBXCommon.h"
#import "PBXTarget.h"
#import "NSString+PBXAdditions.h"
#import "PBXProject.h"
#import "GSXCBuildDatabase.h"

@implementation PBXTarget

- (void) dealloc
{
  RELEASE(_dependencies);
  RELEASE(_buildConfigurationList);
  RELEASE(_productName);
  RELEASE(_buildPhases);
  RELEASE(_name);
  RELEASE(_project);
  RELEASE(_productType);
  RELEASE(_fileSystemSynchronizedGroups);
  RELEASE(_packageProductDepedencies);
  
  [super dealloc];
}

// Methods....
- (NSMutableArray *) fileSystemSynchronizedGroups
{
  return _fileSystemSynchronizedGroups;
}

- (void) setFileSystemSynchronizedGroups: (NSMutableArray *)object
{
  ASSIGN(_fileSystemSynchronizedGroups, object);
}

- (NSMutableArray *) packageProductDependencies
{
  return _packageProductDepedencies;
}

- (void) setPackageProductDependencies: (NSMutableArray *)object
{
  ASSIGN(_packageProductDepedencies, object);
}

- (PBXProject *) project
{
  return _project;
}

- (void) setProject: (PBXProject *)project
{
  ASSIGN(_project, project); 
}

- (NSMutableArray *) dependencies // getter
{
  return _dependencies;
}

- (void) setDependencies: (NSMutableArray *)object; // setter
{
  ASSIGN(_dependencies,object);
}

- (XCConfigurationList *) buildConfigurationList // getter
{
  return _buildConfigurationList;
}

- (void) setBuildConfigurationList: (XCConfigurationList *)object; // setter
{
  ASSIGN(_buildConfigurationList,object);
}

- (NSString *) productName // getter
{
  return _productName;
}

- (void) setProductName: (NSString *)object; // setter
{
  NSString *newName = [object stringByEliminatingSpecialCharacters];
  ASSIGN(_productName,newName);
}

- (NSString *) name // getter
{
  return _name;
}

- (void) setName: (NSString *)object; // setter
{
  NSString *newName = [object stringByEliminatingSpecialCharacters];
  ASSIGN(_name, newName);
}

- (NSMutableArray *) buildPhases // getter
{
  return _buildPhases;
}

- (void) setBuildPhases: (NSMutableArray *)object; // setter
{
  ASSIGN(_buildPhases,object);
}

- (void) setDatabase: (GSXCBuildDatabase *)db
{
  ASSIGN(_database, db);
}

- (GSXCBuildDatabase *) database
{
  return _database;
}

- (NSString *) productType // getter
{
  return _productType;
}

- (void) setProductType: (NSString *)object; // setter
{
  ASSIGN(_productType,object);
}

- (NSArray *) synchronizedSources
{
  NSMutableArray *result = [NSMutableArray array];
  NSEnumerator *gen = [_fileSystemSynchronizedGroups objectEnumerator];
  PBXFileSystemSynchronizedRootGroup *group = nil;

  while ((group = [gen nextObject]) != nil)
    {
      NSArray *children = [group children];
      NSEnumerator *cen = [children objectEnumerator];
      PBXBuildFile *buildFile = nil;

      while ((buildFile = [cen nextObject]) != nil)
	{
	  PBXFileReference *fr = [buildFile fileRef];
	  NSString *name = [fr path];

	  // NSLog(@"path = %@", name);
	  if ([[name pathExtension] isEqualToString: @"m"]
	      || [[name pathExtension] isEqualToString: @"mm"]
	      || [[name pathExtension] isEqualToString: @"M"]
	      || [[name pathExtension] isEqualToString: @"c"]
	      || [[name pathExtension] isEqualToString: @"cc"]
	      || [[name pathExtension] isEqualToString: @"C"]
	      || [[name pathExtension] isEqualToString: @"swift"])
	    {
	      [result addObject: buildFile];
	    }
	}
    }
  
  return result;
}

- (NSArray *) synchronizedHeaders
{
  NSMutableArray *result = [NSMutableArray array];
  NSEnumerator *gen = [_fileSystemSynchronizedGroups objectEnumerator];
  PBXFileSystemSynchronizedRootGroup *group = nil;

  while ((group = [gen nextObject]) != nil)
    {
      NSArray *children = [group children];
      NSEnumerator *cen = [children objectEnumerator];
      PBXBuildFile *buildFile = nil;

      while ((buildFile = [cen nextObject]) != nil)
	{
	  PBXFileReference *fr = [buildFile fileRef];
	  NSString *name = [fr path];

	  if ([[name pathExtension] isEqualToString: @"h"])
	    {
	      [result addObject: buildFile];
	    }
	}
    }
  
  return result;  
}

- (NSArray *) synchronizedResources
{
  NSMutableArray *result = [NSMutableArray array];
  NSEnumerator *gen = [_fileSystemSynchronizedGroups objectEnumerator];
  PBXFileSystemSynchronizedRootGroup *group = nil;

  while ((group = [gen nextObject]) != nil)
    {
      NSArray *children = [group children];
      NSEnumerator *cen = [children objectEnumerator];
      PBXBuildFile *buildFile = nil;

      while ((buildFile = [cen nextObject]) != nil)
	{
	  PBXFileReference *fr = [buildFile fileRef];
	  NSString *name = [fr path];

	  if ([[name pathExtension] isEqualToString: @"xcassets"]
	      || [[name pathExtension] isEqualToString: @"xib"])
	    {
	      [result addObject: buildFile];
	    }
	}
    }
  
  return result;
}

- (BOOL) build
{
  GSXCBuildDatabase *db = [GSXCBuildDatabase buildDatabaseWithTarget: self];
  
  [self setDatabase: db];
  
  return YES;
}

- (BOOL) clean
{
  xcputs([[NSString stringWithFormat: @"Cleaning %@",self] cString]);
  return YES;
}

- (BOOL) install
{
  xcputs([[NSString stringWithFormat: @"Installing %@",self] cString]);
  return YES;
}

- (BOOL) generate
{
  return YES;
}

- (BOOL) link
{
  return YES;
}

@end
