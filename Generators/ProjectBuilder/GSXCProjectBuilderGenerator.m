/*
   Copyright (C) 2025 Free Software Foundation, Inc.

   Written by: GitHub Copilot <copilot@github.com>
   Date: 2025 Oct 23
   
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

#import "GSXCProjectBuilderGenerator.h"
#import "PBXNativeTarget.h"
#import "XCConfigurationList.h"
#import "PBXBuildFile.h"
#import "PBXFileReference.h"

#import "NSArray+Additions.h"

@implementation GSXCProjectBuilderGenerator

- (NSString *) projectTypeForString: (NSString *)type
{
  if ([type isEqualToString: @"APPLICATION"])
    {
      return @"Application";
    }
  else if ([type isEqualToString: @"BUNDLE"])
    {
      return @"Bundle";
    }
  else if ([type isEqualToString: @"FRAMEWORK"])
    {
      return @"Framework";
    }
  else if ([type isEqualToString: @"LIBRARY"])
    {
      return @"Library";  
    }
  else if ([type isEqualToString: @"TOOL"])
    {
      return @"Tool";
    }
  return type;
}

- (id) objectForString: (NSString *)o
{
  return o != nil ? o : @"";
}

- (BOOL) arrayHasValidContent: (NSArray *)array
{
  if (array == nil || [array count] == 0)
    {
      return NO;
    }
  
  // Check if all elements are non-empty strings
  NSEnumerator *en = [array objectEnumerator];
  id obj = nil;
  while ((obj = [en nextObject]) != nil)
    {
      if (![obj isKindOfClass: [NSString class]] || 
          [(NSString *)obj length] == 0)
        {
          continue; // Skip empty strings but don't reject the whole array
        }
      return YES; // Found at least one valid string
    }
  
  return NO; // No valid strings found
}

- (NSString *) safeStringFromArray: (NSArray *)array withMethod: (SEL)method
{
  if (![self arrayHasValidContent: array])
    {
      return @"";
    }
  
  NSString *result = [array performSelector: method];
  return result != nil ? result : @"";
}

- (BOOL) generate
{
  BOOL result = YES;
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *name = [_target name];
  NSString *appName = [name stringByDeletingPathExtension];
  NSString *projectFileName = @"PB.project";
  NSMutableDictionary *projectDict = [NSMutableDictionary dictionary];
  NSMutableDictionary *filesTable = [NSMutableDictionary dictionary];
  
  NSArray *objCFiles = [context objectForKey: @"OBJC_FILES"];
  NSArray *cFiles = [context objectForKey: @"C_FILES"];
  NSArray *cppFiles = [context objectForKey: @"CPP_FILES"];
  NSArray *objCPPFiles = [context objectForKey: @"OBJCPP_FILES"];
  NSArray *headerFiles = [context objectForKey: @"HEADERS"];
  NSArray *resourceFiles = [context objectForKey: @"RESOURCES"];
  NSArray *otherSources = [context objectForKey: @"OTHER_SOURCES"];
  NSArray *libraries = [context objectForKey: @"ADDITIONAL_OBJC_LIBS"];
  NSString *projectType = [context objectForKey: @"PROJECT_TYPE"];

  // Debug output to see what we're getting from the context
  NSDebugLog(@"=== DEBUG: ProjectBuilder Generator Context ===");
  NSDebugLog(@"OBJC_FILES: %@", objCFiles);
  NSDebugLog(@"C_FILES: %@", cFiles);
  NSDebugLog(@"CPP_FILES: %@", cppFiles);
  NSDebugLog(@"OBJCPP_FILES: %@", objCPPFiles);
  NSDebugLog(@"HEADERS: %@", headerFiles);
  NSDebugLog(@"RESOURCES: %@", resourceFiles);
  NSDebugLog(@"OTHER_SOURCES: %@", otherSources);
  NSDebugLog(@"LIBRARIES: %@", libraries);
  NSDebugLog(@"PROJECT_TYPE: %@", projectType);
  NSDebugLog(@"==============================================");

  // Construct the ProjectBuilder project structure
  xcputs("\t* Generating ProjectBuilder project");

  // Set basic project information  
  [projectDict setObject: appName forKey: @"PROJECTNAME"];
  [projectDict setObject: [self projectTypeForString: [projectType uppercaseString]] forKey: @"PROJECTTYPE"];
  
  // Combine all class files (source code files)
  NSMutableArray *classFiles = [NSMutableArray array];
  if ([self arrayHasValidContent: objCFiles])
    {
      [classFiles addObjectsFromArray: objCFiles];
    }
  if ([self arrayHasValidContent: cFiles])
    {
      [classFiles addObjectsFromArray: cFiles];
    }
  if ([self arrayHasValidContent: cppFiles])
    {
      [classFiles addObjectsFromArray: cppFiles];
    }
  if ([self arrayHasValidContent: objCPPFiles])
    {
      [classFiles addObjectsFromArray: objCPPFiles];
    }
  
  // Build the FILESTABLE dictionary structure (as used by ProjectBuilder)
  if ([classFiles count] > 0)
    {
      [filesTable setObject: classFiles forKey: @"CLASSES"];
    }
  
  if ([self arrayHasValidContent: headerFiles])
    {
      [filesTable setObject: headerFiles forKey: @"H_FILES"];
    }
  
  if ([self arrayHasValidContent: resourceFiles])
    {
      // ProjectBuilder uses INTERFACES for NIB/interface files, but we'll put resources here
      [filesTable setObject: resourceFiles forKey: @"INTERFACES"];
    }
  
  if ([self arrayHasValidContent: otherSources])
    {
      [filesTable setObject: otherSources forKey: @"OTHER_LINKED"];
    }
  
  if ([self arrayHasValidContent: libraries])
    {
      // Convert library flags to just library names
      NSMutableArray *cleanLibraries = [NSMutableArray array];
      NSEnumerator *en = [libraries objectEnumerator];
      NSString *lib = nil;
      
      while ((lib = [en nextObject]) != nil)
        {
          if ([lib hasPrefix: @"-l"])
            {
              [cleanLibraries addObject: [lib substringFromIndex: 2]];
            }
          else
            {
              [cleanLibraries addObject: lib];
            }
        }
      
      if ([cleanLibraries count] > 0)
        {
          [filesTable setObject: cleanLibraries forKey: @"FRAMEWORKS"];
        }
    }
  
  // Add empty arrays for any missing required ProjectBuilder sections
  if ([filesTable objectForKey: @"CLASSES"] == nil)
    {
      [filesTable setObject: [NSArray array] forKey: @"CLASSES"];
    }
  if ([filesTable objectForKey: @"H_FILES"] == nil)
    {
      [filesTable setObject: [NSArray array] forKey: @"H_FILES"];
    }
  if ([filesTable objectForKey: @"INTERFACES"] == nil)
    {
      [filesTable setObject: [NSArray array] forKey: @"INTERFACES"];
    }
  if ([filesTable objectForKey: @"OTHER_LINKED"] == nil)
    {
      [filesTable setObject: [NSArray array] forKey: @"OTHER_LINKED"];
    }
  if ([filesTable objectForKey: @"FRAMEWORKS"] == nil)
    {
      [filesTable setObject: [NSArray array] forKey: @"FRAMEWORKS"];
    }
  if ([filesTable objectForKey: @"IMAGES"] == nil)
    {
      [filesTable setObject: [NSArray array] forKey: @"IMAGES"];
    }
  
  // Set the FILESTABLE in the main project dictionary
  [projectDict setObject: filesTable forKey: @"FILESTABLE"];
  
  // Add ProjectBuilder-specific metadata
  [projectDict setObject: @"English" // @"2.1"
		  forKey: @"LANGUAGE"];
  [projectDict setObject: @"gnumake" /* @"NeXT Project Builder Project v2.1" */
		  forKey: @"NEXTSTEP_BUILDTOOL"];
  
  NSDebugLog(@"ProjectBuilder project dict = %@", projectDict);

  // Write the PB.project file
  if (![projectDict writeToFile: projectFileName atomically: YES])
    {
      xcprintf("Error writing project file %s", [projectFileName cString]);
      return NO;
    }
  
  xcputs([[NSString stringWithFormat: @"=== Completed generation of %@ for target %@", projectFileName, name] cString]);

  return result;
}

@end
