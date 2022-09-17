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

#import "GSXCBuildContext.h"
#import "NSString+PBXAdditions.h"
#import "xcsystem.h"

#import <stdlib.h>
#ifndef _MSC_VER
#import <unistd.h>
#endif

NSInteger xcsystem(NSString *cmd)
{
  GSXCBuildContext *ctx = [GSXCBuildContext sharedBuildContext];
  NSDictionary *dict = [ctx config];
  NSString *setupScript = [dict objectForKey: @"setupScript"];
  NSInteger r = 0;

  if(setupScript == nil)
    {
#ifdef _WIN32
      NSString *win_cmd = [cmd execPathForString];
      
      NSDebugLog(@"win_cmd = %@", win_cmd);
      r = system([win_cmd cString]);
#else
      r = system([cmd cString]);
#endif
    }
  else
    {
      NSString *scriptFormat = @"#!/bin/bash\n\n%@\nexit 0\n";
      NSString *body = @"";
      NSString *script = nil;
      
      body = [body stringByAppendingString: [NSString stringWithFormat: @". %@ > /dev/null\n", setupScript]];
      body = [body stringByAppendingString: [NSString stringWithFormat: @"%@\n", cmd]];

      script = [NSString stringWithFormat: scriptFormat, body];

      NSString *filename = [NSString stringWithFormat: @"bt_%lu.sh", [script hash]];
      NSString *scriptCmd = [NSString stringWithFormat: @"./build/%@", filename];
      BOOL f = [script writeToFile: scriptCmd
			atomically: YES
			  encoding: NSUTF8StringEncoding
			     error: NULL];
      if (f)
	{
#ifdef _WIN32
	  NSString *win_cmd = [scriptCmd execPathForString];
	  NSDebugLog(@"win_cmd = %@", win_cmd);
	  r = system([win_cmd cString]);
#else
	  r = system([scriptCmd cString]);
#endif
	}
      else
	{
	  NSLog(@"Failed to write out temporary script %@", scriptCmd);
	}
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
