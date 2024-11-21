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
#import "NSString+PBXAdditions.h"

@implementation PBXFileSystemSynchronizedRootGroup

- (NSMutableArray *) synchronizedChildren
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSDirectoryEnumerator *den = [fm enumeratorAtPath: _path];
  NSMutableArray *result = [NSMutableArray array];
  NSString *filePath = nil;
  NSMutableArray *fp = [NSMutableArray array];
  
  while ((filePath = [den nextObject]) != nil)
    {
      BOOL isDir = NO;
      NSString *fullPath = [_path stringByAppendingPathComponent: filePath];
      
      if ([fm fileExistsAtPath: fullPath isDirectory: &isDir] && isDir == NO)
	{
	  PBXBuildFile *buildFile = [[PBXBuildFile alloc] init];
	  PBXFileReference *fileRef = nil;
	  NSString *fpc = [filePath firstPathComponent];
	  NSString *path = filePath;

	  AUTORELEASE(buildFile);
	  
	  if ([[fpc pathExtension] isEqualToString: @"xcassets"])
	    {
	      path = fpc;
	    }

	  if ([fp containsObject: path] == NO)
	    {
	      fileRef = [[PBXFileReference alloc] initWithPath: path];
	      
	      // NSLog(@"fileRef = %@", fileRef);
	      AUTORELEASE(fileRef);
	      [buildFile setFileRef: fileRef];
	      [result addObject: buildFile];
	      [fp addObject: path];
	    }
	}
    }
  
  // NSLog(@"result = %@", result);

  return result;
}

- (void) setPath: (NSString *)path
{
  [super setPath: path];
  [self setChildren: [self synchronizedChildren]];
}

@end
