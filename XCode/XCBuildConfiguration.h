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

#ifndef __XCBuildConfiguration_h_GNUSTEP_INCLUDE
#define __XCBuildConfiguration_h_GNUSTEP_INCLUDE

#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"
#import "PBXFileReference.h"

@interface XCBuildConfiguration : NSObject
{
  NSMutableDictionary *buildSettings;
  NSString *name;
  PBXFileReference *baseConfigurationReference;
}

// Initialization...
- (instancetype) initWithName: (NSString *)theName
                buildSettings: (NSMutableDictionary *)settings;
- (instancetype) initWithName: (NSString *)theName;

// Methods....
- (NSMutableDictionary *) buildSettings; // getter
- (void) setBuildSettings: (NSMutableDictionary *)object; // setter
- (NSString *) name; // getter
- (void) setName: (NSString *)object; // setter

- (void) apply;
@end

#endif
