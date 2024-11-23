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
#import "PBXGroup.h"

@implementation PBXGroup

- (instancetype) init
{
  self = [super init];
  if (self != nil)
    {
      [self setSourceTree: @"<group>"]; // default value
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_sourceTree);
  RELEASE(_children);
  RELEASE(_name);
  RELEASE(_tabWidth);
  RELEASE(_usesTabs);
  RELEASE(_path);

  [super dealloc];
}

// Methods....
- (NSString *) sourceTree // getter
{
  return _sourceTree;
}

- (void) setSourceTree: (NSString *)object; // setter
{
  ASSIGN(_sourceTree, object);
}

- (NSMutableArray *) children // getter
{
  return _children;
}

- (void) setChildren: (NSMutableArray *)object; // setter
{
  ASSIGN(_children, object);
}

- (NSString *) name // getter
{
  return _name;
}

- (void) setName: (NSString *)object; // setter
{
  ASSIGN(_name, object);
}

- (NSString *) path // getter
{
  return _path;
}

- (void) setPath: (NSString *)object; // setter
{
  ASSIGN(_path, object);
}

- (NSString *) description
{
  return [NSString stringWithFormat: @"<%@ - name = %@, path = %@>",
		   [super description], _name, _path];
}

@end
