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

#import "PBXCommon.h"
#import "XCVersionGroup.h"

@implementation XCVersionGroup

// Methods....
- (NSString *) sourceTree // getter
{
  return sourceTree;
}

- (void) setSourceTree: (NSString *)object; // setter
{
  ASSIGN(sourceTree,object);
}

- (PBXFileReference *) currentVersion // getter
{
  return currentVersion;
}

- (void) setCurrentVersion: (PBXFileReference *)object; // setter
{
  ASSIGN(currentVersion,object);
}

- (NSString *) versionGroupType // getter
{
  return versionGroupType;
}

- (void) setVersionGroupType: (NSString *)object; // setter
{
  ASSIGN(versionGroupType,object);
}

- (NSString *) path // getter
{
  return path;
}

- (void) setPath: (NSString *)object; // setter
{
  ASSIGN(path,object);
}

- (NSString *) buildPath
{
  return [self path];
}

- (NSMutableArray *) children // getter
{
  return children;
}

- (void) setChildren: (NSMutableArray *)object; // setter
{
  ASSIGN(children,object);
}

- (void) setTarget: (NSString *)target
{
}

- (void) setTotalFiles: (NSUInteger)total
{
  _totalFiles = total;
}

- (NSUInteger) totalFiles
{
  return _totalFiles;
}


- (BOOL) build
{
  NSEnumerator *en = [children objectEnumerator];
  id o = nil;
  BOOL result = YES;
  while((o = [en nextObject]) != nil && result)
    {
      xcputs([[NSString stringWithFormat: @"\tProcessing %@",[o path]] cString]);
    }
  return result;
}

@end
