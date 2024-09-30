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
#import "XCConfigurationList.h"
#import "XCBuildConfiguration.h"

@implementation XCConfigurationList

- (instancetype) initWithConfigurations: (NSMutableArray *)configs
{
  self = [super init];
  if (self != nil)
    {
      [self setBuildConfigurations: configs];
    }
  return self;
}

/*
- (instancetype) init
{
  return [self initWithConfigurations: [NSMutableArray array]];
}
*/

// Methods....
- (NSString *) defaultConfigurationIsVisible // getter
{
  return defaultConfigurationIsVisible;
}

- (void) setDefaultConfigurationIsVisible: (NSString *)object; // setter
{
  ASSIGN(defaultConfigurationIsVisible,object);
}

- (NSMutableArray *) buildConfigurations // getter
{
  return buildConfigurations;
}

- (void) setBuildConfigurations: (NSMutableArray *)object; // setter
{
  ASSIGN(buildConfigurations,object);
}

- (NSString *) defaultConfigurationName // getter
{
  return defaultConfigurationName;
}

- (void) setDefaultConfigurationName: (NSString *)object; // setter
{
  ASSIGN(defaultConfigurationName,object);
}

- (XCBuildConfiguration *) defaultConfiguration
{
  NSEnumerator *en = [buildConfigurations objectEnumerator];
  NSString *defaultConfig = (defaultConfigurationName == nil)?
    @"Release":defaultConfigurationName;
  XCBuildConfiguration *config = nil;

  NSDebugLog(@"Number of build configurations = %ld\n%@",
             [buildConfigurations count], buildConfigurations);

  while((config = [en nextObject]) != nil)
    {
      if([[config name] 
	   isEqualToString: 
	     defaultConfig])
	{
	  break;
	}
    }

  return config;
}

- (void) applyDefaultConfiguration
{
  [[self defaultConfiguration] apply];
}

- (NSString *) description
{
  return [NSString stringWithFormat: @"%@ -- %@", [super description],
		   buildConfigurations];
}
@end
