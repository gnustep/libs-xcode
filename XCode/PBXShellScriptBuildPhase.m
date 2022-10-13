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

#import <Foundation/NSDictionary.h>

#import "PBXCommon.h"
#import "PBXShellScriptBuildPhase.h"
#import "NSString+PBXAdditions.h"

#import "xcsystem.h"

extern char **environ;

@implementation PBXShellScriptBuildPhase

- (void) dealloc
{
  RELEASE(_shellPath);
  RELEASE(_shellScript);
  RELEASE(_inputPaths);
  RELEASE(_outputPaths);
  RELEASE(_inputFileListPaths);
  RELEASE(_outputFileListPaths);

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
  return _shellPath;
}

- (void) setShellPath: (NSString *)object; // setter
{
  ASSIGN(_shellPath,object);
}

- (NSString *) shellScript // getter
{
  return _shellScript;
}

- (void) setShellScript: (NSString *)object; // setter
{
  ASSIGN(_shellScript,object);
}

- (NSMutableArray *) inputPaths // getter
{
  return _inputPaths;
}

- (void) setInputPaths: (NSMutableArray *)object; // setter
{
  ASSIGN(_inputPaths,object);
}

- (NSMutableArray *) outputPaths // getter
{
  return _outputPaths;
}

- (void) setOutputPaths: (NSMutableArray *)object; // setter
{
  ASSIGN(_outputPaths,object);
}

- (NSString *) environmentVariableString
{
  NSString *result = [NSString stringWithFormat: @"\n# Environment variables\n\n"];
  char **env = NULL;
  
  for (env = environ; *env != 0; env++)
    {
      char *thisEnv = *env;
      NSString *envStr = [NSString stringWithCString: thisEnv encoding: NSUTF8StringEncoding];
      NSArray *arr = [envStr componentsSeparatedByString: @"="];

      if ([arr count] == 2)
        {
          NSString *var = [arr objectAtIndex: 0];
          NSString *val = [arr objectAtIndex: 1];

          if ([val containsString: @"%"] == NO)
            {
              if ([val containsString: @"\""] ) // val is already quoted
                {
                  result = [result stringByAppendingString: [NSString stringWithFormat: @"export %@=%@\n", var, val]];
                }
              else
                {
                  result = [result stringByAppendingString: [NSString stringWithFormat: @"export %@=\"%@\"\n", var, val]];
                }
            }
        }
    }

  result = [result stringByAppendingString: @"# Done with environment setup...\n\n"];
  
  return result;
}

- (NSString *) contextString
{
  NSString *result = [NSString stringWithFormat: @"#!%@\n# Context variables\n\n", _shellPath];;
  GSXCBuildContext *ctx = [GSXCBuildContext sharedBuildContext];
  NSDictionary *dict = [ctx currentContext];
  NSArray *keys = [dict allKeys];
  NSEnumerator *en = [keys objectEnumerator];
  NSString *k = nil;

  result = [result stringByAppendingString: @"set -eo pipefail\n"
		   @"shopt -s inherit_errexit\n\n"];

  while ((k = [en nextObject]) != nil)
    {
      id v = [dict objectForKey: k];
      if ([v isKindOfClass: [NSString class]])
        {
          if ([v containsString: @"%"] == NO)
            {
              if ([v containsString: @"\""] ) // val is already quoted
                {
                  result = [result stringByAppendingString: [NSString stringWithFormat: @"export %@=%@\n", k, v]];
                }
              else
                {
                  result = [result stringByAppendingString: [NSString stringWithFormat: @"export %@=\"%@\"\n", k, v]];
                }
            }          
        }
    }

  result = [result stringByAppendingString: @"# Done with context setup...\n\n"];
  
  return result;
}

- (NSString *) preprocessScript
{
  NSDictionary *plistFile = [NSDictionary dictionaryWithContentsOfFile: @"buildtool.plist"];
  NSDictionary *searchReplace = [plistFile objectForKey: @"searchReplace"];
  NSString *script = nil;
  NSString *result = nil;

  ASSIGNCOPY(script, _shellScript);

  // Search & replace as defined in the plist file..
  if (searchReplace != nil)
    {
      NSEnumerator *en = [searchReplace keyEnumerator];
      NSString *key = nil;
      
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
              NSTextCheckingResult *match = [regex firstMatchInString: script
                                                              options: 0
                                                                range: NSMakeRange(0, [key length])];
              if (match != nil)
                {
                  NSRange matchRange = [match range];
                  script = [script stringByReplacingCharactersInRange: matchRange
                                                           withString: v];
                }
              else
                {
                  done = YES;
                }
            }
        }
    }

  // Replace any variables defined in the context
  result = [self contextString];
  // result = [result stringByAppendingString: [self environmentVariableString]];
  result = [result stringByAppendingString: @"\n# Script from project file...\n"];
  result = [result stringByAppendingString: script]; 
  result = [result stringByAppendingString: @"\n# Done with Xcode script\nexit $?\n"];

  return result;
}

- (BOOL) build
{
  NSError *error = nil;
  NSString *fileName = [NSString stringWithFormat: @"script_%@_%lu", [[self name] stringByEliminatingSpecialCharacters], [_shellScript hash]];
  NSString *tmpFilename = [NSString stringWithFormat: @"build/%@", fileName];
  NSString *command = [NSString stringWithFormat: @"%@ %@",_shellPath,tmpFilename];
  BOOL result = NO;
  NSString *processedScript = [self preprocessScript];

  // processedScript = [processedScript stringByReplacingEnvironmentVariablesWithValues];
  xcprintf("=== Executing Script Build Phase... %s%s%s\n", GREEN, [_name cString], RESET);
  xcputs([[NSString stringWithFormat: @"=== Command: %s%@%s using shell %@", YELLOW, command, RESET, _shellPath] cString]);
  xcputs("*** script output");
  [processedScript writeToFile: tmpFilename
                    atomically: YES
                      encoding: NSASCIIStringEncoding
                         error: &error];
  
  result = xcsystem(command);
  xcputs("*** script completed");
  xcputs("=== Done Executing Script Build Phase...");

  return (result == 0);
}
@end
