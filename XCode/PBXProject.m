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
#import "PBXProject.h"
#import "PBXContainer.h"
#import "PBXNativeTarget.h"
#import "GSXCBuildContext.h"
#import "NSString+PBXAdditions.h"

#import "PBXTarget.h"
#import "PBXTargetDependency.h"
#import "XCBuildConfiguration.h"
#import "XCConfigurationList.h"

#ifndef _MSC_VER
#import <unistd.h>
#endif

#ifdef _WIN32
#import "setenv.h"
#endif

@interface PBXTarget (Private)

- (NSArray *) prerequisiteTargets;

@end

@implementation PBXTarget (Private)

- (NSArray *) prerequisiteTargets
{
  NSMutableArray *result = [NSMutableArray arrayWithCapacity: [_dependencies count]];
  NSEnumerator *en = [_dependencies objectEnumerator];
  PBXTargetDependency *t = nil;

  while ((t = [en nextObject]) != nil)
    {
      id tg = [t target];

      if (tg != nil)
	{
	  [result addObject: tg];
	  xcputs([[NSString stringWithFormat: @"\t* %@ - Added to dependencies", tg] cString]);
	}
    }

  return result;
}

@end

@interface PBXProject (Private)

- (void) recurseTargetDependencies: (NSArray *)targets
			 forTarget: (PBXTarget *)target
			    result: (NSMutableArray *)result;

- (NSMutableArray *) arrangedTargets;

@end

@implementation PBXProject (Private)

- (void) recurseTargetDependencies: (NSArray *)targets
			 forTarget: (PBXTarget *)target
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
      PBXTarget *t = nil;

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

- (instancetype) init
{
  self = [super init];

  if (self != nil)
    {
      // Set up defaults...
      [self setCompatibilityVersion: @"Xcode 14.0"];
      [self setDevelopmentRegion: @"en"];
      // [self setKnownRegions: [NSMutableArray arrayWithObjects: @"en", @"Base", nil]];
      [self setProjectDirPath: @""];
      [self setProjectRoot: @""];
      [self setHasScannedForEncodings: @"0"];
      // [self setTargets: [NSMutableArray array]];
    }

  return self;
}

// Methods...
- (BOOL) minimizedProjectReferenceProxies // getter
{
  return _minimizedProjectReferenceProxies;
}

- (void) setMinimizedProjectReferenceProxies: (BOOL)flag // setter
{
  _minimizedProjectReferenceProxies = flag;
}

- (NSString *) preferredProjectObjectVersion // getter
{
  return _preferredProjectObjectVersion;
}

- (void) setPreferredProjectObjectVersion: (NSString *)object // setter
{
  ASSIGN(_preferredProjectObjectVersion, object);
}

- (NSString *) developmentRegion // getter
{
  return _developmentRegion;
}

- (void) setDevelopmentRegion: (NSString *)object // setter
{
  ASSIGN(_developmentRegion,object);
}

- (NSMutableArray *) knownRegions // getter
{
  return _knownRegions;
}

- (void) setKnownRegions: (NSMutableArray *)object // setter
{
  ASSIGN(_knownRegions,object);
}

- (NSString *) compatibilityVersion // getter
{
  return _compatibilityVersion;
}

- (void) setCompatibilityVersion: (NSString *)object // setter
{
  ASSIGN(_compatibilityVersion,object);
}

- (NSMutableArray *) projectReferences // getter
{
  return _projectReferences;
}

- (void) setProjectReferences: (NSMutableArray *)object // setter
{
  ASSIGN(_projectReferences,object);
}

- (NSMutableArray *) targets // getter
{
  return _targets;
}

- (void) setTargets: (NSMutableArray *)object // setter
{
  ASSIGN(_targets,object);
}

- (NSString *) projectDirPath // getter
{
  return _projectDirPath;
}

- (void) setProjectDirPath: (NSString *)object // setter
{
  ASSIGN(_projectDirPath,object);
}

- (NSString *) projectRoot // getter
{
  return _projectRoot;
}

- (void) setProjectRoot: (NSString *)object // setter
{
  ASSIGN(_projectRoot,object);
}

- (XCConfigurationList *) buildConfigurationList // getter
{
  return _buildConfigurationList;
}

- (void) setBuildConfigurationList: (XCConfigurationList *)object // setter
{
  ASSIGN(_buildConfigurationList,object);
}

- (PBXGroup *) mainGroup // getter
{
  return _mainGroup;
}

- (void) setMainGroup: (PBXGroup *)object // setter
{
  ASSIGN(_mainGroup,object);
}

- (NSString *) hasScannedForEncodings // getter
{
  return _hasScannedForEncodings;
}

- (void) setHasScannedForEncodings: (NSString *)object // setter
{
  ASSIGN(_hasScannedForEncodings,object);
}

- (PBXGroup *) productRefGroup // getter
{
  return _productRefGroup;
}

- (void) setProductRefGroup: (PBXGroup *)object // setter
{
  ASSIGN(_productRefGroup,object);
}

- (PBXContainer *) container
{
  return _container;
}

- (void) setContainer: (PBXContainer *)object
{
  _container = object; // container retains us, do not retain it...
}

- (void) setContext: (NSDictionary *)context
{
  ASSIGN(_ctx,context);
}

- (NSDictionary *) context
{
  return _ctx;
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
  xcprintf("=== Planning build -- Recursing dependencies...");
  _arrangedTargets = [self arrangedTargets];
  xcprintf("%ld targets - completed\n", (long)[_arrangedTargets count]);
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
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *output = nil;
  // NSString *cmd = nil;
  // cmd = @"gnustep-config --debug-flags";

  // Context...
  output = @"`gnustep-config --debug-flags`"; //[NSString stringForCommand: cmd];
  [context setObject: output
	      forKey: @"CONFIG_STRING"];

  return output;
}

- (BOOL) build
{
  NSString *fn = [[[self container] filename]
		   stringByDeletingLastPathComponent];

  xcprintf("=== Building Project %s%s%s%s\n", BOLD, GREEN, [fn cString], RESET);
  [_buildConfigurationList applyDefaultConfiguration];
  [self _sourceRootFromMainGroup];
  [self plan];

  // Show list of targets...
  NSEnumerator *ten = [_arrangedTargets objectEnumerator];
  id t = nil;
  NSUInteger c = 0;

  while ((t = [ten nextObject]) != nil)
    {
      c++;
      xcprintf("\t* Target #%ld: %s%s%s%s\n", c, BOLD, GREEN, [[t name] cString], RESET);
    }

  NSDebugLog(@"arrangedTargets = %@", _arrangedTargets);

  NSFileManager *fileManager = [NSFileManager defaultManager];
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSEnumerator *en = [_arrangedTargets objectEnumerator];
  id target = nil;
  BOOL result = YES;

  while((target = [en nextObject]) != nil && result)
    {
      [target setProject: self];
      [context contextDictionaryForName: [target name]];
      [self buildString];

      if(YES == [fileManager fileExistsAtPath: [target name]])
	{
	  [context setObject: @"YES"
		      forKey: @"TARGET_IN_SUBDIR"];
	}

      [context setObject: _mainGroup
		  forKey: @"MAIN_GROUP"];
      [context setObject: _container
		  forKey: @"CONTAINER"];
      [context setObject: @"./"
		  forKey: @"PROJECT_ROOT"];
      [context setObject: @"./"
		  forKey: @"PROJECT_DIR"];
      [context setObject: @"./"
		  forKey: @"SRCROOT"];
      [context setObject: @"./"
		  forKey: @"SOURCE_ROOT"];
      [context addEntriesFromDictionary: _ctx];

      result = [target build];
      [context popCurrentContext];

      if (result == NO)
	{
	  break;
	}
    }

  xcprintf("=== Done Building Project %s%s%s%s\n", BOLD, GREEN, [fn cString], RESET);

  return result;
}

- (BOOL) clean
{
  xcputs("=== Cleaning Project");
  [_buildConfigurationList applyDefaultConfiguration];

  NSFileManager *fileManager = [NSFileManager defaultManager];
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSEnumerator *en = [_targets objectEnumerator];
  id target = nil;
  BOOL result = YES;

  while((target = [en nextObject]) != nil && result)
    {
      [target setProject: self];
      if(YES == [fileManager fileExistsAtPath:[target name]])
	{
	  [context setObject: @"YES"
		      forKey: @"TARGET_IN_SUBDIR"];
	}

      [context contextDictionaryForName: [target name]];
      [context setObject: _mainGroup
		  forKey: @"MAIN_GROUP"];
      //      [context setObject: _container
      //		  forKey: @"CONTAINER"];
      [context setObject: @"./"
		  forKey: @"PROJECT_ROOT"];
      [context setObject: @"./"
		  forKey: @"PROJECT_DIR"];
      [context setObject: @"./"
		  forKey: @"SRCROOT"];
      [context setObject: @"./"
		  forKey: @"SOURCE_ROOT"];
      [context addEntriesFromDictionary: _ctx];

      result = [target clean];
      [context popCurrentContext];
    }
  xcputs("=== Completed Cleaning Project");
  return result;
}

- (BOOL) install
{
  xcputs("=== Installing Project");
  [_buildConfigurationList applyDefaultConfiguration];

  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSEnumerator *en = [_targets objectEnumerator];
  id target = nil;
  BOOL result = YES;
  while((target = [en nextObject]) != nil && result)
    {
      [target setProject: self];
      [context contextDictionaryForName: [target name]];
      [context setObject: _mainGroup
		  forKey: @"MAIN_GROUP"];
      //      [context setObject: _container
      //		  forKey: @"CONTAINER"];
      [context setObject: @"./"
		  forKey: @"PROJECT_ROOT"];
      [context setObject: @"./"
		  forKey: @"PROJECT_DIR"];
      [context setObject: @"./"
		  forKey: @"SRCROOT"];
      [context setObject: @"./"
		  forKey: @"SOURCE_ROOT"];
      [context addEntriesFromDictionary: _ctx];

      result = [target install];
      [context popCurrentContext];
    }
  xcputs("=== Completed Installing Project");
  return result;
}

- (BOOL) generate
{
  NSString *fn = [[[self container] filename]
		   stringByDeletingLastPathComponent];

  xcprintf("=== Generating %@ for Project %s%s%s%s\n", [_container parameter], BOLD, GREEN, [fn cString], RESET);
  [_buildConfigurationList applyDefaultConfiguration];
  [self _sourceRootFromMainGroup];
  [self plan];

  NSFileManager *fileManager = [NSFileManager defaultManager];
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSEnumerator *en = [_arrangedTargets objectEnumerator];
  id target = nil;
  BOOL result = YES;

  while((target = [en nextObject]) != nil && result)
    {
      [target setProject: self];
      [context contextDictionaryForName: [target name]];
      [self buildString];

      if(YES == [fileManager fileExistsAtPath:[target name]])
	{
	  [context setObject: @"YES"
		      forKey: @"TARGET_IN_SUBDIR"];
	}

      [context setObject: _mainGroup
		  forKey: @"MAIN_GROUP"];
      [context setObject: _container
		  forKey: @"CONTAINER"];
      [context setObject: @"./"
		  forKey: @"PROJECT_ROOT"];
      [context setObject: @"./"
		  forKey: @"PROJECT_DIR"];
      [context setObject: @"./"
		  forKey: @"SRCROOT"];
      [context setObject: @"./"
		  forKey: @"SOURCE_ROOT"];
      [context addEntriesFromDictionary: _ctx];

      result = [target generate];
      [context popCurrentContext];

      if (result == NO)
	{
	  break;
	}
    }

  xcputs("=== Completed Generating Project");
  return result;
}

- (BOOL) link
{
  NSString *fn = [[[self container] filename]
		   stringByDeletingLastPathComponent];

  xcprintf("=== Linking Project %s%s%s%s\n", BOLD, GREEN, [fn cString], RESET);
  [_buildConfigurationList applyDefaultConfiguration];
  [self _sourceRootFromMainGroup];
  // [self plan];

  // NSLog(@"arrangedTargets = %@", _arrangedTargets);

  NSFileManager *fileManager = [NSFileManager defaultManager];
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSEnumerator *en = [_targets objectEnumerator];
  id target = nil;
  BOOL result = YES;

  while((target = [en nextObject]) != nil && result)
    {
      [target setProject: self];
      [context contextDictionaryForName: [target name]];
      [self buildString];

      if(YES == [fileManager fileExistsAtPath: [target name]])
	{
	  [context setObject: @"YES"
		      forKey: @"TARGET_IN_SUBDIR"];
	}

      [context setObject: _mainGroup
		  forKey: @"MAIN_GROUP"];
      [context setObject: _container
		  forKey: @"CONTAINER"];
      [context setObject: @"./"
		  forKey: @"PROJECT_ROOT"];
      [context setObject: @"./"
		  forKey: @"PROJECT_DIR"];
      [context setObject: @"./"
		  forKey: @"SRCROOT"];
      [context setObject: @"./"
		  forKey: @"SOURCE_ROOT"];
      [context addEntriesFromDictionary: _ctx];

      result = [target link];
      [context popCurrentContext];

      if (result == NO)
	{
	  break;
	}
    }

  xcprintf("=== Done Linking Project %s%s%s%s\n", BOLD, GREEN, [fn cString], RESET);

  return result;
}

- (XCConfigurationList *) _defaultConfigList
{
  XCConfigurationList *xcl = AUTORELEASE([[XCConfigurationList alloc] init]);
  XCBuildConfiguration *config = AUTORELEASE([[XCBuildConfiguration alloc] init]);
  NSMutableArray *configs = [NSMutableArray arrayWithObject: config];

  [config setName: @"Debug"];
  [config setBuildSettings: [NSMutableDictionary dictionaryWithObject: @"macosx"
							       forKey: @"SDKROOT"]];
  [xcl setDefaultConfigurationName: @"Debug"];
  [xcl setBuildConfigurations: configs];

  return xcl;
}

- (BOOL) save
{
  NSEnumerator *en = [_arrangedTargets objectEnumerator];
  id target = nil;

  // Set up the configuration list...
  [self setBuildConfigurationList: [self _defaultConfigList]];

  id targetConfig = [self _defaultConfigList];
  while((target = [en nextObject]) != nil)
    {
      [target setBuildConfigurationList: targetConfig]; // set up config list.
    }

  return YES;
}

@end
