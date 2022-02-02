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
*/ #import <stdlib.h>
#import "PBXCommon.h"
#import "PBXAbstractTarget.h"
#import "NSString+PBXAdditions.h"

@implementation PBXAbstractTarget

- (void) dealloc
{
  RELEASE(dependencies);
  RELEASE(buildConfigurationList);
  RELEASE(productName);
  RELEASE(buildPhases);
  RELEASE(name);

  [super dealloc];
}

// Methods....
- (NSMutableArray *) dependencies // getter
{
  return dependencies;
}

- (void) setDependencies: (NSMutableArray *)object; // setter
{
  ASSIGN(dependencies,object);
}

- (XCConfigurationList *) buildConfigurationList // getter
{
  return buildConfigurationList;
}

- (void) setBuildConfigurationList: (XCConfigurationList *)object; // setter
{
  ASSIGN(buildConfigurationList,object);
}

- (NSString *) productName // getter
{
  return productName;
}

- (void) setProductName: (NSString *)object; // setter
{
  NSString *newName = [object stringByEliminatingSpecialCharacters];
  ASSIGN(productName,newName);
}

- (NSString *) name // getter
{
  return name;
}

- (void) setName: (NSString *)object; // setter
{
  NSString *newName = [object stringByEliminatingSpecialCharacters];
  ASSIGN(name, newName);
}

- (NSMutableArray *) buildPhases // getter
{
  return buildPhases;
}

- (void) setBuildPhases: (NSMutableArray *)object; // setter
{
  ASSIGN(buildPhases,object);
}

- (BOOL) build
{
  NSDictionary *plistFile = [NSDictionary dictionaryWithContentsOfFile:
                                            @"buildtool.plist"];
  NSArray *skippedTarget = [plistFile objectForKey:
                                        @"skippedTarget"];
  
  if ([skippedTarget containsObject: [self name]])
    {
      xcputs([[NSString stringWithFormat: @"Skipping %@",self] cString]);
    }
  else
    {
      xcputs([[NSString stringWithFormat: @"Building %@",self] cString]);
    }
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

@end
