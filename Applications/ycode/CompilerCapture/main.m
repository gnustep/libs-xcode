/*
   Project: Ycode

   Copyright (C) 2025 Free Software Foundation

   Author: Gregory Casamento

   Created: 2025-01-15

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this application; if not, see
   <https://www.gnu.org/licenses/>.
*/

#import <Foundation/Foundation.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>

/* Invoked through compiler-name symlinks. Preserve argv and the compiler's
   exit status; never execute a shell or alter project flags. */
int
main (int argc, char **argv)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  NSDictionary *environment = [[NSProcessInfo processInfo] environment];
  NSData *mapping = [[environment objectForKey: @"YCODE_REAL_COMPILERS"]
      dataUsingEncoding: NSUTF8StringEncoding];
  NSDictionary *compilers
      = mapping ? [NSJSONSerialization JSONObjectWithData: mapping
                                                  options: 0
                                                    error: NULL]
                : nil;
  NSString *name = [[NSString stringWithUTF8String: argv[0]] lastPathComponent];
  NSString *compiler = [compilers objectForKey: name];
  if (![compiler length])
    {
      fprintf (stderr, "Ycode: missing original compiler\n");
      [pool drain];
      return 127;
    }
  NSMutableArray *arguments = [NSMutableArray arrayWithObject: compiler];
  BOOL compile = NO;
  NSString *source = nil;
  int index;
  NSArray *extensions = [NSArray
      arrayWithObjects: @"c", @"m", @"mm", @"cc", @"cpp", @"cxx", @"C", nil];
  for (index = 1; index < argc; index++)
    {
      NSString *argument = [NSString stringWithUTF8String: argv[index]];
      if (!argument)
        {
          [pool drain];
          return 127;
        }
      [arguments addObject: argument];
      if ([argument isEqual: @"-c"])
        compile = YES;
      if (![argument hasPrefix: @"-"] &&
          [extensions containsObject: [argument pathExtension]] &&
          [[NSFileManager defaultManager] fileExistsAtPath: argument])
        source = argument;
    }
  NSString *fragments = [environment objectForKey: @"YCODE_CDB_FRAGMENTS"];
  if (compile && source && [fragments length])
    {
      NSString *directory =
          [[NSFileManager defaultManager] currentDirectoryPath];
      if (![source isAbsolutePath])
        source = [directory stringByAppendingPathComponent: source];
      NSDictionary *entry = [NSDictionary
          dictionaryWithObjectsAndKeys: directory, @"directory",
                                       [source stringByStandardizingPath],
                                       @"file", arguments, @"arguments", nil];
      NSData *data = [NSJSONSerialization dataWithJSONObject: entry
                                                     options: 0
                                                       error: NULL];
      NSString *fragment =
          [fragments stringByAppendingPathComponent:
                         [[[NSProcessInfo processInfo] globallyUniqueString]
                             stringByAppendingPathExtension: @"json"]];
      [data writeToFile: fragment atomically: YES];
    }
  NSString *path = [environment objectForKey: @"YCODE_CAPTURE_PATH"];
  if (path)
    setenv ("PATH", [path UTF8String], 1);
  char *executable = strdup ([compiler fileSystemRepresentation]);
  [pool drain];
  argv[0] = executable;
  execv (executable, argv);
  perror ("Ycode compiler");
  free (executable);
  return 127;
}
