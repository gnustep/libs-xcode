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

#import <Foundation/NSOperation.h>

#import "PBXCommon.h"
#import "PBXSourcesBuildPhase.h"
#import "PBXFileReference.h"
#import "PBXBuildFile.h"

#import "GSXCBuildOperation.h"

@implementation PBXSourcesBuildPhase

- (instancetype) init
{
  if ((self = [super init]) != nil)
    {
      _queue = [[NSOperationQueue alloc] init];
      [_queue setMaxConcurrentOperationCount: 1];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_queue);
  [super dealloc];
}

- (BOOL) build
{
  id file = nil;
  BOOL result = YES;
  NSUInteger i = 1;
  NSMutableArray *ops = [NSMutableArray array];
  NSEnumerator *en = [_files objectEnumerator];
                         
  xcputs("=== Executing Sources Build Phase");

  while((file = [en nextObject]) != nil && result)
    {
      NSAutoreleasePool *p = [[NSAutoreleasePool alloc] init];
      GSXCBuildOperation *op = [GSXCBuildOperation operationWithFile: file];
      
      [file setTarget: _target];
      [file setTotalFiles: [_files count]];
      [file setCurrentFile: i];
      [ops addObject: op];

      i++;
      
      RELEASE(p);
    }

  // Handle the error...
  NS_DURING
    {
      [_queue addOperations: ops waitUntilFinished: YES];
    }
  NS_HANDLER
    {
      [_queue cancelAllOperations];
      NSLog(@"Compilation halted.");
    }
  NS_ENDHANDLER;
  
  xcputs("=== Sources Build Phase Completed");

  return result;
}

- (BOOL) generate
{
  NSEnumerator *en = [_files objectEnumerator];
  id file = nil;
  BOOL result = YES;

  xcputs("=== Generating using Sources Build Phase");
  
  while((file = [en nextObject]) != nil && result)
    {
      [file setTarget: _target];
      result = [file generate];
    }

  xcputs("=== Sources Build Phase generation completed");

  return result;
}

@end
