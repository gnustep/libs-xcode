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
*/ #import <Foundation/NSArray.h>
#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSDictionary.h>

#import "NSString+PBXAdditions.h"
#import <unistd.h>

extern char **environ;

@implementation NSString (PBXAdditions)

- (NSString *) firstPathComponent
{
  NSArray *components = [self pathComponents];
  return ([components count] > 0)?[components objectAtIndex: 0]:@"";
}

- (NSString *) stringByEscapingSpecialCharacters
{
  NSString *result = nil;

  result = [self stringByReplacingOccurrencesOfString: @" "
						     withString: @"_"];
  result = [self stringByReplacingOccurrencesOfString: @"("
                                           withString: @"\\)"];
  result = [self stringByReplacingOccurrencesOfString: @")"
                                           withString: @"\\)"];
  result = [self stringByReplacingOccurrencesOfString: @"["
                                           withString: @"\\["];
  result = [self stringByReplacingOccurrencesOfString: @"]"
                                           withString: @"\\]"];
  result = [self stringByReplacingOccurrencesOfString: @"{"
                                           withString: @"\\{"];
  result = [self stringByReplacingOccurrencesOfString: @"}"
                                           withString: @"\\}"];

  return result;
}

- (NSString *) stringByEliminatingSpecialCharacters
{
  NSString *cs = @"()[]/\\| ";
  NSString *result = @"";
  NSUInteger l = [self length];
  NSUInteger i = 0;

  for (i = 0; i < l; i++)
    {
      NSString *c = [NSString stringWithFormat: @"%c",[self characterAtIndex: i]];
      if ([cs containsString: c])
        {
          continue;
        }
      result = [result stringByAppendingString: c];
    }

  return result;
}

- (NSString *) stringByCapitalizingFirstCharacter
{
  unichar c = [self characterAtIndex: 0];
  NSRange range = NSMakeRange(0,1);
  NSString *oneChar = [[NSString stringWithFormat:@"%C",c] uppercaseString];
  NSString *name = [self stringByReplacingCharactersInRange: range withString: oneChar];
  
  return name;
}

- (NSString *) stringByDeletingFirstPathComponent
{
  NSArray *components = [self pathComponents];
  NSString *firstComponent = [self firstPathComponent];
  NSString *result = @"";
  NSEnumerator *en = [components objectEnumerator];
  NSString *c = nil;

  while ((c = [en nextObject]) != nil)
    {
      if ([c isEqualToString: firstComponent])
        continue;
      
      result = [result stringByAppendingPathComponent: c];
    }
  
  return result;
}

- (NSString *) stringByReplacingEnvironmentVariablesWithValues
{
  NSString *result = nil;
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];

  result = [NSString stringWithString: self]; // autoreleased copy
  
  // Get env vars...
  char **env = NULL;
  for (env = environ; *env != 0; env++)
    {
      char *thisEnv = *env;
      NSString *envStr = [NSString stringWithCString: thisEnv encoding: NSUTF8StringEncoding];
      NSArray *components = [envStr componentsSeparatedByString: @"="];
      [dict setObject: [components lastObject]
               forKey: [components firstObject]];
    }

  // Replace all variables in the plist with the values...
  NSArray *keys = [dict allKeys];
  NSEnumerator *en = [keys objectEnumerator];
  NSString *k = nil;
  while ((k = [en nextObject]) != nil)
    {
      NSString *v = [dict objectForKey: k];
      result = [result stringByReplacingOccurrencesOfString: [NSString stringWithFormat: @"$(%@)",k]
                                                 withString: v];
      result = [result stringByReplacingOccurrencesOfString: [NSString stringWithFormat: @"$%@",k]
                                                 withString: v];
    }

  return result;
}

- (NSString *) stringByAddingQuotationMarks
{
  return [NSString stringWithFormat: @"\"%@\"", self];
}

+ (NSString *) stringForCommand: (NSString *)command
{
  NSString *output = nil;
  char string[2048];
  const char *cmd_string;
  FILE *fp;
  
  cmd_string = [command cString];
  
  /* Open the command for reading. */
  fp = popen(cmd_string, "r");
  if (fp != NULL)
    {
      output = @"";
      
      /* Read the output a line at a time - output it. */
      while (fgets(string, sizeof(string) - 1, fp) != NULL)
        {
          int len = strlen(string);
          int i = 0;

          for(i = 0; i < len; i++)
            {
              if(string[i] == '\n')
                {
                  string[i] = ' ';
                }
            }

          output = [output stringByAppendingString: 
                             [NSString stringWithCString: string]];
        }
      
      fclose(fp);
    }
  
  return output;
}

+ (NSString *) stringForEnvironmentVariable: (char *)envvar
{
  char *v = getenv("FRAMEWORK_VERSION");

  if (v != NULL)
    {
      return [NSString stringWithCString: v];
    }

  return nil;
}

@end
