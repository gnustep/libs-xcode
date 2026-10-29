/* ToolDelegate.m
 *
 * Copyright (C) 2023 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg.casamento@gmail.com>
 * Date:	2023
 *
 * This file is part of GNUstep.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111
 * USA.
 */

#import <Foundation/Foundation.h>

#import <XCode/PBXCoder.h>
#import <XCode/PBXContainer.h>
#import <XCode/PBXProject.h>
#import <XCode/PBXTarget.h>
#import <XCode/NSString+PBXAdditions.h>
#import <XCode/XCWorkspaceParser.h>
#import <XCode/XCWorkspace.h>
#import <XCode/XCConfigurationList.h>

#import "ToolDelegate.h"
#import "ArgPair.h"

NSString *
findProjectFilename (NSArray *projectDirEntries)
{
  NSEnumerator *e = [projectDirEntries objectEnumerator];
  NSString *fileName;

  while ((fileName = [e nextObject]))
    {
      NSRange range = [fileName rangeOfString: @"._"];
      if ([[fileName pathExtension] isEqual: @"xcodeproj"]
          && range.location == NSNotFound)
        {
          return [fileName stringByAppendingPathComponent: @"project.pbxproj"];
        }
    }

  return nil;
}

NSString *
findWorkspaceFilename (NSArray *projectDirEntries)
{
  NSEnumerator *e = [projectDirEntries objectEnumerator];
  NSString *fileName;

  while ((fileName = [e nextObject]))
    {
      NSRange range = [fileName rangeOfString: @"._"];
      if ([[fileName pathExtension] isEqual: @"xcworkspace"]
          && range.location == NSNotFound)
        {
          return [fileName
              stringByAppendingPathComponent: @"contents.xcworkspacedata"];
        }
    }

  return nil;
}

NSString *
resolveProjectName (BOOL *isProject)
{
  NSString *fileName = nil;
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSString *projectDir = [fileManager currentDirectoryPath];
  NSArray *projectDirEntries =
      [fileManager directoryContentsAtPath: projectDir];

  fileName = findWorkspaceFilename (projectDirEntries);
  if (fileName != nil)
    {
      *isProject = NO;
    }
  else
    {
      *isProject = YES;
      fileName = findProjectFilename (projectDirEntries);
    }

  return fileName;
}

static BOOL
optionTakesValue (NSString *option)
{
  NSArray *options = [NSArray
      arrayWithObjects: @"-project", @"-workspace", @"-target", @"-scheme",
                       @"-configuration", @"-sdk", @"-arch", @"-destination",
                       @"-derivedDataPath", @"-archivePath", @"-jobs",
                       @"-write", @"generate", @"save", nil];

  return [options containsObject: option];
}

static BOOL
optionTakesNoValue (NSString *option)
{
  NSArray *options =
      [NSArray arrayWithObjects: @"-alltargets", @"-parallelizeTargets",
                                @"-quiet", @"-verbose", @"-list",
                                @"-showBuildSettings", @"-license", @"build",
                                @"install", @"clean", @"link", @"test", nil];

  return [options containsObject: option];
}

static NSString *
projectFileForPath (NSString *path, BOOL *isProject)
{
  NSString *fileName = nil;
  NSString *ext = [path pathExtension];

  if ([ext isEqualToString: @"xcworkspace"])
    {
      *isProject = NO;
      fileName =
          [path stringByAppendingPathComponent: @"contents.xcworkspacedata"];
    }
  else if ([ext isEqualToString: @"xcodeproj"])
    {
      *isProject = YES;
      fileName = [path stringByAppendingPathComponent: @"project.pbxproj"];
    }
  else if ([[path lastPathComponent] isEqualToString: @"project.pbxproj"])
    {
      *isProject = YES;
      fileName = path;
    }
  else if ([[path lastPathComponent]
               isEqualToString: @"contents.xcworkspacedata"])
    {
      *isProject = NO;
      fileName = path;
    }

  return fileName;
}

// ToolDelegate...
@implementation ToolDelegate

- (NSDictionary *) parseArguments
{
  NSMutableDictionary *result = [NSMutableDictionary dictionary];
  NSProcessInfo *pi = [NSProcessInfo processInfo];
  NSMutableArray *args = [NSMutableArray arrayWithArray: [pi arguments]];
  NSEnumerator *en = [args objectEnumerator];
  id obj = nil;
  BOOL parse_val = NO;
  ArgPair *pair = AUTORELEASE ([[ArgPair alloc] init]);

  while ((obj = [en nextObject]) != nil)
    {
      if (parse_val)
        {
          [pair setValue: obj];
          [result setObject: pair forKey: [pair argument]];
          parse_val = NO;
          continue;
        }
      else
        {
          pair = AUTORELEASE ([[ArgPair alloc] init]);

          if (optionTakesValue (obj))
            {
              [pair setArgument: obj];
              parse_val = YES;
            }

          if (optionTakesNoValue (obj))
            {
              [pair setArgument: obj];
              parse_val = NO;
            }

          // If there is no parameter for the argument, set it anyway...
          if (parse_val == NO)
            {
              [result setObject: pair forKey: obj];
            }
        }
    }

  if (parse_val == YES)
    {
      [self postMessage: @"# Parameter is mandatory, non specified."];
      return nil; // exit if no parameter...
    }

  return result;
}

// -target, -scheme, and xcodebuild's -only-testing:<id> and
// -skip-testing:<id> (which can be repeated), for the test action.
- (NSDictionary *) testOptions: (NSDictionary *)args
{
  NSMutableDictionary *options = [NSMutableDictionary dictionary];
  NSMutableArray *only = [NSMutableArray array];
  NSMutableArray *skip = [NSMutableArray array];
  NSEnumerator *en =
      [[[NSProcessInfo processInfo] arguments] objectEnumerator];
  NSString *arg = nil;

  if ([[args objectForKey: @"-target"] value] != nil)
    {
      [options setObject: [[args objectForKey: @"-target"] value]
                  forKey: @"target"];
    }
  if ([[args objectForKey: @"-scheme"] value] != nil)
    {
      [options setObject: [[args objectForKey: @"-scheme"] value]
                  forKey: @"scheme"];
    }
  while ((arg = [en nextObject]) != nil)
    {
      if ([arg hasPrefix: @"-only-testing:"])
        {
          [only addObject:
                    [arg substringFromIndex: [@"-only-testing:" length]]];
        }
      else if ([arg hasPrefix: @"-skip-testing:"])
        {
          [skip addObject:
                    [arg substringFromIndex: [@"-skip-testing:" length]]];
        }
    }
  [options setObject: only forKey: @"only"];
  [options setObject: skip forKey: @"skip"];
  return options;
}

- (BOOL) applyTargetName: (NSString *)targetName toProject: (PBXProject *)project
{
  NSMutableArray *matchingTargets = [NSMutableArray array];
  NSEnumerator *en = [[project targets] objectEnumerator];
  PBXTarget *target = nil;

  while ((target = [en nextObject]) != nil)
    {
      if ([[target name] isEqualToString: targetName])
        {
          [matchingTargets addObject: target];
        }
    }

  if ([matchingTargets count] == 0)
    {
      [self postMessage: @"# No target named \"%@\".", targetName];
      return NO;
    }

  [project setTargets: matchingTargets];
  return YES;
}

- (void) applyConfigurationName: (NSString *)configurationName
                     toProject: (PBXProject *)project
{
  NSEnumerator *en = [[project targets] objectEnumerator];
  PBXTarget *target = nil;

  [[project buildConfigurationList]
      setDefaultConfigurationName: configurationName];

  while ((target = [en nextObject]) != nil)
    {
      [[target buildConfigurationList]
          setDefaultConfigurationName: configurationName];
    }
}

- (BOOL) process
{
  NSString *file = nil;
  NSString *fileName = nil;
  NSDictionary *args = [self parseArguments];
  ArgPair *opt = nil;
  BOOL isProject = NO;
  BOOL success = NO;
  NSString *parameter = nil; //  @"cmake";

  // NSLog(@"args = %@", args);
  // NSLog(@"file = %@", file);

  // Get the file to write out to...
  NSString *outputFile = nil;

  if (args == nil)
    {
      return NO;
    }

  opt = [args objectForKey: @"-project"];
  if (opt != nil)
    {
      file = [opt value];
    }

  opt = [args objectForKey: @"-workspace"];
  if (opt != nil)
    {
      file = [opt value];
    }

  if (file != nil)
    {
      fileName = projectFileForPath (file, &isProject);
      if (fileName == nil)
        {
          [self postMessage: @"# Unsupported project path: %@", file];
          return NO;
        }
    }
  else
    {
      fileName = resolveProjectName (&isProject);
    }

  if (fileName == nil
      || ![[NSFileManager defaultManager] fileExistsAtPath: fileName])
    {
      [self
          postMessage: @"# Project or workspace file not found: %@", fileName];
      return NO;
    }

  // If any of these other options is defined, then don't build because we are transforming data...
  opt = [args objectForKey: @"-write"];
  if (opt != nil)
    {
      outputFile = [opt value];
      NSLog (@"outputFile = %@", outputFile);
    }

  if (opt == nil)
    {
      NSString *function = nil;

      // Get the current function...
      opt = [args objectForKey: @"build"];
      if (opt != nil)
        {
          function = @"build";
        }

      opt = [args objectForKey: @"install"];
      if (opt != nil)
        {
          function = @"install";
        }

      opt = [args objectForKey: @"clean"];
      if (opt != nil)
        {
          function = @"clean";
        }

      opt = [args objectForKey: @"test"];
      if (opt != nil)
        {
          function = @"test";
        }

      opt = [args objectForKey: @"generate"];
      if (opt != nil)
        {
          function = @"generate";
          ASSIGN (parameter, [opt value]);
        }

      opt = [args objectForKey: @"link"];
      if (opt != nil)
        {
          function = @"link";
        }

      opt = [args objectForKey: @"save"];
      if (opt != nil)
        {
          function = @"save";
          ASSIGN (parameter, [opt value]);
        }

      // if no function is specified, build is the default...
      if (function == nil)
        {
          function = @"build";
        }

      // Execute..
      if (function != nil)
        {
          NS_DURING
          {
            NSString *display = [function stringByCapitalizingFirstCharacter];
            SEL operation = NSSelectorFromString (function);

            if (fileName == nil)
              {
                fileName = resolveProjectName (&isProject);
              }

            if (isProject)
              {
                PBXCoder *coder = nil;
                PBXContainer *container = nil;

                // Unarchive...
                coder = [[PBXCoder alloc] initWithContentsOfFile: fileName];
                container = [coder unarchive];
                [container setParameter: parameter];
                if ([function isEqualToString: @"test"])
                  {
                    [container setTestOptions: [self testOptions: args]];
                  }

                opt = [args objectForKey: @"-configuration"];
                if (opt != nil)
                  {
                    [self applyConfigurationName: [opt value]
                                       toProject: [container rootObject]];
                  }

                opt = [args objectForKey: @"-target"];
                if (opt == nil)
                  {
                    opt = [args objectForKey: @"-scheme"];
                  }
                if (opt != nil && [args objectForKey: @"-alltargets"] == nil
                    && ![function isEqualToString: @"test"] &&
                    [self applyTargetName: [opt value]
                                toProject: [container rootObject]]
                        == NO)
                  {
                    RELEASE (coder);
                    return NO;
                  }

                [coder setDelegate: self];

                // Build...
                if ([container respondsToSelector: operation])
                  {
                    // build...
                    [self
                        postMessage: @"\033[1;32m**\033[0m Start operation %@",
                                    display];
                    BOOL (*invoke) (id, SEL) = (BOOL (*) (
                        id, SEL))[container methodForSelector: operation];
                    success = invoke (container, operation);
                    if (success)
                      {
                        [self postMessage: @"\033[1;32m**\033[0m %@ Succeeded",
                                          display];
                      }
                    else
                      {
                        [self postMessage: @"\033[1;31m**\033[0m %@ Failed",
                                          display];
                      }
                  }
                else
                  {
                    [self postMessage: @"Unknown build operation \"%@\" for %@",
                                      display, container];
                  }
              }
            else
              {
                XCWorkspaceParser *p =
                    [XCWorkspaceParser parseWorkspaceFile: fileName];
                XCWorkspace *w = [p workspace];

                if ([w respondsToSelector: operation])
                  {
                    BOOL (*invoke) (id, SEL)
                        = (BOOL (*) (id, SEL))[w methodForSelector: operation];
                    success = invoke (w, operation);
                  }
              }
          }
          NS_HANDLER
          {
            NSLog (@"%@", localException);
            success = NO;
          }
          NS_ENDHANDLER;
        }
    }
  return success;
}

@end
