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
#import "PBXSourcesBuildPhase.h"
#import "PBXFileReference.h"
#import "PBXBuildFile.h"

@implementation PBXSourcesBuildPhase

- (BOOL) build
{
  puts("=== Executing Sources Build Phase");
  NSEnumerator *en = [files objectEnumerator];
  id file = nil;
  BOOL result = YES;
  NSUInteger i = 1;
  
  while((file = [en nextObject]) != nil && result)
    {
      NSAutoreleasePool *p = [[NSAutoreleasePool alloc] init];
      
      [file setTarget: target];
      [file setTotalFiles: [files count]];
      [file setCurrentFile: i];
      result = [file build];
      i++;
      
      RELEASE(p);
    }
  puts("=== Sources Build Phase Completed");

  return result;
}

- (BOOL) generate
{
  puts("=== Generating using Sources Build Phase");
  NSEnumerator *en = [files objectEnumerator];
  id file = nil;
  BOOL result = YES;
  while((file = [en nextObject]) != nil && result)
    {
      [file setTarget: target];
      result = [file generate];
    }
  puts("=== Sources Build Phase generation completed");

  return result;
}

@end
