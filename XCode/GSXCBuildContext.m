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
*/ #import "GSXCBuildContext.h"

id _sharedBuildContext = nil;

@implementation GSXCBuildContext

+ (id) sharedBuildContext
{
  if(_sharedBuildContext == nil)
    {
      _sharedBuildContext = [[GSXCBuildContext alloc] init];
    }
  return _sharedBuildContext;
}

- (id) init
{
  if((self = [super init]) != nil)
    {
      stack = [[NSMutableArray alloc] initWithCapacity: 10];
      contextDictionary = [[NSMutableDictionary alloc] init];
      config = [[NSDictionary alloc] initWithContentsOfFile: @"buildtool.plist"];
      NSDebugLog(@"%@",config);
    }
  return self;
}

- (void) dealloc
{
  RELEASE(stack);
  RELEASE(contextDictionary);
  RELEASE(config);
  
  [super dealloc];
}

- (NSDictionary *) config
{
  return config;
}

- (NSDictionary *) configForTargetName: (NSString *)name
{
  NSDictionary *targetDict = [config objectForKey: name];
  NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary: config];

  if (targetDict != nil)
    {
      [result addEntriesFromDictionary: targetDict]; // override existing entries.
    }
  
  return result;
}

- (NSMutableDictionary *) currentContext
{
  return currentContext;
}

- (NSMutableDictionary *) contextDictionaryForName: (NSString *)name
{
  currentContext = [contextDictionary objectForKey: name];
  if(currentContext == nil)
    {
      currentContext = [NSMutableDictionary dictionary];
      [contextDictionary setObject: currentContext forKey: name];
      [contextDictionary setObject: name forKey: @"TARGET_NAME"];
      [stack addObject: currentContext];
    }
  return currentContext;
}

- (NSMutableDictionary *) popCurrentContext
{
  NSMutableDictionary *popped = [stack lastObject];
  [stack removeLastObject];
  currentContext = [stack lastObject];
  return popped;
}

- (void) setObject: (id)object forKey: (id)key
{
  [currentContext setObject: object forKey: key];
}

- (id) objectForKey: (id)key
{
  return [currentContext objectForKey: key];
}

- (void) addEntriesFromDictionary: (NSDictionary *)dict;
{
  [currentContext addEntriesFromDictionary: dict];
}

- (NSString *) description
{
  return [NSString stringWithFormat: @"%@ -- contextDictionary = %@, \n currentContext = %@, \n stack = %@ \n\n",
		   [super description], contextDictionary, currentContext, stack];
}
@end
