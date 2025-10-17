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

#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"
#import "XCConfigurationList.h"
#import "PBXFileReference.h"
#import "PBXTarget.h"

@interface PBXNativeTarget : PBXTarget
{
  PBXFileReference *_productReference;
  NSString *_productInstallPath;
  NSMutableArray *_buildRules;
  NSString *_comments;
  NSString *_productSettingsXML;
  XCConfigurationList *_xcConfigurationList;
}

/**
 * Returns the product reference for this native target.
 */
- (PBXFileReference *) productReference;

/**
 * Sets the product reference for this native target.
 */
- (void) setProductReference: (PBXFileReference *)object;

/**
 * Returns the product install path for this native target.
 */
- (NSString *) productInstallPath;

/**
 * Sets the product install path for this native target.
 */
- (void) setProductInstallPath: (NSString *)object;

/**
 * Returns the build rules for this native target.
 */
- (NSMutableArray *) buildRules;

/**
 * Sets the build rules for this native target.
 */
- (void) setBuildRules: (NSMutableArray *)object;

/**
 * Returns the product settings XML for this native target.
 */
- (NSString *) productSettingsXML;

/**
 * Sets the product settings XML for this native target.
 */
- (void) setProductSettingsXML: (NSString *)object;

@end
