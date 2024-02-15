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
#import "GSXCBuildDatabase.h"

@implementation PBXSourcesBuildPhase

- (instancetype) init
{
  if ((self = [super init]) != nil)
    {
      _cpus = [[NSProcessInfo processInfo] processorCount];      
      _queue = [[NSOperationQueue alloc] init];
      [_queue setMaxConcurrentOperationCount: _cpus];
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
  GSXCBuildContext *ctx = [GSXCBuildContext sharedBuildContext];
  NSDictionary *config = [ctx config];
  GSXCBuildDatabase *db = [_target database];
  NSArray *files = _files;
  id file = nil;
  BOOL result = YES;
  NSUInteger i = 1;
  NSMutableArray *ops = [NSMutableArray array];
  NSEnumerator *en = nil;
  NSString *buildType = [config objectForKey: @"buildType"];
  
  NSDebugLog(@"config = %@", config);
  if ([buildType isEqualToString: @"linear"] == YES || buildType == nil) // linear is the default
    {
      [_queue setMaxConcurrentOperationCount: 1];
    }
  else if ([buildType isEqualToString: @"parallel"] == YES)
    {
      NSString *mct = [config objectForKey: @"maxConcurrentOperationCount"];

      if (mct != nil)
	{
	  NSUInteger t = [mct intValue];

	  if (t > 0)
	    {
	      _cpus = t;
	      [_queue setMaxConcurrentOperationCount: _cpus];
	    }
	}
      
      xcprintf("\t* Parallel build using %ld CPUs...\n", _cpus);
    }
  
  // if the database is present use it's list of files...
  if (db != nil)
    {
      if ([db isEmpty])
	{
	  xcputs("\t++++ No files modified, nothing to build. ++++\n");
	  return YES;
	}
      
      files = [db files];
    }
    
  en = [files objectEnumerator];                         
  xcputs("=== Executing Sources Build Phase");
  while((file = [en nextObject]) != nil && result)
    {
      NSAutoreleasePool *p = [[NSAutoreleasePool alloc] init];
      GSXCBuildOperation *op = [GSXCBuildOperation operationWithFile: file];
      
      [file setTarget: _target];
      [file setTotalFiles: [files count]];
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

  // if (db != nil)
    {
      [self link]; // generate the rest of the output file entries
    }
  
  return result;
}

- (BOOL) generate
{
  xcputs("=== Generating using Sources Build Phase");
  NSEnumerator *en = [_files objectEnumerator];
  id file = nil;
  BOOL result = YES;
  while((file = [en nextObject]) != nil && result)
    {
      [file setTarget: _target];
      result = [file generate];
    }
  xcputs("=== Sources Build Phase generation completed");

  return result;
}

- (BOOL) link
{
  GSXCBuildDatabase *db = [_target database];
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *of = (db != nil) ? nil : [context objectForKey: @"OUTPUT_FILES"];
  NSString *outputFiles = (of == nil) ? @"" : of;
  PBXBuildFile *file = nil;
  BOOL result = YES;
  NSString *buildDir = @"./build";
  NSEnumerator *en = [_files objectEnumerator];
  NSFileManager *mgr = [NSFileManager defaultManager];

  buildDir = [buildDir stringByAppendingPathComponent: [_target name]];

  xcputs("=== Executing Sources Build Phase (LINK)");
  while((file = [en nextObject]) != nil && result)
    {
      PBXFileReference *fr = [file fileRef];
      NSString *fileName = [[fr path] lastPathComponent];
      NSString *outputPath = [buildDir stringByAppendingPathComponent: 
				    [fileName stringByAppendingString: @".o"]];

      outputFiles = [[outputFiles stringByAppendingString: [NSString stringWithFormat: @"'%@'",outputPath]] 
		      stringByAppendingString: @" "];
      
      // NSLog(@"name = %@", [fr path]);
      xcprintf("\t+ Collecting %s%s%s%s ... ", BOLD, MAGENTA, [outputPath cString], RESET);

      if ([mgr fileExistsAtPath: outputPath] == YES)
	{
	  xcprintf("%s%sfound%s\n", BOLD, GREEN, RESET);
	}
      else
	{
	  xcprintf("%s%smissing%s\n", BOLD, RED, RESET);
	  result = NO;
	  break;
	}
    }

  [context setObject: outputFiles forKey: @"OUTPUT_FILES"];
  // NSLog(@"Output files %@", outputFiles);
  xcputs("=== Sources Build Phase Completed (LINK)");

  return result;
}

@end
