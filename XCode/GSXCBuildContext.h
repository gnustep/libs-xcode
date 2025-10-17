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
*/ #import <Foundation/Foundation.h>

@interface GSXCBuildContext : NSObject
{
  NSMutableDictionary *contextDictionary;
  NSMutableDictionary *currentContext;
  NSMutableArray *stack;
  NSDictionary *config;
}

/**
 * Returns the shared build context instance.
 */
+ (id) sharedBuildContext;

/**
 * Returns the current context dictionary.
 */
- (NSMutableDictionary *) currentContext;

/**
 * Returns the context dictionary for the given name.
 */
- (NSMutableDictionary *) contextDictionaryForName: (NSString *)name;

/**
 * Pops and returns the current context.
 */
- (NSMutableDictionary *) popCurrentContext;

/**
 * Returns the configuration dictionary.
 */
- (NSDictionary *) config;

/**
 * Returns the configuration for the given target name.
 */
- (NSDictionary *) configForTargetName: (NSString *)name;

/**
 * Sets an object for the given key in the current context.
 */
- (void) setObject: (id)object forKey: (id)key;

/**
 * Returns the object for the given key from the current context.
 */
- (id) objectForKey: (id)key;

/**
 * Adds entries from the given dictionary to the current context.
 */
- (void) addEntriesFromDictionary: (NSDictionary *)dict;

@end
