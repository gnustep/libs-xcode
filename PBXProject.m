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
#import "PBXProject.h"
#import "PBXNativeTarget.h"
#import "GSXCBuildContext.h"
#import "NSString+PBXAdditions.h"

#import "PBXAbstractTarget.h"
#import "PBXTargetDependency.h"

#import <unistd.h>

@interface PBXAbstractTarget (Private)

- (NSArray *) prerequisiteTargets;

@end

@implementation PBXAbstractTarget (Private)

- (NSArray *) prerequisiteTargets
{
  NSMutableArray *result = [NSMutableArray arrayWithCapacity: [dependencies count]];
  NSEnumerator *en = [dependencies objectEnumerator];
  PBXTargetDependency *t = nil;
  
  while ((t = [en nextObject]) != nil)
    {
      [result addObject: [t target]];
    }

  return result;
}

@end

@interface PBXProject (Private)

- (void) recurseTargetDependencies: (NSArray *)targets
                         forTarget: (PBXAbstractTarget *)target
                            result: (NSMutableArray *)result;

- (NSMutableArray *) arrangedTargets;

@end

@implementation PBXProject (Private)

- (void) recurseTargetDependencies: (NSArray *)targets
                         forTarget: (PBXAbstractTarget *)target
                            result: (NSMutableArray *)result
{
  if ([targets count] == 0 && target != nil)
    {
      if ([result containsObject: target] == NO)
        {
          [result insertObject: target
                       atIndex: 0];
        }
    }
  if ([targets count] == 1 && target == nil)
    {
      if ([result containsObject: target] == NO)
        {
          [result insertObject: [targets firstObject]
                       atIndex: 0];
        }
    }
  else
    {
      NSEnumerator *en = [targets objectEnumerator];
      PBXAbstractTarget *t = nil;
      
      while ((t = [en nextObject]) != nil)
        {
          NSArray *da = [t prerequisiteTargets];

          [self recurseTargetDependencies: da
                                forTarget: t
                                   result: result];
        }
    }
}

- (NSMutableArray *) arrangedTargets
{
  _arrangedTargets = [NSMutableArray arrayWithCapacity: 100];
  [self recurseTargetDependencies: [self targets]
                        forTarget: nil
                           result: _arrangedTargets];

  NSEnumerator *en = [[self targets] objectEnumerator];
  id o = nil;

  while ((o = [en nextObject]) != nil)
    {
      if ([_arrangedTargets containsObject: o] == NO)
        {
          [_arrangedTargets addObject: o];
        }
    }
  
  NSDebugLog(@"arrangedTarget = %ld, targets = %ld", [_arrangedTargets count], [[self targets] count]);
  
  return _arrangedTargets;
}

@end

@implementation PBXProject

// Methods....
- (NSString *) developmentRegion // getter
{
  return developmentRegion;
}

- (void) setDevelopmentRegion: (NSString *)object; // setter
{
  ASSIGN(developmentRegion,object);
}

- (NSMutableArray *) knownRegions // getter
{
  return knownRegions;
}

- (void) setKnownRegions: (NSMutableArray *)object; // setter
{
  ASSIGN(knownRegions,object);
}

- (NSString *) compatibilityVersion // getter
{
  return compatibilityVersion;
}

- (void) setCompatibilityVersion: (NSString *)object; // setter
{
  ASSIGN(compatibilityVersion,object);
}

- (NSMutableArray *) projectReferences // getter
{
  return projectReferences;
}

- (void) setProjectReferences: (NSMutableArray *)object; // setter
{
  ASSIGN(projectReferences,object);
}

- (NSMutableArray *) targets // getter
{
  return _targets;
}

- (void) setTargets: (NSMutableArray *)object; // setter
{
  ASSIGN(_targets,object);
}

- (NSString *) projectDirPath // getter
{
  return projectDirPath;
}

- (void) setProjectDirPath: (NSString *)object; // setter
{
  ASSIGN(projectDirPath,object);
}

- (NSString *) projectRoot // getter
{
  return projectRoot;
}

- (void) setProjectRoot: (NSString *)object; // setter
{
  ASSIGN(projectRoot,object);
}

- (XCConfigurationList *) buildConfigurationList // getter
{
  return buildConfigurationList;
}

- (void) setBuildConfigurationList: (XCConfigurationList *)object; // setter
{
  ASSIGN(buildConfigurationList,object);
}

- (PBXGroup *) mainGroup // getter
{
  return mainGroup;
}

- (void) setMainGroup: (PBXGroup *)object; // setter
{
  ASSIGN(mainGroup,object);
}

- (NSString *) hasScannedForEncodings // getter
{
  return hasScannedForEncodings;
}

- (void) setHasScannedForEncodings: (NSString *)object; // setter
{
  ASSIGN(hasScannedForEncodings,object);
}

- (PBXGroup *) productRefGroup // getter
{
  return productRefGroup;
}

- (void) setProductRefGroup: (PBXGroup *)object; // setter
{
  ASSIGN(productRefGroup,object);
}

- (PBXContainer *) container
{
  return container;
}

- (void) setContainer: (PBXContainer *)object
{
  container = object; // container retains us, do not retain it...
}

- (void) setContext: (NSDictionary *)context
{
  ASSIGN(ctx,context);
}

- (void) setFilename: (NSString *)fn
{
  ASSIGN(_filename, fn);
}
  
- (NSString *) filename
{
  return _filename;
}

- (void) plan
{
  printf("=== Planning build -- Recursing dependencies...");
  _arrangedTargets = [self arrangedTargets];
  printf("%ld targets - completed\n", [_arrangedTargets count]);
  //  NSLog(@"%@", _arrangedTargets);
}

- (void) _sourceRootFromMainGroup
{
  NSString *sourceRoot = @"./"; // [[sourceGroup path] firstPathComponent];
  
  // get first group, which is the source group.
  if(sourceRoot == nil || [sourceRoot isEqualToString: @""])
    {
      sourceRoot = @"./";
    }

  setenv("SOURCE_ROOT","./",1);
  setenv("SRCROOT","./",1);
}

- (NSString *) buildString
{
  NSString *output = [NSString stringForCommand: @"gnustep-config --debug-flags"];
  
  // Context...
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  [context setObject: output
	      forKey: @"CONFIG_STRING"];

  return output;
}

- (BOOL) build
{
  NSString *fn = [[[self container] filename]
                   stringByDeletingLastPathComponent];

  printf("=== Building Project %s%s%s%s\n", BOLD, GREEN, [fn cString], RESET);
  [buildConfigurationList applyDefaultConfiguration];
  [self _sourceRootFromMainGroup];
  [self plan];
  
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSEnumerator *en = [_arrangedTargets objectEnumerator];
  id target = nil;
  BOOL result = YES;
  
  while((target = [en nextObject]) != nil && result)
    {
      BOOL targetInSubdir = NO;
      NSFileManager *fileManager = [NSFileManager defaultManager];
      
      [context contextDictionaryForName: [target name]];
      [self buildString];

      if(YES == [fileManager fileExistsAtPath: [target name]])
	{
	  targetInSubdir = YES;
	  [context setObject: @"YES"
		      forKey: @"TARGET_IN_SUBDIR"];
	}

      [context setObject: mainGroup 
		  forKey: @"MAIN_GROUP"]; 
      [context setObject: container
		  forKey: @"CONTAINER"];
      [context setObject: @"./"
		  forKey: @"PROJECT_ROOT"];
      [context setObject: @"./"
		  forKey: @"PROJECT_DIR"];
      [context setObject: @"./"
		  forKey: @"SRCROOT"];
      [context addEntriesFromDictionary:ctx];
      
      result = [target build];
      [context popCurrentContext];

      if (result == NO)
        {
          break;
        }
    }

  printf("=== Done Building Project %s%s%s%s\n", BOLD, GREEN, [fn cString], RESET);

  return result;
}

- (BOOL) clean
{
  puts("=== Cleaning Project");
  [buildConfigurationList applyDefaultConfiguration];

  NSFileManager *fileManager = [NSFileManager defaultManager];
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSEnumerator *en = [_targets objectEnumerator];
  id target = nil;
  BOOL result = YES;
  
  while((target = [en nextObject]) != nil && result)
    {
      BOOL targetInSubdir = NO;

      if(YES == [fileManager fileExistsAtPath:[target name]])
	{
	  targetInSubdir = YES;
	  [context setObject: @"YES"
		      forKey: @"TARGET_IN_SUBDIR"];
	}

      [context contextDictionaryForName: [target name]];
      [context setObject: mainGroup 
		  forKey: @"MAIN_GROUP"]; 
      result = [target clean];
      [context popCurrentContext];
    }
  puts("=== Completed Cleaning Project");
  return result;  
}

- (BOOL) install
{
  puts("=== Installing Project");
  [buildConfigurationList applyDefaultConfiguration];

  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSEnumerator *en = [_targets objectEnumerator];
  id target = nil;
  BOOL result = YES;
  while((target = [en nextObject]) != nil && result)
    {
      [context contextDictionaryForName: [target name]];
      [context setObject: mainGroup 
		  forKey: @"MAIN_GROUP"]; 
      result = [target install];
      [context popCurrentContext];
    }
  puts("=== Completed Installing Project");
  return result;  
}

- (BOOL) generate
{
  puts("=== Generating Project");
  [buildConfigurationList applyDefaultConfiguration];
  [self _sourceRootFromMainGroup];

  NSFileManager *fileManager = [NSFileManager defaultManager];
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSEnumerator *en = [_targets objectEnumerator];
  id target = nil;
  BOOL result = YES;
  while((target = [en nextObject]) != nil && result)
    {
      BOOL targetInSubdir = NO;
      NSString *currentDirectory = [NSString stringWithCString: getcwd(NULL,0)];

      [context contextDictionaryForName: [target name]];
      [self buildString];

      if(YES == [fileManager fileExistsAtPath:[target name]])
	{
	  targetInSubdir = YES;
	  [context setObject: @"YES"
		      forKey: @"TARGET_IN_SUBDIR"];
	}

      [context setObject: mainGroup 
		  forKey: @"MAIN_GROUP"]; 
      [context setObject: container
		  forKey: @"CONTAINER"];
      [context setObject: currentDirectory
		  forKey: @"PROJECT_ROOT"];
      [context addEntriesFromDictionary:ctx];
      
      result = [target generate];
      [context popCurrentContext];
    }
  
  puts("=== Completed Generating Project");
  return result;
}

@end
