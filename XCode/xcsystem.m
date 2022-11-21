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

#import <Foundation/NSUUID.h>
#import <Foundation/NSTask.h>

#import "GSXCBuildContext.h"
#import "NSString+PBXAdditions.h"
#import "xcsystem.h"

#import <stdlib.h>
#ifndef _MSC_VER
#import <unistd.h>
#endif

extern char **environ;

NSString *contextString()
{
  NSString *result = @"\n# Context variables\n\n";
  GSXCBuildContext *ctx = [GSXCBuildContext sharedBuildContext];
  NSDictionary *dict = [ctx currentContext];
  NSArray *keys = [dict allKeys];
  NSEnumerator *en = [keys objectEnumerator];
  NSString *k = nil;

  while ((k = [en nextObject]) != nil)
    {
      if (![k isEqualToString: @"OUTPUT_FILES"]) // exclude some vars
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
    }

  result = [result stringByAppendingString: @"# Done with context setup...\n\n"];
  
  return result;
}

NSInteger xcsystem(NSString *cmd)
{
  GSXCBuildContext *ctx = [GSXCBuildContext sharedBuildContext];
  NSDictionary *dict = [ctx config];
  NSString *setupScript = [dict objectForKey: @"setupScript"];
  NSInteger r = 0;
  NSString *scriptFormat = @"#!/bin/bash\n"
    @"set -eo pipefail\n"
    @"shopt -s inherit_errexit\n\n"
    @"%@\n\n"
    @"exit $?\n";
  NSString *body = @"";
  NSString *script = nil;
  NSString *c = [cmd stringByReplacingOccurrencesOfString: @"$(SRCROOT)" withString: @"."];

  if (setupScript != nil)
    {
      body = [body stringByAppendingString: [NSString stringWithFormat: @". %@ > /dev/null\n", setupScript]];
    }
  
  body = [body stringByAppendingString: contextString()];
  body = [body stringByAppendingString: [NSString stringWithFormat: @"%@\n", c]];
  script = [NSString stringWithFormat: scriptFormat, body];
  
  NSString *filename = [NSString stringWithFormat: @"bt_%lu.sh", [script hash]];
  NSString *scriptCmd = [NSString stringWithFormat: @"build/%@", filename];
  BOOL f = [script writeToFile: scriptCmd
		    atomically: YES
		      encoding: NSUTF8StringEncoding
			 error: NULL];

  // make script executable
  if (f)
    {
      NSFileManager *mgr = [NSFileManager defaultManager];
      NSString *octal = @"0755"; // permissions
      unsigned long value = 0;

      f = NO;
      sscanf([octal UTF8String], "%lo", &value);

      if (value != 0)
	{
	  NSNumber *n = [NSNumber numberWithLong: value];
	  NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys: n, NSFilePosixPermissions, nil];
	  
	  f = [mgr changeFileAttributes: attrs
				 atPath: scriptCmd];
	}
      else
	{
	  NSLog(@"Couldn't scan permissions value");
	}
    }
  else
    {
      NSLog(@"Unable to write %@", scriptCmd);
    }

  // run it...
  if (f)
    {
      NSTask *task;
      
#ifdef _WIN32
      NSString *win_cmd = [scriptCmd execPathForString];

      NSDebugLog(@"win_cmd = %@", win_cmd);
      task = [NSTask launchedTaskWithLaunchPath: [win_cmd stringByResolvingPath]
				      arguments: nil];
#else
      task = [NSTask launchedTaskWithLaunchPath: [scriptCmd stringByResolvingPath]
				      arguments: nil];
#endif
      if (task)
	{
	  [task waitUntilExit];
	}
      else
	{
	  NSLog(@"Failed to start task %@", scriptCmd);
	}
    }
  else
    {
      NSLog(@"Failed to permissions for script %@", scriptCmd);
    }

  return r;
}

void xcputs(const char *str)
{
  puts(str);
  fflush(stdout);
}

void xcput_string(NSString *str)
{
  xcputs([str cString]);
}

int xcprintf(const char *format, ...)
{
    int result;
    va_list args;

    va_start(args, format);
    result = vprintf(format, args);
    va_end(args);

    fflush(stdout);

    return result;
}
