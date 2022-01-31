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

#import <Foundation/NSDictionary.h>

#import "PBXCommon.h"
#import "PBXShellScriptBuildPhase.h"
#import "NSString+PBXAdditions.h"

#import "xcsystem.h"

@implementation PBXShellScriptBuildPhase

- (void) dealloc
{
  RELEASE(shellPath);
  RELEASE(shellScript);
  RELEASE(inputPaths);
  RELEASE(outputPaths);
  RELEASE(_inputFileListPaths);
  RELEASE(_outputFileListPaths);
  RELEASE(name);

  [super dealloc];
}

// Methods....
- (NSMutableArray *) inputFileListPaths
{
  return _inputFileListPaths;
}

- (void) setInputFileListPaths: (NSMutableArray *)object
{
  ASSIGN(_inputFileListPaths, object);
}

- (NSMutableArray *) outputFileListPaths
{
  return _outputFileListPaths;
}

- (void) setOutputFileListPaths: (NSMutableArray *)object
{
  ASSIGN(_outputFileListPaths, object);
}

- (NSString *) shellPath // getter
{
  return shellPath;
}

- (void) setShellPath: (NSString *)object; // setter
{
  ASSIGN(shellPath,object);
}

- (NSString *) shellScript // getter
{
  return shellScript;
}

- (void) setShellScript: (NSString *)object; // setter
{
  ASSIGN(shellScript,object);
}

- (NSMutableArray *) inputPaths // getter
{
  return inputPaths;
}

- (void) setInputPaths: (NSMutableArray *)object; // setter
{
  ASSIGN(inputPaths,object);
}

- (NSMutableArray *) outputPaths // getter
{
  return outputPaths;
}

- (void) setOutputPaths: (NSMutableArray *)object; // setter
{
  ASSIGN(outputPaths,object);
}

- (NSString *) name // getter
{
  return name;
}

- (void) setName: (NSString *)object; // setter
{
  ASSIGN(name,object);
}

- (NSString *) preprocessScript
{
  NSDictionary *plistFile = [NSDictionary dictionaryWithContentsOfFile: @"buildtool.plist"];
  NSDictionary *searchReplace = [plistFile objectForKey: @"searchReplace"];
  NSEnumerator *en = [searchReplace keyEnumerator];
  NSString *key = nil;
  NSString *result = nil;
  
  ASSIGNCOPY(result, shellScript);
  
  while ((key = [en nextObject]) != nil)
    {
      NSString *v = [searchReplace objectForKey: key];
      NSError *error = NULL;
      BOOL done = NO;
      NSRegularExpression *regex = [NSRegularExpression
                                     regularExpressionWithPattern: key
                                                          options: 0
                                                            error: &error];

      // Iterate through all of the matches, but after each change start over because the ranges
      // will shift as a result of the substitution.  When there are no matches left, exit.
      while (done == NO)
        {
          NSTextCheckingResult *match = [regex firstMatchInString: result
                                                          options: 0
                                                            range: NSMakeRange(0, [key length])];
          if (match != nil)
            {
              NSRange matchRange = [match range];
              result = [result stringByReplacingCharactersInRange: matchRange
                                                       withString: v];
            }
          else
            {
              done = YES;
            }
        }
    }

  return result;
}

- (BOOL) build
{
  NSError *error = nil;
  NSString *fileName = [NSString stringWithFormat: @"script_%lu",[shellScript hash]];
  NSString *tmpFilename = [NSString stringWithFormat: @"/tmp/%@", fileName];
  NSString *command = [NSString stringWithFormat: @"%@ %@",shellPath,tmpFilename];
  BOOL result = NO;
  NSString *processedScript = [self preprocessScript];

  processedScript = [processedScript stringByReplacingEnvironmentVariablesWithValues];
  puts("=== Executing Script Build Phase...");
  puts([[NSString stringWithFormat: @"=== Command: \t%s%@%s", RED, command, RESET] cString]);
  puts("*** script output");
  [processedScript writeToFile: tmpFilename
                    atomically: YES
                      encoding: NSASCIIStringEncoding
                         error: &error];
  
  result = xcsystem(command);
  puts("*** script completed");
  puts("=== Done Executing Script Build Phase...");

  return (result == 0);
}
@end
