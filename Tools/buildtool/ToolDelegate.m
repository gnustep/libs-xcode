/* AppDelegate.m
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

#import "ToolDelegate.h"
#import "ArgPair.h"

// AppDelegate...
@implementation ToolDelegate

- (NSDictionary *) parseArguments
{
  NSMutableDictionary *result = [NSMutableDictionary dictionary];
  NSProcessInfo *pi = [NSProcessInfo processInfo];
  NSMutableArray *args = [NSMutableArray arrayWithArray: [pi arguments]];
  BOOL filenameIsLastObject = NO;
  NSString *file = nil;  
  NSEnumerator *en = [args objectEnumerator];
  id obj = nil;
  BOOL parse_val = NO;
  ArgPair *pair = AUTORELEASE([[ArgPair alloc] init]);
  
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
	  pair = AUTORELEASE([[ArgPair alloc] init]);

	  if ([obj isEqualToString: @"--read"])
	    {
	      [pair setArgument: obj];
	      parse_val = YES;	      
	    }

	  if ([obj isEqualToString: @"--write"])
	    {
	      [pair setArgument: obj];
	      parse_val = YES;
	    }

	  // If there is no parameter for the argument, set it anyway...
	  if (parse_val == NO)
	    {
	      [result setObject: pair forKey: obj];
	    }
	}
    }

  return result;
}

- (void) process
{
  NSProcessInfo *pi = [NSProcessInfo processInfo];
  
  if ([[pi arguments] count] > 1)
    {
      NSString *file = nil;
      NSString *outputPath = @"./";
      NSDictionary *args = [self parseArguments];
      ArgPair *opt = nil;
      
      NSDebugLog(@"args = %@", args);
      NSDebugLog(@"file = %@", file);

      // Get the file to write out to...
      NSString *outputFile = nil;

      opt = [args objectForKey: @"--read"];
      if (opt != nil)
	{
	  file = [opt value];
	}

      if (file != nil)
	{
	}
      else
	{
	  NSLog(@"No document specified");
	  return;
	}
      
    }
}

@end
