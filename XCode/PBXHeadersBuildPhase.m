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
#import "PBXCommon.h"
#import "PBXHeadersBuildPhase.h"
#import "PBXFileReference.h"
#import "PBXBuildFile.h"
#import "GSXCBuildContext.h"
#import "GSXCCommon.h"

@implementation PBXHeadersBuildPhase
- (BOOL) build
{
  xcputs("=== Executing Headers Build Phase");
  NSString *productType = [[GSXCBuildContext sharedBuildContext] objectForKey: @"PRODUCT_TYPE"];
  if([productType isEqualToString: BUNDLE_TYPE] ||
     [productType isEqualToString: TOOL_TYPE] ||
     [productType isEqualToString: APPLICATION_TYPE])
    {
      xcputs([[NSString stringWithFormat: @"\t* %s%sWARN%s: No need to process headers for product type %@",BOLD, YELLOW, RESET, productType] cString]);
      return YES;
    }

  xcputs([[NSString stringWithFormat: @"\t* Copying headers to derived sources folder..."] cString]);
  NSFileManager *defaultManager = [NSFileManager defaultManager];
  id file = nil;
  BOOL result = YES;
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSError *error = nil;

  NSArray *synchronizedFiles = [_target synchronizedHeaders];
  NSArray *files = [_files arrayByAddingObjectsFromArray: synchronizedFiles];
  
  NSEnumerator *en = [files objectEnumerator];
  NSString *derivedSourceHeaderDir = [context objectForKey: @"DERIVED_SOURCE_HEADER_DIR"];
  while((file = [en nextObject]) != nil && result)
    {
      NSString *path = [[file fileRef] path];
      NSString *srcFile = [[file fileRef] buildPath];
      NSString *dstFile = [derivedSourceHeaderDir stringByAppendingPathComponent: [path lastPathComponent]];
      BOOL copyResult = [defaultManager copyItemAtPath: srcFile
						toPath: dstFile
						 error: &error];
      xcputs([[NSString stringWithFormat: @"\tCopy %s%@%s -> %s%@%s", YELLOW, srcFile, RESET, GREEN, dstFile, RESET] cString]);
      if(!copyResult)
	{
	  xcputs([[NSString stringWithFormat: @"\t* Already exists"] cString]);
	}
    }

  // Only copy into the framework header folder, if it's a framework...
  if([productType isEqualToString: FRAMEWORK_TYPE])
    {
      xcputs([[NSString stringWithFormat: @"\t* Copying headers to framework header folder..."] cString]);
      en = [_files objectEnumerator];
      NSString *headerDir = [context objectForKey: @"HEADER_DIR"];
      while((file = [en nextObject]) != nil && result)
	{
	  NSString *path = [[file fileRef] path];
	  NSString *srcFile = [[file fileRef] buildPath];
	  NSString *dstFile = [headerDir stringByAppendingPathComponent: [path lastPathComponent]];
	  BOOL copyResult = [defaultManager copyItemAtPath: srcFile
						    toPath: dstFile
						     error: &error];
          xcputs([[NSString stringWithFormat: @"\tCopy %s%@%s -> %s%@%s", YELLOW, srcFile, RESET, GREEN, dstFile, RESET] cString]);
	  if(!copyResult)
	    {
	      xcputs([[NSString stringWithFormat: @"\t* Already exists"] cString]);
	    }
	}
    }

  xcputs([[NSString stringWithFormat: @"=== Completed Headers Build Phase"] cString]);

  return result;
}

- (BOOL) generate
{
  xcputs("=== Executing Headers Build Phase (Generate)");
  NSString *productType = [[GSXCBuildContext sharedBuildContext] objectForKey: @"PRODUCT_TYPE"];
  if([productType isEqualToString: BUNDLE_TYPE] ||
     [productType isEqualToString: TOOL_TYPE] ||
     [productType isEqualToString: APPLICATION_TYPE])
    {
      xcputs([[NSString stringWithFormat: @"\t* %s%sWARN%s: No need to process headers for product type %@",BOLD, YELLOW, RESET, productType] cString]);
      return YES;
    }

  BOOL result = YES;
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];

  // NSString *derivedSourceHeaderDir = [context objectForKey: @"DERIVED_SOURCE_HEADER_DIR"];
  [context setObject: _files forKey: @"DERIVED_HEADERS"];
  xcputs([[NSString stringWithFormat: @"\tAdding entry for derived header files"] cString]);

  // Only copy into the framework header folder, if it's a framework...
  if([productType isEqualToString: FRAMEWORK_TYPE])
    {
      // NSString *headerDir = [context objectForKey: @"HEADER_DIR"];
      [context setObject: _files forKey: @"HEADERS"];
      xcputs([[NSString stringWithFormat: @"\tAdding entry for derived header"] cString]);    
    }

  xcputs([[NSString stringWithFormat: @"=== Completed Headers Build Phase (Generate)"] cString]);

  return result;
}

- (BOOL) link
{
  return YES;
}

@end
