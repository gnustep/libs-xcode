/*
   Copyright (C) 2018, 2019, 2020, 2021 Free Software Foundation, Inc.

   Written by: Gregory John Casamento <greg.casamento@gmail.com>
   Date: 2024 November
   
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
#import "PBXFileSystemSynchronizedRootGroup.h"
#import "PBXFileReference.h"
#import "PBXBuildFile.h"

@implementation PBXFileSystemSynchronizedRootGroup

- (NSMutableArray *) synchronizedChildren
{
  NSFileManager *fm = [NSFileManager defaultManager];
  BOOL isDirectory;
  NSMutableArray *result = [NSMutableArray array];
  
  if ([fm fileExistsAtPath: _path isDirectory: &isDirectory]
      && isDirectory == YES)
    {
      NSError *error = nil;
      NSArray *files = [fm contentsOfDirectoryAtPath: _path error: &error];

      if (error == nil)
	{
	  NSEnumerator *en = [files objectEnumerator];
	  NSString *path = nil;

	  while ((path = [en nextObject]) != nil)
	    {
	      PBXBuildFile *buildFile = [[PBXBuildFile alloc] init];
	      PBXFileReference *fileRef = [[PBXFileReference alloc] initWithPath: path];

	      AUTORELEASE(buildFile);
	      AUTORELEASE(fileRef);
	      
	      [buildFile setFileRef: fileRef];
	      [result addObject: buildFile];
	    }
	}
    }

  return result;
}

- (instancetype) init
{
  self = [super init];
  if (self != nil)
    {
      [self setChildren: [self synchronizedChildren]];
    }
  return self;
}

@end
