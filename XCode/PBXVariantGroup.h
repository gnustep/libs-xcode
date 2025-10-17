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

// Local includes
#import "PBXCoder.h"


@interface PBXVariantGroup : NSObject
{
  NSString *sourceTree;
  NSString *path;
  NSMutableArray *children;
  NSString *name;
}

/**
 * Returns the source tree for this variant group.
 */
- (NSString *) sourceTree;

/**
 * Sets the source tree for this variant group.
 */
- (void) setSourceTree: (NSString *)object;

/**
 * Returns the path for this variant group.
 */
- (NSString *) path;

/**
 * Sets the path for this variant group.
 */
- (void) setPath: (NSString *)object;

/**
 * Returns the children of this variant group.
 */
- (NSMutableArray *) children;

/**
 * Sets the children of this variant group.
 */
- (void) setChildren: (NSMutableArray *)object;

/**
 * Returns the name of this variant group.
 */
- (NSString *) name;

/**
 * Sets the name of this variant group.
 */
- (void) setName: (NSString *)object;

/**
 * Returns the build path for this variant group.
 */
- (NSString *) buildPath;

@end
