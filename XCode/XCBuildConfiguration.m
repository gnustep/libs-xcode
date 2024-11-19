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
#import "XCBuildConfiguration.h"
#import "GSXCBuildContext.h"

#import <stdlib.h>

#ifdef _WIN32
#import "setenv.h"
#endif

@implementation XCBuildConfiguration

- (instancetype) initWithName: (NSString *)theName
		buildSettings: (NSMutableDictionary *)settings
{
  self = [super init];
  if (self != nil)
    {
      [self setBuildSettings: settings];
      [self setName: theName];
    }
  return self;
}

- (instancetype) initWithName: (NSString *)theName
{
  NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithObject: @"macosx"
								     forKey: @"SDKROOT"];
  return [self initWithName: theName
	      buildSettings: settings];
}

- (instancetype) init
{
  self = [super init];
  if (self != nil)
    {
      // nothing now...
    }
  return self;
}

- (NSString *) description
{
  return [NSString stringWithFormat: @"%@ -- buildSettings = %@, name = %@", [super description], buildSettings, name];
}

// Methods....
- (NSMutableDictionary *) buildSettings // getter
{
  return buildSettings;
}

- (void) setBuildSettings: (NSMutableDictionary *)object; // setter
{
  ASSIGN(buildSettings,object);
}

- (NSString *) name // getter
{
  return name;
}

- (void) setName: (NSString *)object; // setter
{
  ASSIGN(name,object);
}

- (void) apply
{
  xcputs([[NSString stringWithFormat: @"=== Applying Build Configuration %s%@%s",GREEN, name, RESET] cString]);
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSEnumerator *en = [buildSettings keyEnumerator];
  NSString *key = nil;

  while ((key = [en nextObject]) != nil)
    {
      id value = [buildSettings objectForKey: key];
      if ([value isKindOfClass: [NSString class]])
	{
	  setenv([key cString],[value cString],1);
	}
      else if([value isKindOfClass: [NSArray class]])
	{
	  [context setObject: value
		      forKey: key];
	  NSDebugLog(@"\tContext: %@ = %@",key,value);
	}
      else
	{
	  NSDebugLog(@"\tWARNING: Can't interpret value %@, for environment variable %@", value, key);
	}
    }

  if ([buildSettings objectForKey: @"TARGET_BUILD_DIR"] == nil)
    {
      NSDebugLog(@"\tEnvironment: TARGET_BUILD_DIR = build (built-in)");
      setenv("TARGET_BUILD_DIR","build",1);
      [context setObject: @"build" forKey: @"TARGET_BUILD_DIR"];
    }

  if ([buildSettings objectForKey: @"BUILT_PRODUCTS_DIR"] == nil)
    {
      NSDebugLog(@"\tEnvironment: BUILT_PRODUCTS_DIR = build (built-in)");
      setenv("BUILT_PRODUCTS_DIR","build",1);
      [context setObject: @"build" forKey: @"BUILD_PRODUCTS_DIR"];
    }

  xcputs([[NSString stringWithFormat: @"=== Done Applying Build Configuration for %@",name] cString]);
}
@end
