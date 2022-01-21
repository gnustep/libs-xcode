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

#import "PBXCommon.h"
#import "PBXBuildFile.h"
#import "PBXNativeTarget.h"

@implementation PBXBuildFile

// Methods....
- (void) setPlatformFilter: (NSString *)f
{
  ASSIGN(platformFilter, f);
}

- (PBXFileReference *) fileRef // getter
{
  return fileRef;
}

- (void) setFileRef: (PBXFileReference *)object; // setter
{
  ASSIGN(fileRef,object);
}

- (NSMutableDictionary *) settings // getter
{
  return settings;
}

- (void) setSettings: (NSMutableDictionary *)object; // setter
{
  ASSIGN(settings,object);
}

- (void) applySettings
{
  // puts("%@",settings);
}

- (NSString *) buildPath
{
  return [fileRef buildPath];
}

- (NSString *) path
{
  return [fileRef path];
}

- (void) setTarget: (PBXNativeTarget *)t
{
  target = t;
}

- (BOOL) build
{
  [self applySettings];
  [fileRef setTarget: target];
  return [fileRef build];
}

- (BOOL) generate
{
  [self applySettings];
  puts([[NSString stringWithFormat: @"\t* Creating entry for %@",[fileRef buildPath]] cString]);
  [fileRef setTarget: target];
  return [fileRef generate];
}

- (NSString *) description
{
  NSString *s = [super description];
  return [s stringByAppendingFormat: @" <%@>", fileRef]; 
}

@end
