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
#import "PBXTargetDependency.h"

@implementation PBXTargetDependency

- (void) dealloc
{
  RELEASE(_targetProxy);
  RELEASE(_name);
  RELEASE(_target);

  [super dealloc];
}

// Methods....
- (PBXContainerItemProxy *) targetProxy // getter
{
  return _targetProxy;
}

- (void) setTargetProxy: (PBXContainerItemProxy *)object; // setter
{
  ASSIGN(_targetProxy,object);
}

- (NSString *) name // getter
{
  return _name;
}

- (void) setName: (NSString *)object; // setter
{
  ASSIGN(_name,object);
}

- (PBXNativeTarget *)target
{
  return _target;
}

- (void) setTarget: (PBXNativeTarget *)object
{
  _target = object;
}

- (BOOL) build
{
  return [_targetProxy build];
}

- (BOOL) generate
{
  return [_targetProxy generate];
}

- (BOOL) clean
{
}

- (NSString *) description
{
  return [NSString stringWithFormat: @"<%@> - %@", [super description], _name];
}
@end
